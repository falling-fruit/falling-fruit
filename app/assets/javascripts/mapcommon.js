  // ================= globals ==================

  var map;
  var geocoder;
  var prior_bounds = null;
  var prior_zoom = null;
  var markersArray = [];
  var openInfoWindow = null;
  var showing_route_controls = false;
  var openInfoWindowHtml = null;
  var openMarker = null;
  var labelsOn = false;
  var last_search = null;
  var pb = null;
  var markersLoadedEvent = document.createEvent("Event");
  markersLoadedEvent.initEvent("markersloaded",true,true);

  // ================= functions =================

  function find_marker(lid){
    for(var i = 0; i < markersArray.length; i++){
      if(markersArray[i].id == lid) return i;
    }
    return undefined;
  }

  // will avoid adding duplicate markers (using location id)
  function add_markers_from_json(mdata,rich,skip_ids){
    var len = mdata.length;
    for(var i = 0; i < len; i++){
      var lid = mdata[i]["location_id"];
      if((skip_ids != undefined) && (skip_ids.indexOf(parseInt(lid)) >= 0)) continue;
      if((lid != undefined) && (find_marker(lid) != undefined)) continue;
      if(!rich){
        var w = mdata[i]["width"];
        var h = mdata[i]["height"];
        var wo = parseInt(w/2,10);
        var ho = parseInt(h/2,10);
        var m = new google.maps.Marker({
            icon: {
              url: mdata[i]["picture"],
              size: new google.maps.Size(w,h),
              origin: new google.maps.Point(0,0),
              // by convention, icon center is at 6.5/17ths
              anchor: new google.maps.Point(w*0.382,h*0.382)
            },
            position: new google.maps.LatLng(mdata[i]["lat"],mdata[i]["lng"]), 
            map: map,
            title: mdata[i]["title"],
            draggable: false
        });
        markersArray.push({marker: m, id: mdata[i]["location_id"], type: "point"});
      }else{
        var w = mdata[i]["width"];
        var h = mdata[i]["height"];
        var wo = parseInt(w/2,10);
        var ho = parseInt(h/2,10);
        var m = new RichMarker({
            content: '<div style="color:black;background:url(' + mdata[i]["picture"] + ');height:'+h+
                     'px;line-height:'+h+'px;width:'+w+'px;top:-'+ho+'px;left:-'+wo+'px;'+
                     'text-align: center;position:absolute;'+
                     'font-family:Arial,sans-serif;font-weight:bold;font-size:9pt;">'+mdata[i]["title"]+'</div>',
            position: new google.maps.LatLng(mdata[i]["lat"],mdata[i]["lng"]), 
            map: map,
            draggable: false,
            width: w,
            height: h,
            shadow: false,
            flat: true,
            title: mdata[i]["title"],
            anchor: RichMarkerPosition.MIDDLE,
          });
          add_clicky_cluster(m);
          markersArray.push({marker: m, id: null, type: "cluster"});
      }
    }
    document.dispatchEvent(markersLoadedEvent);
  }

  // Removes the overlays from the map
  function clear_markers() {
    if (markersArray) {
      for (var i = 0; i < markersArray.length; i++ ) {
        markersArray[i].marker.setMap(null);
        markersArray[i].marker = null;
        markersArray[i].id = null;
      }
    }
    markersArray.length = 0;
    markersArray = [];
  }

  function do_clusters(bounds,zoom,muni,type_filter){
      var bstr = '';
      var gstr = 'method=grid&grid=' + zoom;
      if(bounds != undefined){
        var ne = bounds.getNorthEast();
        var sw = bounds.getSouthWest();
        bstr = 'nelat=' + ne.lat() + '&nelng=' + ne.lng() + 
               '&swlat=' + sw.lat() + '&swlng=' + sw.lng();
      }
      if(muni) mstr = '';
      else mstr = 'muni=0&';
      var tstr = '';
      if(type_filter != undefined){
        tstr = '&t='+type_filter;
      }
      if(pb != null) pb.start(200);
      var request = $.ajax({
        type: 'GET',
        url: '/locations/cluster.json?' + mstr + gstr + '&' + bstr + tstr,
        dataType: 'json'
      });
      request.done(function(json){
        if(json.length > 0){
          clear_markers();
          add_markers_from_json(json,true);
        }
        if(pb != null) pb.hide();
      });
      request.fail(function() {  
        if(pb != null) pb.hide();
      });
  }

  function open_marker_by_id(id,lat,lng){
    for (var i = 0; i < markersArray.length; i++ ) {
      if(markersArray[i].id == id){
        var requestHtml = $.ajax({
          type: 'GET',
          url: '/locations/' + id + '/infobox',
          dataType: 'html'
        });
        requestHtml.done(function(html){
          var infowindow = new google.maps.InfoWindow({content: html });
          google.maps.event.addListener(infowindow,'closeclick',function(){
            openInfoWindow = null;
            openMarker = null;
          });
          infowindow.open(map, markersArray[i].marker);
          openInfoWindow = infowindow;
          openInfoWindowHtml = requestHtml.responseText
        });
        openMarker = markersArray[i].marker;
        return true;
      }
    }
    // didn't find it, manually fetch & add it
    var requestJson = $.ajax({
      type: 'GET',
      url: '/locations/marker.json?id=' + id,
      dataType: 'json'
    });
    requestJson.done(function(json){
      add_markers_from_json(json,false);
      // make marker clickable
      add_marker_infobox(markersArray.length-1);
      // filter and labels
      if(labelsOn) labelize_markers();
      search_filter(last_search);
      // open infobox
      var requestHtml = $.ajax({
        type: 'GET',
        url: '/locations/' + id + '/infobox',
        dataType: 'html'
      });
      requestHtml.done(function(html){
        var infowindow = new google.maps.InfoWindow({content: html });
        google.maps.event.addListener(infowindow,'closeclick',function(){
          openInfoWindow = null;
          openMarker = null;
        });
        infowindow.open(map, markersArray[markersArray.length-1].marker);
        openInfoWindow = infowindow;
        openInfoWindowHtml = requestHtml.responseText;
      });
      openMarker = markersArray[markersArray.length-1];
    });
    return true;
  }

  function add_marker_infobox(i){ 
    var marker = markersArray[i].marker;
    var id = markersArray[i].id;
    google.maps.event.addListener(marker, 'click', function(){
      if(openMarker === marker) return;
      if(openInfoWindow != null) openInfoWindow.close()
      var requestHtml = $.ajax({
        type: 'GET',
        url: '/locations/' + id + '/infobox',
        dataType: 'html'
      });
      requestHtml.done(function(html){
        var infowindow = new google.maps.InfoWindow({content: html });
        google.maps.event.addListener(infowindow,'closeclick',function(){
          openInfoWindow = null;
          openMarker = null;
        });
        infowindow.open(map, marker);
        openInfoWindow = infowindow;
        openInfoWindowHtml = requestHtml.responseText
      });
      openMarker = marker;
    });
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

  function do_markers(bounds,skip_ids,muni,type_filter){
    var bstr = '';
    if(bounds != undefined){
      bstr = 'nelat=' + bounds.getNorthEast().lat() + '&nelng=' + bounds.getNorthEast().lng() + 
             '&swlat=' + bounds.getSouthWest().lat() + '&swlng=' + bounds.getSouthWest().lng();
    }
    mstr = 0;
    if(muni) mstr = 1;
    var tstr = '';
    if(type_filter != undefined){
      tstr = '&t='+type_filter;
    }
    if(pb != null) pb.start(200);
    var request = $.ajax({
      type: 'GET',
      url: '/locations/markers.json?muni=' + mstr + '&' + bstr + tstr,
      dataType: 'json'
    });
    request.done(function(json){
      if(pb != null) pb.setTotal(json.length);
      // remove any cluster-type markers 
      var i = find_marker(null);
      while((i != undefined) && (i >= 0)){
        markersArray[i].marker.setMap(null);
        markersArray[i].marker = null;
        markersArray[i].id = null;
        markersArray.splice(i,1);
        i = find_marker(null);
      }
      add_markers_from_json(json,false,skip_ids);
      // make markers clickable
      for (var i = 0; i < markersArray.length; ++i) {
        add_marker_infobox(i);
      }

      if(labelsOn) labelize_markers();

      n = json.length;
      if(n > 0){
        nt = json[0]["n"];
        if((n < nt) && (nt >= 500)){
          $("#pg_text").html(n + " of " + nt + " visible");
        }else{
          pb.hide();
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

  function recenter_map(){
    navigator.geolocation.getCurrentPosition(function(position){
        var lat = position.coords.latitude;
        var lon = position.coords.longitude;
        loc = new google.maps.LatLng(lat,lon);
        map.panTo(loc);
        map.setZoom(15);
        $('#hidden_controls').show();
        // update markers once we're done panning and zooming
        google.maps.event.addListenerOnce(map, 'idle', function(){
          do_markers(map.getBounds(),null,$('#muni').is(':checked'));
        });
        var cross = new google.maps.Marker({
          icon: '/cross.png',
          position: new google.maps.LatLng(lat,lon), 
          map: map,
          draggable: false,
        });
    },function(error){
      //use error.code to determine what went wrong
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
  function place_add_marker(latLng) {
    var marker = new google.maps.Marker({
        position: latLng, 
        map: map,
        draggable: true
    });
    markersArray.push({marker: marker, id: -1, type: "point"});
    // Set and open infowindow
    var infowindow = new google.maps.InfoWindow({
        content: '<div id="newmarker">' +
                 '<a href="/locations/new?lat=' + latLng.lat() + '&lng=' + latLng.lng() + 
                 '" data-ajax="false" rel="external">Click to add a source here</a><br><span class="subtext">You can drag this thing too</span></div>'
    });
    infowindow.open(map,marker);
    // Listen to drag & drop
    google.maps.event.addListener(marker, 'dragend', function() {
        var infowindow = new google.maps.InfoWindow({
          content: '<div id="newmarker">' +
                 '<a href="/locations/new?lat=' + this.getPosition().lat() + '&lng=' + this.getPosition().lng() + 
                 '" data-ajax="false" rel="external">Click to add a source here</a><br><span class="subtext">You can drag this thing too</span></div>'
        });
        infowindow.open(map,marker);
    });
    google.maps.event.addListener(infowindow,'closeclick',function(){
      remove_add_marker();
    });
  }

  function labelize_markers() {
       // if we're still in clustered mode, don't label
       if(map.getZoom() <= 11) return;
       var len = markersArray.length;
       for(var i = 0; i < len; i++){
         if(!markersArray[i].marker.getVisible()) continue;
         if(markersArray[i].label != undefined) continue;
         var pos = markersArray[i].marker.getPosition();
         var mapLabel = new MapLabel({
           text: markersArray[i].marker.getTitle(),
           // bad hack to prevent marker from overlapping with label
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

  function delabelize_markers() {
        var len = markersArray.length;
        for(var i = 0; i < len; i++){
          markersArray[i].marker.unbind('map');
          markersArray[i].marker.unbind('position');
          markersArray[i].label.set('text','');
          markersArray[i].label.set('map',null);
          markersArray[i].label = null;
        }
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

  // see: https://developers.google.com/maps/documentation/javascript/geocoding 
  function recenter_map_to_address() {
    geocoder.geocode( { 'address': $("#address").val() }, function(results, status) {
      if (status == google.maps.GeocoderStatus.OK) {
        var bounds = results[0].geometry.bounds;
        var loc = results[0].geometry.location;
        if(bounds == undefined){       
          map.setZoom(15)
          map.panTo(loc);
        }else{
          map.fitBounds(bounds);
        }
        var cross = new google.maps.Marker({
          icon: '/cross.png',
          position: loc, 
          map: map,
          draggable: false
        });
      } else {
        alert("Geocode was not successful for the following reason: " + status);
      }
    });
  }
  
function update_attribution() {
  var typeid = map.getMapTypeId();
  if(typeid == 'toner-lite'){
    $('#stamen_attribution').show();
  }else{
    $('#stamen_attribution').hide();
  }
 }

// Adds a bicycle layer toggle to the map
function bicycleControl(map) {

  // Initialize control div
  var controlDiv = document.createElement('div');
  map.controls[google.maps.ControlPosition.TOP_RIGHT].push(controlDiv);
  controlDiv.id = 'maptype_button';
  controlDiv.title = 'Show bicycle map';
  controlDiv.innerHTML = 'Bicycling';

  // Initialize map with control off
  var toggled = false;
  var layer = new google.maps.BicyclingLayer();

  // Setup the click event listeners
  google.maps.event.addDomListener(controlDiv, 'click', function() {
    if (toggled) {
      layer.setMap(null);
      controlDiv.style.fontWeight = 'normal';
      controlDiv.style.color = '#565656';
      controlDiv.style.boxShadow = '0px 1px 1px -1px rgba(0, 0, 0, 0.4)';
      toggled = 0;
    } else {
      layer.setMap(map);
      controlDiv.style.fontWeight = '500';
      controlDiv.style.color = '#000';
      controlDiv.style.boxShadow = '0px 1px 1px -1px rgba(0, 0, 0, 0.6)';
      toggled = 1;
    }
  });
}

// Adds Key Drag Zoom to the map
// http://google-maps-utility-library-v3.googlecode.com/svn/tags/keydragzoom/
function keyDragZoom(map) {
	map.enableKeyDragZoom({
		visualEnabled: true,
		visualPosition: google.maps.ControlPosition.LEFT,
		visualPositionOffset: new google.maps.Size(35, 0),
		visualPositionIndex: null,
		visualSprite: "http://maps.gstatic.com/mapfiles/ftr/controls/dragzoom_btn.png",
		visualSize: new google.maps.Size(20, 20),
		visualTips: {
		 off: "Turn on drag-zoom (or hold 'Shift' key)",
		 on: "Turn off drag-zoom"
		},
		key: "shift",
		boxStyle: {border: "1px solid #736AFF"},
		veilStyle: {backgroundColor: "gray", opacity: 0.25, cursor: "crosshair"}
	 });
}

// Toggles on/off route controls below footer of location infowindow
function toggle_route_controls() {
    if(showing_route_controls){
      openInfoWindow.setContent(openInfoWindowHtml);
      showing_route_controls = false;
    }else{
      tempHtml = openInfoWindowHtml.replace('<div id="route_controls" style="display:none;','<div id="route_controls" style="display:block;').replace('routes<img src="/smarrow_down.png"','routes<img src="/smarrow_up.png"');
      openInfoWindow.setContent(tempHtml);
      showing_route_controls = true;
    }
}

// Zooms to currently open marker
function zoom_to_marker() {
  maxZoom = map.mapTypes[map.mapTypeId].maxZoom;
  map.panTo(openMarker.position);
  map.setZoom(maxZoom);
}
