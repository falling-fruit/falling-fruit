// ================= app globals ==================
// Set in application.html.erb

var cats;
var host;

// ================= map globals ==================

var map;
var pano;
var pointer;
var crosshair;
var pano_tab = null;
var prior_bounds = null;
var prior_zoom = null;
var prior_url = null;
var markersArray = [];
var types_hash = {}; // id to count mapping
var showing_route_controls = false; // currently unused
var labelsOn = false;
var bicycleLayerOn = null;
var bicycleControl = null;
var last_search = null;
var pb = null;
var toner = 'toner-lite';
var markersLoadedEvent = document.createEvent("Event");
markersLoadedEvent.initEvent("markersloaded",true,true);
var markersMax = 5000; // maximum markers that will display at one time...
var markersPartial = false;
if (host == "localhost") {
  var api_base = "http://localhost:3100/api/0.2/";
  var api_key = "AKDJGHSD";
} else {
  var api_base = "https://fallingfruit.org/api/0.2/";
  var api_key = "EEQRBBUB";
}

// ================= services ==================

var panoClient = new google.maps.StreetViewService();
var elevationClient = new google.maps.ElevationService();
var geocoder = new google.maps.Geocoder();

// ================= infowindow =================

var infowindow = new google.maps.InfoWindow();
infowindow.marker = false;
var infowindowHeaderHeight = null;

function close_infowindow() {
  infowindow.close();
  infowindow.setContent('');
  infowindow.marker = false;
}

function open_infowindow(marker) {
  if (marker === undefined) {
    marker = infowindow.marker;
  }
  if (marker) {
    if (pano.getVisible()) {
      infowindow.open(pano, marker);
    } else {
      infowindow.open(map, marker);
    }
    infowindow.marker = marker;
  }
}

google.maps.event.addListener(infowindow,'closeclick',function() {
  close_infowindow();
});

//   google.maps.event.addListenerOnce(infowindow,'domready',function() {
//     setup_tabs(infowindow.marker, infowindow);
//   });
//   google.maps.event.addListenerOnce(infowindow,'content_changed',function() {
//     open_infowindow(infowindow, infowindow.marker);
//   });

// ================= basemap =================

function basemap(lat,lng,zoom,type,bounds){

  // Enable the visual refresh
  google.maps.visualRefresh = true;
  var mapTypeIds = [];
  Object.keys(google.maps.MapTypeId).forEach(function(key, index) {
    mapTypeIds.push(google.maps.MapTypeId[key]);
  });
  mapTypeIds.push(toner, "OSM");

  var mapOptions = {
    zoom: zoom,
    mapTypeId: type,
    mapTypeControl: true,
    mapTypeControlOptions: {
      style: google.maps.MapTypeControlStyle.HORIZONTAL_BAR,
      position: google.maps.ControlPosition.TOP_RIGHT,
      mapTypeIds: mapTypeIds
    },
    zoomControl: true,
    zoomControlOptions: {
      position: google.maps.ControlPosition.LEFT_CENTER
    },
    scaleControl: true,
    streetViewControl: true,
    streetViewControlOptions: {
      position: google.maps.ControlPosition.LEFT_CENTER
    }
  };

  map = new google.maps.Map(document.getElementById('map'),mapOptions);
  if (bounds == undefined) {
    map.setCenter(new google.maps.LatLng(lat,lng));
    map.setZoom(zoom);
  } else {
    map.fitBounds(bounds);
  }

  // Street View Pano (full screen, still in beta)
  pano = map.getStreetView();

  // Stamen Toner (B&W) map
  var tonerType = new google.maps.StamenMapType(toner);
  tonerType.name = "B+W";
  map.mapTypes.set(toner, tonerType);
  if(type == toner){
    update_attribution();
  }

  // OSM
  // http://wiki.openstreetmap.org/wiki/Google_Maps_Example
  map.mapTypes.set("OSM", new google.maps.ImageMapType({
    getTileUrl: function(coord, zoom) {
      // "Wrap" x (logitude) at 180th meridian properly
      // NOTE: Don't touch coord.x because coord param is by reference, and changing its x property breakes something in Google's lib
      var tilesPerGlobe = 1 << zoom;
      var x = coord.x % tilesPerGlobe;
      if (x < 0) {
        x = tilesPerGlobe+x;
      }
      // Wrap y (latitude) in a like manner if you want to enable vertical infinite scroll
      return "http://tile.openstreetmap.org/" + zoom + "/" + x + "/" + coord.y + ".png";
    },
    tileSize: new google.maps.Size(256, 256),
    name: "OSM",
    maxZoom: 18
  }));

  // Turn off 45 deg imagery by default
  map.setTilt(0);

  // Bicycle map (and control)
  add_bicycle_control(map);

  // Progress bar
  pb = progressBar();
  map.controls[google.maps.ControlPosition.TOP_CENTER].push(pb.getDiv());

  // Key Drag Zoom
  keyDragZoom(map);

  // Pointer
  pointer = new google.maps.Marker({
    position: map.getCenter(),
    map: map,
    icon: {
      path: google.maps.SymbolPath.CIRCLE,
      scale: 10,
      strokeWeight: 4,
      strokeColor: '#ff666e'
      },
    draggable: false,
    clickable: false,
    visible: false,
    zIndex: 1e3
  });

  // Search crosshair
  var w = 19;
  var h = 19;
  crosshair = new google.maps.Marker({
    position: map.getCenter(),
    map: map,
    icon: {
      url: '/cross.png',
      size: new google.maps.Size(w, h),
      origin: new google.maps.Point(0, 0),
      anchor: new google.maps.Point(w/2, h/2)
      },
    draggable: false,
    clickable: false,
    visible: false,
    zIndex: -1e3 // so that it draws beneath any overlapping marker
  });

  // Close open location infowindow when map is clicked
  google.maps.event.addListener(map, 'click', function(event) {
    close_infowindow();
  });

  // Update attribution when map type changes
  google.maps.event.addListener(map, 'maptypeid_changed', function(event) {
    update_attribution();
  });

  google.maps.event.addListener(map, 'zoom_changed', function(event) {
    zoom = map.getZoom();
  });
}

function find_marker(lid){
  for(var i = 0; i < markersArray.length; i++){
    if(markersArray[i].id == lid) return i;
  }
  return undefined;
}

// Convert WKT shape to map bounds
function wkt_to_bounds(wkt_string) {
  var wkt = new Wkt.Wkt();
  wkt.read(wkt_string);
  obj = wkt.toObject();
  if (obj.getBounds !== undefined && typeof obj.getBounds === 'function') {
    // For objects that have defined bounds or a way to get them
    return obj.getBounds();
  } else if (obj.getPath !== undefined && typeof obj.getPath === 'function') {
    // For Polygons and Polylines
    var b = new google.maps.LatLngBounds();
    for (var i = 0; i < obj.getPath().length;i++) {
      b.extend(obj.getPath().getAt(i));
    }
    return b;
  }
  //} else if (obj.getPosition !== undefined && typeof obj.getPosition === 'function') {
  //    return obj.getPosition();
  //  }
  //}
  return false;
}

// Draw foraging range on map
function add_range(range_string) {
  var wkt = new Wkt.Wkt();
  wkt.read(range_string);
  obj = wkt.toObject({
    strokeColor: '#666',
    strokeWeight: 5,
    strokeOpacity: 0.5,
    fillOpacity: 0,
    clickable: false
  });
  obj.setMap(map);
  return obj;
}

function number_to_human(n){
  if(n > 999 && n <= 999999){
    return Math.round(n/1000.0) + "K";
  }else if(n > 999999){
    return Math.round(n/1000000) + "M";
  }else{
    return n;
  }
}

function add_clusters_from_json(mdata,type_filter){
  var len = mdata.length;
  for(var i = 0; i < len; i++){
    var lid = mdata[i]["id"];
    if((lid != undefined) && (find_marker(lid) != undefined)) continue;
    var pct = Math.min(Math.max((Math.round(Math.log(mdata[i]["count"])/Math.log(10))+2)*10,30),100);
    var picture = "/icons/orangedot" + pct + ".png";
    var w = pct;
    var h = pct;
    var wo = parseInt(w/2,10);
    var ho = parseInt(h/2,10);
    var m = new RichMarker({
      content: '<div style="color:black;background:url(' + picture + ');height:'+h+
      'px;line-height:'+h+'px;width:'+w+'px;top:-'+ho+'px;left:-'+wo+'px;'+
      'text-align: center;position:absolute;'+
      'font-family:Arial,sans-serif;font-weight:bold;font-size:9pt;">'+number_to_human(mdata[i]["count"])+'</div>',
      position: new google.maps.LatLng(mdata[i]["center_y"],mdata[i]["center_x"]),
      map: map,
      draggable: false,
      width: w,
      height: h,
      shadow: false,
      flat: true,
      title: number_to_human(mdata[i]["count"]),
      anchor: RichMarkerPosition.MIDDLE
    });
    add_clicky_cluster(m);
    markersArray.push({marker: m, id: null, type: "cluster", types: [], parent_types: []});
  }
  document.dispatchEvent(markersLoadedEvent);
}

// will avoid adding duplicate markers (using location id)
function add_markers_from_json(mdata,skip_ids){
  var len = mdata.length;
  for(var i = 0; i < len; i++){
    var lid = mdata[i]["id"];
    if((skip_ids != undefined) && (skip_ids.indexOf(parseInt(lid)) >= 0)) continue;
    if((lid != undefined) && (find_marker(lid) != undefined)) continue;
    var w = 17;
    var h = 17;
    var wo = parseInt(w/2,10);
    var ho = parseInt(h/2,10);
    if(infowindow.marker && infowindow.marker.id == lid){
      var m = infowindow.marker;
    }else{
      var m = new google.maps.Marker({
        icon: {
          url: '/icons/smdot_t1_red.png',
          size: new google.maps.Size(w,h),
          origin: new google.maps.Point(0,0),
          // smdot icon center is at ~40%
          anchor: new google.maps.Point(w*0.4,h*0.4)
        },
        position: new google.maps.LatLng(mdata[i]["lat"],mdata[i]["lng"]),
        map: map,
        title: type_names_to_title(mdata[i]["type_names"]),
        draggable: false
      });
    }
    markersArray.push({marker: m, id: mdata[i]["id"], type: "point",
      types: mdata[i]["type_ids"], parent_types: mdata[i]["parent_types"]});
    for(var j = 0; j < mdata[i]["type_ids"].length; j++){
      var tid = mdata[i]["type_ids"][j];
      if(types_hash[tid] == undefined) types_hash[tid] = 1;
      else types_hash[tid] += 1;
    }
    if(mdata[i]["parent_types"]) {
      for (var j = 0; j < mdata[i]["parent_types"].length; j++) {
        var tid = mdata[i]["parent_types"][j];
        if (types_hash[tid] == undefined) types_hash[tid] = 1;
        else types_hash[tid] += 1;
      }
    }
  }
  document.dispatchEvent(markersLoadedEvent);
}

// Removes all markers, except the open one, from the map
function clear_markers() {
  if (markersArray == undefined || markersArray.length == 0) return;
  for (var i = 0; i < markersArray.length; i++ ) {
    // comment this line in to keep open marker between refreshes
    //if(infowindow.marker && infowindow.marker == markersArray[i].marker) continue;
    markersArray[i].marker.setMap(null);
    markersArray[i].marker = null;
    markersArray[i].id = null;
    delabelize_marker(i);
  }
  markersArray.length = 0;
  markersArray = [];
  types_hash = {};
}

function clear_offscreen_markers(){
  if (markersArray == undefined || markersArray.length == 0) return;
  var bounds = map.getBounds();
  var len = markersArray.length;
  for (var i = 0; i < len; i++ ) {
    if(infowindow.marker && infowindow.marker == markersArray[i].marker) continue;
    if(!bounds.contains(markersArray[i].marker.getPosition())){
      if(markersArray[i].types) {
        for (var j = 0; j < markersArray[i].types.length; j++) {
          var tid = markersArray[i].types[j];
          if (types_hash[tid] != undefined && types_hash[tid] > 0) types_hash[tid] -= 1;
          if (types_hash[tid] == 0) delete types_hash[tid];
        }
      }
        if(markersArray[i].parent_types) {
        for (var j = 0; j < markersArray[i].parent_types.length; j++) {
          var tid = markersArray[i].parent_types[j];
          if (types_hash[tid] != undefined && types_hash[tid] > 0) types_hash[tid] -= 1;
          if (types_hash[tid] == 0) delete types_hash[tid];
        }
      }
      markersArray[i].marker.setMap(null);
      markersArray[i].marker = null;
      markersArray[i].id = null;
      markersArray[i].types = null;
      markersArray[i].type = null;
      markersArray[i].parent_types = null;
      delabelize_marker(i);
      markersArray.splice(i,1);
      i--;
      len--;
    }
  }
}

function bounds_to_query_string(bounds){
    if(bounds == undefined) return '';
    var ne = bounds.getNorthEast();
    var sw = bounds.getSouthWest();
    bstr = '&nelat=' + ne.lat() + '&nelng=' + ne.lng() +
           '&swlat=' + sw.lat() + '&swlng=' + sw.lng();
    return bstr;
}

function do_clusters(bounds,zoom,muni,type_filter) {
    var bstr = bounds_to_query_string(bounds);
    var gstr = '&zoom=' + zoom;
    if (muni) mstr = '&muni=1';
      else mstr = '&muni=0';
    var tstr = '';
    if(type_filter != undefined){
      tstr = '&t=' + type_filter.join(",");
    }
    if(pb != null) pb.start(200);
    //console.log(api_base + 'clusters.json?api_key=' + api_key + '&locale=' + I18n.locale + mstr + gstr + bstr + tstr);
    var request = $.ajax({
      type: 'GET',
      url: api_base + 'clusters.json?api_key=' + api_key + '&locale=' + I18n.locale + mstr + gstr + bstr + tstr,
      dataType: 'json'
    });
    request.done(function(json){
      //console.log(json);
      clear_markers();
      if(json.length > 0){
        add_clusters_from_json(json);
      }
      markersPartial = false;
      if(pb != null) pb.hide();
      // Call from here to ensure the data is available
      do_cluster_types(bounds,zoom,muni);
    });
    request.fail(function() {
      if(pb != null) pb.hide();
    });
}

function do_cluster_types(bounds,zoom,muni) {
  var bstr = bounds_to_query_string(bounds);
  var gstr = '&zoom=' + zoom;
  if (muni) mstr = '&muni=1';
  else mstr = '&muni=0';
  var url = api_base + 'types.json?api_key=' + api_key + '&locale=' + I18n.locale + mstr + gstr + bstr;
  //console.log(url);
  var request = $.ajax({
    type: 'GET',
    url: url,
    dataType: 'json'
  });
  request.done(function(json){
    types_hash = {};
    if(json.length > 0){
      for(var i = 0;i < json.length; i++){
        types_hash[json[i]["id"]] = json[i]["count"];
      }
    }
    update_count_hack();
  });
}

// Given a list of type names, returns a marker title fit for displaying on the map.
function type_names_to_title(type_names) {
  if (type_names.length == 0) {
    return "";
  } else if (type_names.length == 1) {
    return type_names[0];
  } else if (type_names.length == 2) {
    return type_names[0] + " & " + type_names[1];
  } else {
    return type_names[0] + " (+" + (type_names.length - 1) + ")";
  }
}

// Finds nearest imagery from Street View Service, then calculates the heading.
// https://developers.google.com/maps/documentation/javascript/reference?csw=1#spherical
function setup_streetview_tab(marker,distance,visible) {
  var latlng = marker.getPosition();
  var nearestPano = null;
  panoClient.getPanoramaByLocation(latlng, distance, function(result, status) {
    if (status == google.maps.StreetViewStatus.OK) {
      if (visible) {
        nearestPano = result.location.pano;
        panoPosition = result.location.latLng;
        var heading = google.maps.geometry.spherical.computeHeading(panoPosition, latlng);
        pano_tab = new google.maps.StreetViewPanorama(document.getElementById("tab-3"), {
          navigationControl: true,
          navigationControlOptions: {style: google.maps.NavigationControlStyle.ANDROID},
          enableCloseButton: false,
          addressControl: false,
          position: panoPosition,
          pov: { heading: heading, pitch: 0, zoom: 1 },
          linksControl: false,
        });
        var pano_marker = new google.maps.Marker({
          position: marker.getPosition(),
          map: pano_tab
        });
        // Calculate pitch from Google Elevation API
        // If fails, assume that elevation is equal at both points
        var camera_height = 2;
        var locations = [panoPosition, latlng];
        var positionalRequest = {
          'locations': locations
        }
        var x = google.maps.geometry.spherical.computeDistanceBetween(locations[0], locations[1]);
        elevationClient.getElevationForLocations(positionalRequest, function(results, status) {
          if (status == google.maps.ElevationStatus.OK & results.length == 2) {
            var y = results[1].elevation - (results[0].elevation + camera_height);
          } else {
            var y = -camera_height;
          }
          var pitch = 90 - Math.atan2(x,y) * (180 / Math.PI);
          pano_tab.setPov({ heading: heading, pitch: pitch, zoom: 1 });
        });
        pano_tab.setVisible(true);
      }
      return(true);
    } else {
      $("#tab-3").remove();
      $("#streetview-tab").remove();
      $("#streetview-toggle").remove();
      return(false);
    }
  });
}

// Finds nearest imagery from Street View Service, then calculates the heading.
// https://developers.google.com/maps/documentation/javascript/reference?csw=1#spherical
function streetview_toggle(marker,distance) {
  if (pano.getVisible()) {
    pano.setVisible(false);
  } else {
    var latlng = marker.getPosition();
    var nearestPano = null;
    panoClient.getPanoramaByLocation(latlng, distance, function(result, status) {
      if (status == google.maps.StreetViewStatus.OK) {
        nearestPano = result.location.pano;
        panoPosition = result.location.latLng;
        var heading = google.maps.geometry.spherical.computeHeading(panoPosition, latlng);
        // Calculate pitch from Google Elevation API
        // If fails, assume that elevation is equal at both points
        var camera_height = 2;
        var locations = [panoPosition, latlng];
        var positionalRequest = {
          'locations': locations
        }
        var x = google.maps.geometry.spherical.computeDistanceBetween(locations[0], locations[1]);
        elevationClient.getElevationForLocations(positionalRequest, function(results, status) {
          if (status == google.maps.ElevationStatus.OK & results.length == 2) {
            var y = results[1].elevation - (results[0].elevation + camera_height);
          } else {
            var y = -camera_height;
          }
          var pitch = 90 - Math.atan2(x,y) * (180 / Math.PI);
          pano.setPosition(panoPosition);
          pano.setPov({ heading: heading, pitch: pitch, zoom: 1 });
        });
        google.maps.event.addListener(pano, 'visible_changed', function() {
          if (infowindow.marker && infowindow.marker == marker) {
            open_infowindow(marker)
          }
        });
        pano.setVisible(true);
      } else {
        $("#streetview-toggle").remove();
        return(false);
      }
    });
  }
}

function open_problem_modal(id){
  $('#problem_modal').load('/problems/new?location_id=' + id + '&locale=' + I18n.locale).dialog({
    autoOpen:true,
    width:425,
    modal:true,
    resizable:false,
    draggable:false,
    position: {my: "center", at: "center", of: "#searchbar"},
    close:function(){
      $('#problem_modal').html('');
    }
  });
}

function open_unverified_help_modal(){
  $('#unverified_help').dialog({
    autoOpen:true,
    width:500,
    modal:true,
    resizable:false,
    draggable:false
  });
}

function open_inventories_help_modal(){
  $('#tree_inventories_help').dialog({
    autoOpen:true,
    width:640,
    modal:true,
    resizable:false,
    draggable:false
  });
}

function open_invasive_help_modal(){
  $('#tree_invasive_help').dialog({
    autoOpen:true,
    width:640,
    modal:true,
    resizable:false,
    draggable:false
  });
}

function open_pending_types_help_modal(){
  $('#pending_types_help').dialog({
    autoOpen:true,
    width:500,
    modal:true,
    resizable:false,
    draggable:false
  });
}

// Tab 1
function open_tab_1() {
  open_infowindow();
}

// Tab 2
function open_tab_2() {
  open_infowindow();
  // Load images into Shadowbox gallery
  Shadowbox.clearCache();
  Shadowbox.setup("a[rel='shadowbox']", { gallery: "Gallery" });
}

// Tab 3
function open_tab_3() {
  p = $('#location_infowindow');
  if ($("#tab-1").hasClass('ui-tabs-hide')) {
    var starting_height = $('#tab-2').height();
  } else {
    var starting_height = $('#tab-1').height();
  }
  var previous_height = $('#tab-3').height()
  var new_height = Math.max(starting_height, Math.min(400, 0.75 * $('#map').height() - infowindowHeaderHeight));
  $('#tab-3').height(new_height);
  open_infowindow();
  if (pano_tab == null || !pano_tab.visible) {
    setup_streetview_tab(infowindow.marker,50,true);
  } else if (previous_height != new_height) {
    pano_tab.setVisible(true);
  }
}

// Tab 1 (info, the default) uses its original height, or the max height.
// Tab 2 (reviews) tries to get as close as possible to its content height.
// Tab 3 (street view) requires a minimum height to be useful.
function setup_tabs(callback) {
  p = $('#location_infowindow');
  infowindowHeaderHeight = p.children('.ui-tabs-nav').outerHeight(true);
  var max_height = 0.75 * $('#map').height() - infowindowHeaderHeight;
  if (max_height < $('#tab-1').height()) {
    $('#tab-1').height(max_height);
  }
  $('#tab-2').height(Math.min(max_height, Math.max($('#tab-1').height(), $('#tab-2').height())));
  var current_width = p.parent().width();
  $('#tab-1').width(current_width);
  $('#tab-2').width(current_width);
  $('#tab-3').width(current_width);
  // HACK: Force Google to recalculate infowindow size.
  $('#tab-1').height($('#tab-1').height() + 1);
  $('.gm-style-iw').height($('#location_infowindow').height());
  infowindow.setContent(infowindow.content);
}

function open_marker(marker) {
  var cstr = '';
  if (cats != undefined) {
    cstr = '&c=' + cats;
  }
  lstr = '&locale=' + I18n.locale;
  var requestHtml = $.ajax({
    type: 'GET',
    url: '/locations/' + marker.id + '/infobox?' + cstr + lstr,
    dataType: 'html'
  });
  requestHtml.done(function(html) {
    var div = document.createElement('div');
    div.innerHTML = html;
    $(div).tabs();
    infowindow.setContent(div);
    open_infowindow(marker);
    google.maps.event.addListenerOnce(infowindow,'domready',function() {
      setup_tabs();
      setup_streetview_tab(infowindow.marker,50,false);
    });
  });
}

function add_marker_infowindow(i) {
  var marker = markersArray[i].marker;
  marker.id = markersArray[i].id;
  google.maps.event.addListener(marker,'click',function() {
    pano_tab = null;
    if (marker == infowindow.marker) {
      return true;
    }
    open_marker(marker);
  });
}

function open_marker_by_id(id) {
  for (var i = 0; i < markersArray.length; i++) {
    if (markersArray[i].id == id) {
      marker = markersArray[i].marker;
      marker.id = markersArray[i].id;
      open_marker(marker);
      return true;
    }
  }
  // didn't find it, manually fetch & add it
  var requestJson = $.ajax({
    type: 'GET',
    url: api_base + 'locations/'+id+'.json?api_key='+api_key,
    dataType: 'json'
  });
  requestJson.done(function(json){
    // Add marker to map
    // Put into array for add_markers_from_json()
    add_markers_from_json([json]);
    // make marker clickable
    add_marker_infowindow(markersArray.length-1);
    // filter and labels
    if(labelsOn) labelize_markers();
    search_filter(last_search);
    // open infowindow
    marker = markersArray[markersArray.length-1].marker;
    marker.id = markersArray[markersArray.length-1].id;
    open_marker(marker);
  });
  return true;
}

function add_clicky_cluster(marker){
  google.maps.event.addListener(marker, 'click', function(){
    var z = map.getZoom();
    if(z >= 10) z = 13;
    else z += 2;
    map.panTo(marker.getPosition());
    map.setZoom(z);
  });
}

function do_markers(bounds,skip_ids,muni,type_filter,cats,invasive) {
  if(markersArray.length >= markersMax) return;
  var bstr = bounds_to_query_string(bounds);
  if (muni) mstr = '&muni=1';
    else mstr = '&muni=0';
  if (invasive) istr = '&invasive=1';
  else istr = '';

  var tstr = '';
  if (type_filter != undefined) {
    var tstr = '&t=' + type_filter.join(",");
  }
  var cstr = '';
  if (cats != undefined) {
    cstr = '&c=' + cats;
  }
  if(pb != null) pb.start(200);
  //console.log(api_base + 'locations.json?api_key='+api_key+'&locale=' + I18n.locale + mstr + bstr + tstr + cstr);
  var request = $.ajax({
    type: 'GET',
    url: api_base + 'locations.json?api_key='+api_key+'&locale=' + I18n.locale + mstr + istr + bstr + tstr + cstr,
    dataType: 'json'
  });
  request.done(function(json){
    //console.log(json);
    if(pb != null) pb.setTotal(json.length);
    // remove any cluster-type markers
    var i = find_marker(null);
    while((i != undefined) && (i >= 0)){
      if(markersArray[i].marker != undefined){
        markersArray[i].marker.setMap(null);
        markersArray[i].marker = null;
        markersArray[i].id = null;
        markersArray[i].type = null;
        markersArray[i].types = null;
        markersArray[i].parent_types = null;
      }
      markersArray.splice(i,1);
      i = find_marker(null);
    }
    n_found = json.shift();
    n_limit = json.shift();
    clear_offscreen_markers();
    add_markers_from_json(json,skip_ids);
    if(type_filter != undefined && type_filter.length > 0) apply_type_filter();
    else clear_type_filter();
    // make markers clickable
    for (var i = 0; i < markersArray.length; ++i) {
      add_marker_infowindow(i);
    }
    if(labelsOn) labelize_markers();
    n = json.length;
    if(n > 0){
      if((n < n_found) && (n_found >= n_limit)){
        $("#pg_text").html(markersArray.length + " of " + n_found + " visible");
        markersPartial = true;
      }else{
        pb.hide();
        markersPartial = false;
      }
    }else{
      pb.hide();
    }
    search_filter(last_search);
  });
  request.fail(function(){
    if(pb != null) pb.hide();
  });
}

function remove_add_marker(){
  // by convention, the "add" marker has an id of -1
  var i = find_marker(-1);
  if(i == undefined) return;
  var marker = markersArray[i].marker;
  var id = markersArray[i].id;
  marker.setMap(null);
  markersArray.splice(i,1);
}

// Add a marker with an open infowindow
function place_add_marker(latlng) {
  var marker = new google.maps.Marker({
      position: latlng,
      map: map,
      draggable: true
  });
  markersArray.push({marker: marker, id: -1, type: "point"});
  // Set and open infowindow
  var html = $('<div id="addmarker"><a href="/locations/new?lat='
    + latlng.lat() + '&lng=' + latlng.lng() + '&locale=' + I18n.locale
    + '" data-ajax="false" rel="external">' + I18n.t("locations.index.addmarker_html") + '</div>');
  var infowindow = new google.maps.InfoWindow({
    content: html[0]
  });
  infowindow.open(map,marker);
  // Listen to drag & drop
  google.maps.event.addListener(marker, 'dragend', function() {
    $('#addmarker').children('a').attr('href', '/locations/new?lat=' + this.getPosition().lat() + '&lng=' + this.getPosition().lng());
  });
  google.maps.event.addListener(infowindow,'closeclick',function(){
    remove_add_marker();
  });
}

function labelize_markers() {
   // if we're still in clustered mode, don't label
   if(map.getZoom() <= 12) return;
   var len = markersArray.length;
   for(var i = 0; i < len; i++){
     if(!markersArray[i].marker.getVisible()) continue;
		 if (markersArray[i].marker.getZIndex() < 100) continue; // HACK: skip filtered out locations
     if(markersArray[i].label != undefined) continue;
     var pos = markersArray[i].marker.getPosition();
     var mapLabel = new MapLabel({
       text: markersArray[i].marker.getTitle(),
       // FIXME: bad hack to prevent marker from overlapping with label
       position: new google.maps.LatLng(pos.lat()-0.00003,pos.lng()),
       map: map,
       fontSize: 13,
       fontColor: '#990000',
       strokeColor: '#efe8de',
       strokeWeight: 5,
       align: 'center'
     });
     markersArray[i].label = mapLabel;
     markersArray[i].marker.bindTo('map', mapLabel);
   }
   labelsOn = true;
}

function delabelize_marker(i){
  if(markersArray[i].label != undefined){
    markersArray[i].label.set('text','');
    markersArray[i].label = null;
  }
}

function delabelize_markers() {
  var len = markersArray.length;
  for(var i = 0; i < len; i++) delabelize_marker(i);
  labelsOn = false;
}

function search_filter(search){
  if(search == null) return;
  last_search = search;
  var len = markersArray.length;
  for(var i = 0; i < len; i++){
    var marker = markersArray[i].marker;
    var label = markersArray[i].label;
    var title = marker.getTitle();
    if(marker == undefined || title == undefined) continue;
    if(search == ""){
      marker.setVisible(true);
      if(label != undefined) label.set('map',map);
    }else if(title.search(new RegExp(search,"i")) >= 0){
      marker.setVisible(true);
      if(label != undefined) label.set('map',map);
    }else{
      marker.setVisible(false);
      if(label != undefined) label.set('map',null);
    }
  }
}

function intersect(a, b) {
  var t;
  if (b.length > a.length) t = b, b = a, a = t; // indexOf to loop over shorter
  return a.filter(function (e) {
    if (b.indexOf(e) !== -1) return true;
  });
}

// updates the count in the placeholder text
function update_count_hack(){
  // Update count hack
  if (type_filter != undefined && type_filter.length > 0) {
    filter_display = $('#s2id_type_filter .select2-chosen');
    var types_count = 0;
    if (type_filter != undefined) {
      for (var i = 0; i < type_filter.length; i++) {
        types_count += types_hash[type_filter[i]] == undefined ? 0 : types_hash[type_filter[i]];
      }
    }
    filter_display.html(filter_display.html().replace(/\(\d+\)/,'('+types_count+')'));
  }
}

function apply_type_filter() {
  var len = markersArray.length;
  for(var i = 0; i < len; i++){
    if(markersArray[i].types == undefined) continue;
    if(intersect(markersArray[i].types,type_filter).length > 0){
      //markersArray[i].marker.setVisible(true);
      markersArray[i].marker.setZIndex(101);
      markersArray[i].marker.setIcon({url: "/icons/smdot_t1_red.png", size: {width: 17, height: 17}, anchor: {x: 17*0.4, y: 17*0.4}});
      //if (markersArray[i].label != undefined) markersArray[i].label.set('map',map);
    }else{
      //markersArray[i].marker.setVisible(false);
      markersArray[i].marker.setZIndex(99);
      markersArray[i].marker.setIcon({url: "/icons/smdot_t1_white_a50.png", size: {width: 17, height: 17}, anchor: {x: 17*0.4, y: 17*0.4}});
      //if(markersArray[i].label != undefined) markersArray[i].label.set('map',null);
    }
  }
  update_count_hack();
}

function clear_type_filter() {
  var len = markersArray.length;
  for (var i = 0; i < len; i++) {
    //markersArray[i].marker.setVisible(true);
    markersArray[i].marker.setZIndex(101);
    markersArray[i].marker.setIcon({url: "/icons/smdot_t1_red.png", size: {width: 17, height: 17}, anchor: {x: 17*0.4, y: 17*0.4}});
    //if (markersArray[i].label != undefined) markersArray[i].label.set('map',map);
  }
}

function update_attribution() {
  var typeid = map.getMapTypeId();
  if (typeid == toner) {
    $('#stamen_attribution').show();
  } else {
    $('#stamen_attribution').hide();
  }
}

function recenter_map() {
  navigator.geolocation.getCurrentPosition(function(position){
      var lat = position.coords.latitude;
      var lng = position.coords.longitude;
      var latlng = new google.maps.LatLng(lat,lng);
      apply_geocode(latlng,undefined,15);
  },function(error){
    console.log("Geocode error [" + error.code + "]: " + error.message);
  });
}

// see: https://developers.google.com/maps/documentation/javascript/geocoding
function recenter_map_to_address() {
  // Bypass geocoder if already lat, lng
  // (geocoder snaps to nearest address, so not exact)
  var strsplit = $("#address").val().split(/[\s,]+/);
  if (strsplit.length == 2) {
    var lat = parseFloat(strsplit[0]);
    var lng = parseFloat(strsplit[1]);
    if (!isNaN(lat) && !isNaN(lng)) {
      var latlng = new google.maps.LatLng(lat,lng);
      apply_geocode(latlng,undefined,17);
      return;
    }
  }

  // Run geocoder for everything else
  geocoder.geocode( { 'address': $("#address").val() }, function(results, status) {
    if (status == google.maps.GeocoderStatus.OK) {
      var bounds = results[0].geometry.viewport;
      var latlng = results[0].geometry.location;
      apply_geocode(latlng,bounds);
      return;
    } else {
      alert(I18n.t("locations.messages.geocode_failed") + ": " + status);
    }
  });
}

function apply_geocode(latlng,bounds,zoom) {
  if (zoom == undefined) {
    zoom = 17;
  }
  if (latlng != undefined) {
    if (bounds == undefined) {
      map.setZoom(zoom);
      map.panTo(latlng);
    } else {
      map.fitBounds(bounds);
      zoom = map.getZoom();
    }
    if (zoom > 12) {
      show_crosshair(latlng);
    } else {
      hide_crosshair();
    }
  }
}

// Adds a bicycle layer toggle to the map
function add_bicycle_control(map) {

  // Initialize control div
  bicycleControl = document.createElement('div');
  map.controls[google.maps.ControlPosition.TOP_RIGHT].push(bicycleControl);
  bicycleControl.id = 'maptype_button';
  bicycleControl.innerHTML = I18n.t("routes.modes_of_travel")[1];

  // Initialize map with control off
  bicycleLayerOn = false;
  var layer = new google.maps.BicyclingLayer();

  // Setup the click event listeners
  google.maps.event.addDomListener(bicycleControl, 'click', function() {
    if (bicycleLayerOn) {
      layer.setMap(null);
      bicycleControl.style.fontWeight = 'normal';
      bicycleControl.style.color = '#565656';
      bicycleControl.style.boxShadow = '0px 1px 1px -1px rgba(0, 0, 0, 0.4)';
      bicycleLayerOn = false;
    } else {
      layer.setMap(map);
      bicycleControl.style.fontWeight = '500';
      bicycleControl.style.color = '#000';
      bicycleControl.style.boxShadow = '0px 1px 1px -1px rgba(0, 0, 0, 0.6)';
      bicycleLayerOn = true;
    }
  });
}

// Adds Key Drag Zoom to the map
// TODO: Translate tooltips, adjust size to match new controls
// http://google-maps-utility-library-v3.googlecode.com/svn/tags/keydragzoom/
function keyDragZoom(map) {
  map.enableKeyDragZoom({
    visualEnabled: true,
    visualPosition: google.maps.ControlPosition.LEFT_CENTER,
    visualPositionOffset: new google.maps.Size(15, 0),
    visualSize: new google.maps.Size(20, 20),
    //visualPositionIndex: null,
    visualSprite: "//maps.gstatic.com/mapfiles/ftr/controls/dragzoom_btn.png",
    key: "shift",
    boxStyle: {border: "2px solid rgba(0, 0, 0, 0.4)"},
    veilStyle: {backgroundColor: "transparent", cursor: "crosshair"},
    visualTips: {off: I18n.t("locations.index.turn_on_dragzoom"), on: I18n.t("locations.index.turn_off_dragzoom")}
   });
}

// Toggles on/off route controls below footer of location infowindow
function toggle_route_controls() {
  if ($('#route_controls').css('display') == 'none') {
      $('#route_controls').show();
      $('#route_toggle').css('color', '#333');
    } else {
      $('#route_controls').hide();
      $('#route_toggle').css('color', '#999');
    }
    $('#tab-1').height('');
    open_infowindow();
}

// Zooms to currently open marker
function zoom_to_marker() {
  maxZoom = map.mapTypes[map.mapTypeId].maxZoom;
  map.panTo(infowindow.marker.position);
  map.setZoom(maxZoom);
  open_infowindow();
}

// Show pointer
function show_pointer(lat, lng) {
  pointer.setPosition(new google.maps.LatLng(lat,lng));
  pointer.setVisible(true);
}

// Hide pointer
function hide_pointer() {
  pointer.setVisible(false);
}

// Show crosshair
function show_crosshair(latlng) {
  crosshair.setPosition(latlng);
  crosshair.setVisible(true);
}

// Hide crosshair
function hide_crosshair() {
  crosshair.setVisible(false);
}

/**********************************************************/
/********************** New / Edit ************************/
/**********************************************************/

// Update marker position from user-provided address
function update_marker_address() {

  // If empty, do nothing
  if($("#location_address").val() == "") return;
  geocoder.geocode({'address': $("#location_address").val()}, function(results, status) {

    // If valid address, move existing (or place new) marker
    if (status == google.maps.GeocoderStatus.OK) {
      var lat = results[0].geometry.location.lat();
      var lng = results[0].geometry.location.lng();
      var latlng = results[0].geometry.location
      $("#location_lat").val(lat.toFixed(6));
      $("#location_lng").val(lng.toFixed(6));
      map.panTo(latlng);
      map.setZoom(15);
      if (marker != null) {
        marker.setPosition(latlng);
        if(watchID != undefined){
          navigator.geolocation.clearWatch(watchID);
          watchID = null;
        }
      } else {
        nag = initialize_marker(lat,lng);
        nag.open(map,marker);
        nagOpen = true;
      }
    // Otherwise, return geocoding errors
    } else {
      alert(I18n.t("locations.messages.geocode_failed") + ": " + status);
    }
  });
}

// Update marker position from user-provided latitude and longitude
function update_marker_latlng() {
  var lat = parseFloat($("#location_lat").val());
  var lng = parseFloat($("#location_lng").val());

  // If bogus, do nothing
  if (isNaN(lat) || isNaN(lng)) return;

  // If latitude > 85, return error
  // Google Maps cannot display lat > 85 properly, and lat > 85 breaks clusters.
  if (Math.abs(lat) > 85) {
    alert(I18n.t("locations.messages.latitude_too_large"));
    return;
  }

  // Otherwise, and if numeric, move marker
  // If out of range, longitude is converted to [-180, 180]
  var latlng = new google.maps.LatLng(lat,lng, false);
  map.panTo(latlng);
  map.setZoom(15);
  if (marker != null) {
    marker.setPosition(latlng);
    if(watchID != undefined){
      navigator.geolocation.clearWatch(watchID);
      watchID = null;
    }
  } else {
    nag = initialize_marker(lat,lng);
    nag.open(map,marker);
    nagOpen = true;
  }
}

// Decode html coming in as a string
function decodeHtml(html) {
    var txt = document.createElement("textarea");
    txt.innerHTML = html;
    return txt.value;
}

// Initialize map marker (marker) and infowindow (nag)
function load_edit_marker(lat,lng) {

  var latlng = new google.maps.LatLng(lat,lng)

  // Initialize marker
  var marker = new google.maps.Marker({
    icon: '',
    position: latlng,
    map: map,
    draggable: true
  });

  // Infowindow
  var html = $('<div id="editmarker">' + I18n.t("locations.index.editmarker_html") + '</div>');
  var nag = new google.maps.InfoWindow({
    content: html[0]
  });
  var nagOpen = false;

  // Event listeners
  // Open nag once tiles loaded
  google.maps.event.addListenerOnce(map, 'tilesloaded', function(event) {
    nag.open(map,marker);
    nagOpen = true;
  });

  // Update lat,lng fields when marker moved
  google.maps.event.addListener(marker, 'position_changed', function() {
    $("#location_lat").val(this.getPosition().lat().toFixed(6));
    $("#location_lng").val(this.getPosition().lng().toFixed(6));
  });

  // Record closing of nag
  google.maps.event.addListener(nag, 'closeclick', function(event) {
    nagOpen = false;
  });

  // Toggle nag open/close on click of marker
  google.maps.event.addListener(marker, 'click', function(event) {
    if (nagOpen) {
      nag.close();
      nagOpen = false;
    } else {
      nag.open(map,marker);
      nagOpen = true;
    }
  });

  return marker;
}
