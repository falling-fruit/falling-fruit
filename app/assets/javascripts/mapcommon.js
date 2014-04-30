  // ================= globals ==================

  var map;
  var pano;
  var pointer;
  var pano_tab = null;
  var panoClient = new google.maps.StreetViewService();
  var elevationClient = new google.maps.ElevationService();
  var geocoder = geocoder = new google.maps.Geocoder();
  var prior_bounds = null;
  var prior_zoom = null;
  var prior_url = null;
  var markersArray = [];
  var types_hash = {};
  var openInfoWindow = null;
  var showing_route_controls = false; // currently unused
  var openInfoWindowHtml = null;
  var originalTab1Height = null; // currently unused
  var originalTab2Height = null; // currently unused
  var openInfoWindowHeaderHeight = null;
  var openMarker = null;
  var openMarkerId = null;
  var labelsOn = null;
  var bicycleLayerOn = null;
  var bicycleControl = null;
  var last_search = null;
  var pb = null;
  var toner = 'toner-lite';
  var markersLoadedEvent = document.createEvent("Event");
  markersLoadedEvent.initEvent("markersloaded",true,true);
  var markersMax = 5000; // maximum markers that will display at one time...
  var markersPartial = false;
  var watchID = null; // navigator/geolocation watchID

  // ================= functions =================

  function basemap(lat,lng,zoom,type,bounds){
    
    // Enable the visual refresh
    google.maps.visualRefresh = true;
    
    var mapOptions = {
      zoom: zoom,
      mapTypeId: type,
      mapTypeControlOptions: {
      mapTypeIds: [
        google.maps.MapTypeId.ROADMAP, 
        google.maps.MapTypeId.TERRAIN, 
        google.maps.MapTypeId.SATELLITE, 
        google.maps.MapTypeId.HYBRID, 
        toner]
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
    tonerType.name = "B&W";
    map.mapTypes.set(toner, tonerType);
    if(type == toner){
      update_attribution();
    }
  
    // Turn off 45 deg imagery by default
    map.setTilt(0);
  
    // Bicycle map (and control)
    add_bicycle_control(map);
    
    // Progress bar
    pb = progressBar();
    map.controls[google.maps.ControlPosition.RIGHT].push(pb.getDiv());
    
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
      zIndex: 9999 // STILL below clusters!
    });
  
    // Close open location infowindow when map is clicked
    google.maps.event.addListener(map, 'click', function(event) {
      if (openMarker != null && openInfoWindow != null) {
        openInfoWindow.close();
        openMarker = null;
        openMarkerId = null;
        openInfoWindow = null;
      }
    });
    
    // Update attribution when map type changes
    google.maps.event.addListener(map, 'maptypeid_changed', function(event) {
      update_attribution();
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
        if(openMarkerId == lid){
          var m = openMarker; 
        }else{
          var m = new google.maps.Marker({
            icon: {
              url: mdata[i]["picture"],
              size: new google.maps.Size(w,h),
              origin: new google.maps.Point(0,0),
              // by convention, icon center is at ~40%
              anchor: new google.maps.Point(w*0.4,h*0.4)
            },
            position: new google.maps.LatLng(mdata[i]["lat"],mdata[i]["lng"]), 
            map: map,
            title: mdata[i]["title"],
            draggable: false
          });
        }
        markersArray.push({marker: m, id: mdata[i]["location_id"], type: "point", types: mdata[i]["types"], parent_types: mdata[i]["parent_types"]});
        for(var j = 0; j < mdata[i]["types"].length; j++){
          var tid = mdata[i]["types"][j];
          if(types_hash[tid] == undefined) types_hash[tid] = 1;
          else types_hash[tid] += 1;
        }
        for(var j = 0; j < mdata[i]["parent_types"].length; j++){
          var tid = mdata[i]["parent_types"][j];
          if(types_hash[tid] == undefined) types_hash[tid] = 1;
          else types_hash[tid] += 1;
        }
      } else {
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
          markersArray.push({marker: m, id: null, type: "cluster", types: [], parent_types: []});
      }
    }
    document.dispatchEvent(markersLoadedEvent);
  }

  // Removes all markers, except the open one, from the map
  function clear_markers() {
    if (markersArray == undefined || markersArray.length == 0) return;
    for (var i = 0; i < markersArray.length; i++ ) {
      // comment this line in to keep open marker between refreshes
      //if(openMarker != undefined && openMarker == markersArray[i].marker) continue;
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
      if(openMarker != undefined && markersArray[i].marker == openMarker) continue;
      if(!bounds.contains(markersArray[i].marker.getPosition())){
        for(var j = 0; j < markersArray[i].types.length; j++){
          var tid = markersArray[i].types[j];
          if(types_hash[tid] != undefined && types_hash[tid] > 0) types_hash[tid] -= 1;
          if(types_hash[tid] == 0) delete types_hash[tid];
        }
        for(var j = 0; j < markersArray[i].parent_types.length; j++){
          var tid = markersArray[i].parent_types[j];
          if(types_hash[tid] != undefined && types_hash[tid] > 0) types_hash[tid] -= 1;
          if(types_hash[tid] == 0) delete types_hash[tid];
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
      bstr = 'nelat=' + ne.lat() + '&nelng=' + ne.lng() +
             '&swlat=' + sw.lat() + '&swlng=' + sw.lng();
      return bstr;
  }

  function do_clusters(bounds,zoom,muni,type_filter) {
      var bstr = bounds_to_query_string(bounds);
      var gstr = 'method=grid&grid=' + zoom;
      if (muni) mstr = '';
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
        clear_markers();
        if(json.length > 0){
          add_markers_from_json(json,true);
        }
        //do_cluster_types(bounds,zoom,muni);
        markersPartial = false;
        if(pb != null) pb.hide();
      });
      request.fail(function() {  
        if(pb != null) pb.hide();
      });
  }
  
  function do_cluster_types(bounds,zoom,muni) {
		var bstr = bounds_to_query_string(bounds);
		var gstr = 'method=grid&grid=' + zoom;
		if (muni) mstr = '';
		else mstr = 'muni=0&';
		var request = $.ajax({
			type: 'GET',
			url: '/locations/cluster_types.json?' + mstr + gstr + '&' + bstr,
			dataType: 'json'
		});
		request.done(function(json){		    
		    types_hash = {};
			if(json.length > 0){
				for(var i = 0;i < json.length; i++){
					types_hash[json[i]["id"]] = json[i]["n"];
				}
			}
			// Update count hack
				if (!mobile && type_filter != undefined) {
				  var previous_text = $('#s2id_type_filter .select2-chosen').html();
				  filter_display = $('#s2id_type_filter .select2-chosen');
				  if (types_hash[type_filter] == undefined) {
				    filter_display.html(previous_text.replace(/([0-9]+)/, 0));
				  } else {
				    filter_display.html(previous_text.replace(/([0-9]+)/, types_hash[type_filter]));
				  }
			  }
		});
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
						position: openMarker.getPosition(), 
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
						if (openMarker == marker && openInfoWindow != null) {
							if (pano.getVisible()) {
								openInfoWindow.open(pano, openMarker);
							} else {
								openInfoWindow.open(map, openMarker);
							}
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
    $('#problem_modal').load('/problems/new?location_id='+id).dialog({
      autoOpen:true, 
      title:'Report a problem', 
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
      title:'Why Unverified?', 
      width:500, 
      modal:true, 
      resizable:false, 
      draggable:false
    });
  }

  function open_inventories_help_modal(){
    $('#tree_inventories_help').dialog({
      autoOpen:true, 
      title:'What is a tree inventory?', 
      width:640, 
      modal:true, 
      resizable:false, 
      draggable:false
    });
  }
  
  function open_pending_types_help_modal(){
    $('#pending_types_help').dialog({
      autoOpen:true, 
      title:'Pending types', 
      width:500, 
      modal:true, 
      resizable:false, 
      draggable:false
    });
  }
  
// Tab 1 (info, the default) uses its original height.
function open_tab_1() {	
  p = $('#location_infowindow');
  openInfoWindowHeaderHeight = p.children('.ui-tabs-nav')[0].scrollHeight + parseFloat(p.children('.ui-tabs-nav').css('margin-bottom'));
  var max_height = 0.75 * $('#map').height() - openInfoWindowHeaderHeight;
  if (max_height < ($('#tab-1').height() - 1)) {
    $('#tab-1').height(max_height);
  }
  if (pano.getVisible()) {
            openInfoWindow.open(pano, openMarker);
          } else {
            openInfoWindow.open(map, openMarker);
          }
}

// Tab 2 (reviews) tries to get as close as possible to its content height.
function open_tab_2() {
  p = $('#location_infowindow');
	$('#tab-2').width(p.parent().width());
	var new_height = Math.min(0.75 * $('#map').height() - openInfoWindowHeaderHeight, Math.max($('#tab-1').height(), $('#tab-2').height()));
	$('#tab-2').height(new_height);
	if (pano.getVisible()) {
            	openInfoWindow.open(pano, openMarker);
          	} else {
            	openInfoWindow.open(map, openMarker);
          	}
	// Load images into Shadowbox gallery
	Shadowbox.clearCache();
	Shadowbox.setup("a[rel='shadowbox']", { gallery: "Gallery" });
}

// Tab 3 (street view) requires a minimum height to be useful.
function open_tab_3() {
  p = $('#location_infowindow');
  if ($("#tab-1").hasClass('ui-tabs-hide')) {
  	var starting_height = $('#tab-2').height();
  } else {
  	var starting_height = $('#tab-1').height();
  }
  var previous_height = $('#tab-3').height()
	var current_width = p.parent().width();
	$('#tab-3').width(current_width);
	var new_height = Math.max(starting_height, Math.min(400, 0.75 * $('#map').height() - openInfoWindowHeaderHeight));
	$('#tab-3').height(new_height);
	if (pano.getVisible()) {
            	openInfoWindow.open(pano, openMarker);
          	} else {
            	openInfoWindow.open(map, openMarker);
          	}
	if (pano_tab == null || !pano_tab.visible) {
    setup_streetview_tab(openMarker,50,true);
  } else if (previous_height != new_height) {
  	pano_tab.setVisible(true);
  }
}

  function setup_tabs(marker, infowindow) {
    p = $('#location_infowindow');
    //originalTab1Height = $('#tab-1').height();
    //originalTab2Height = $('#tab-2').height();
    // Hack: Avoids error when request arrives before DOM ready?
    if (p.children('.ui-tabs-nav')[0] != undefined) {
			openInfoWindowHeaderHeight = p.children('.ui-tabs-nav')[0].scrollHeight + parseFloat(p.children('.ui-tabs-nav').css('margin-bottom'));
			var max_height = 0.75 * $('#map').height() - openInfoWindowHeaderHeight;
			if (max_height < ($('#tab-1').height() - 1)) {
				$('#tab-1').height(max_height);
				if (pano.getVisible()) {
            	openInfoWindow.open(pano, openMarker);
          	} else {
            	openInfoWindow.open(map, openMarker);
          	}
				return;
			}
		}
  }

  function open_marker_by_id(id) {
    for (var i = 0; i < markersArray.length; i++) {
      if (markersArray[i].id == id) {
        var requestHtml = $.ajax({
          type: 'GET',
          url: '/locations/' + id + '/infobox',
          dataType: 'html'
        });
        requestHtml.done(function(html){
          var div = document.createElement('div');
          div.innerHTML = html;
          setup_streetview_tab(markersArray[i].marker,50,false);
          $(div).tabs();
          var infowindow = new google.maps.InfoWindow({content:div});
          google.maps.event.addListener(infowindow,'closeclick',function(){
            openInfoWindow = null;
            openMarker = null;
            openMarkerId = null;
          });
          if (pano.getVisible()) {
            infowindow.open(pano, markersArray[i].marker);
          } else {
            infowindow.open(map, markersArray[i].marker);
          }
          openInfoWindow = infowindow;
          openInfoWindowHtml = infowindow.content;
          google.maps.event.addListenerOnce(infowindow,'domready',function(){
            setup_tabs(markersArray[i].marker, openInfoWindow);
          });
        });
        openMarker = markersArray[i].marker;
        openMarkerId = markersArray[i].id;
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
        var div = document.createElement('div');
        div.innerHTML = html;
        setup_streetview_tab(markersArray[markersArray.length-1].marker,50,false);
        $(div).tabs();
        var infowindow = new google.maps.InfoWindow({content: div});
        google.maps.event.addListener(infowindow,'closeclick',function(){
          openInfoWindow = null;
          openMarker = null;
          openMarkerId = null;
        });
        if (pano.getVisible()) {
            infowindow.open(pano, markersArray[markersArray.length-1].marker);
          } else {
            infowindow.open(map, markersArray[markersArray.length-1].marker);
          }
          openInfoWindow = infowindow;
          openInfoWindowHtml = infowindow.content;
          google.maps.event.addListenerOnce(infowindow,'domready',function(){
            setup_tabs(markersArray[markersArray.length-1].marker, openInfoWindow);
          });
      });
      openMarker = markersArray[markersArray.length-1].marker;
      openMarkerId = markersArray[markersArray.length-1].id;
    });
    return true;
  }

  function add_marker_infobox(i) { 
    var marker = markersArray[i].marker;
    var id = markersArray[i].id;
    google.maps.event.addListener(marker, 'click', function(){
    	// Clear existing Street View tab object
    	// (doing this on map-click and close-click is not enough, marker-click is sufficient)
    	pano_tab = null;
      if (openMarker === marker) return;
      if (openInfoWindow != null) openInfoWindow.close();
      var requestHtml = $.ajax({
        type: 'GET',
        url: '/locations/' + id + '/infobox',
        dataType: 'html'
      });
      requestHtml.done(function(html) {
        var div = document.createElement('div');
        div.innerHTML = html;
        setup_streetview_tab(marker,50,false);
        $(div).tabs();
        var infowindow = new google.maps.InfoWindow({content:div});
        google.maps.event.addListener(infowindow,'closeclick',function(){
          openInfoWindow = null;
          openMarker = null;
          openMarkerId = null;
        });
        if (pano.getVisible()) {
            infowindow.open(pano, marker);
          } else {
            infowindow.open(map, marker);
          }
          openInfoWindow = infowindow;
          openInfoWindowHtml = infowindow.content;
          google.maps.event.addListenerOnce(infowindow,'domready',function(){
            setup_tabs(marker, openInfoWindow);
          });
					// Hack: Avoids incorrectly sized tab-1 in infowindow.
          setup_tabs(marker, openInfoWindow);
      });
      openMarker = marker;
      openMarkerId = id;
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

  function do_markers(bounds,skip_ids,muni,type_filter,cats) {
    if(markersArray.length >= markersMax) return;
    var bstr = bounds_to_query_string(bounds);
    mstr = 0;
    if(muni) mstr = 1;
    var tstr = '';
    var cstr = '';
    if (type_filter != undefined) {
      tstr = '&t='+type_filter;
    }
    if (cats != undefined) {
      cstr = '&c='+cats;
    }
    if(pb != null) pb.start(200);
    var request = $.ajax({
      type: 'GET',
      url: '/locations/markers.json?muni=' + mstr + '&' + bstr + tstr + cstr,
      dataType: 'json'
    });
    request.done(function(json){
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
      add_markers_from_json(json,false,skip_ids);
      if(type_filter != undefined) apply_type_filter();
      // make markers clickable
      for (var i = 0; i < markersArray.length; ++i) {
        add_marker_infobox(i);
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
			// Update count hack
			if (!mobile && type_filter != undefined) {
				filter_display = $('#s2id_type_filter .select2-chosen');
				if (types_hash[type_filter] == undefined) {
				  filter_display.html(filter_display.html().replace(/([0-9]+)/, 0));
				} else {
				  filter_display.html(filter_display.html().replace(/([0-9]+)/, types_hash[type_filter]));
				}
			}
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
    var html = $('<div id="newmarker"><a href="/locations/new?lat=' + latlng.lat() + '&lng=' + latlng.lng() + 
                 '" data-ajax="false" rel="external">Click to add a source here</a><br><span class="subtext">You can drag this thing too</span></div>');
    var infowindow = new google.maps.InfoWindow({
    	content: html[0]
    });
    infowindow.open(map,marker);
    // Listen to drag & drop
    google.maps.event.addListener(marker, 'dragend', function() {
    	$('#newmarker').children('a').attr('href', '/locations/new?lat=' + this.getPosition().lat() + '&lng=' + this.getPosition().lng());
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

  function apply_type_filter() {
    var len = markersArray.length;
    for(var i = 0; i < len; i++){
      if(markersArray[i].types == undefined || markersArray[i].parent_types == undefined) continue;
      if (markersArray[i].types.indexOf(type_filter) >= 0 || markersArray[i].parent_types.indexOf(type_filter) >= 0) {
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
		//use error.code to determine what went wrong
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
			alert("Geocode was not successful for the following reason: " + status);
		}
	});
}

function apply_geocode(latlng,bounds,zoom) {
	if (zoom == undefined) {
		var zoom = 17;
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
			var w = 19;
			var h = 19;
			var cross = new google.maps.Marker({
				icon: {
					url: '/cross.png',
					size: new google.maps.Size(w, h),
					origin: new google.maps.Point(0, 0),
					anchor: new google.maps.Point(w/2, h/2)
					},
				position: latlng, 
				map: map,
				draggable: false,
				clickable: false,
				zIndex: -9999 // so that it draws beneath any overlapping marker
			});
		}
	}
}

// Adds a bicycle layer toggle to the map
function add_bicycle_control(map) {

  // Initialize control div
  bicycleControl = document.createElement('div');
  map.controls[google.maps.ControlPosition.TOP_RIGHT].push(bicycleControl);
  bicycleControl.id = 'maptype_button';
  bicycleControl.title = 'Show bicycle map';
  bicycleControl.innerHTML = 'Bicycling';

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

// Adds Key Drag Zoom to the map (unless mobile device)
// http://google-maps-utility-library-v3.googlecode.com/svn/tags/keydragzoom/
function keyDragZoom(map) {
	if (!mobile) {
		map.enableKeyDragZoom({
			visualEnabled: true,
			visualPosition: google.maps.ControlPosition.LEFT,
			visualPositionOffset: new google.maps.Size(35, 0),
			visualPositionIndex: null,
			visualSprite: "//maps.gstatic.com/mapfiles/ftr/controls/dragzoom_btn.png",
			visualSize: new google.maps.Size(20, 20),
			visualTips: {
			 off: "Turn on drag-zoom (or hold 'Shift' key)",
			 on: "Turn off drag-zoom"
			},
			key: "shift",
			boxStyle: {border: "1px solid #736AFF"},
			veilStyle: {backgroundColor: "transparent", cursor: "crosshair"}
		 });
	}
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
    openInfoWindow.setContent(openInfoWindowHtml);
    openInfoWindow.open(map, openMarker);
}

// Toggles on/off route controls below footer of location infowindow
function toggle_problem_controls(location_id) {
  if ($('#problem_controls').css('display') == 'none') {
      $('#problem_controls').show();
      $('#problem_toggle').css('color', '#333');
    } else {
    	$('#problem_controls').hide();
    	$('#problem_toggle').css('color', '#999');
    }
    openInfoWindow.setContent(openInfoWindowHtml);
    openInfoWindow.open(map, openMarker);
}

// Zooms to currently open marker
function zoom_to_marker() {
  maxZoom = map.mapTypes[map.mapTypeId].maxZoom;
  map.panTo(openMarker.position);
  map.setZoom(maxZoom);
  if (openInfoWindow != null && openMarker != null) {
    openInfoWindow.open(map, openMarker);
  }
}

function sidebar_pan_to_location(lid,lat,lng){
  z = map.getZoom();
  if(z >= 13){
    if (openInfoWindow != null) openInfoWindow.close()
    map.panTo(new google.maps.LatLng(lat,lng));
    open_marker_by_id(lid);
  }else{
    map.panTo(new google.maps.LatLng(lat,lng))
    map.setZoom(13);
    open_marker_by_id(lid);
  }
}

// Add a marker with an open infowindow
function show_pointer(lat, lng) {
  pointer.setPosition(new google.maps.LatLng(lat,lng));
  pointer.setVisible(true);
}

function hide_pointer() {
  pointer.setVisible(false);
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
			$("#location_lat").val(lat);
			$("#location_lng").val(lng);
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
			alert("Geocode was not successful for the following reason: " + status);
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
	  alert("We do not support latitudes beyond 85 degrees (north or south).");
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

// Initialize map marker (marker) and infowindow (nag)
function place_edit_marker(lat,lng) {
	
	var latlng = new google.maps.LatLng(lat,lng)
	
	// Marker (global variable in new)
	marker = new google.maps.Marker({
		icon: '',
		position: latlng, 
		map: map,
		draggable: true
	});

  // remove geolocation watcher when marker is dragged
  if(watchID != undefined){
    google.maps.event.addListenerOnce(marker, 'dragend', function() {
      navigator.geolocation.clearWatch(watchID);
      watchID = null;
      alert('cleared');
    });
  }
	
	// Infowindow
	var html = $('<div id="editmarker"><b>Adjust the marker to change the position of the source.</b><br/><br/>Check the satellite view - the source may be visible from space!</div>');
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
	
	// Update lat, lng when marker moved
	google.maps.event.addListener(marker, 'dragend', function() {
		$("#location_lat").val(this.getPosition().lat());
		$("#location_lng").val(this.getPosition().lng());
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
	
	// Close nag if map is clicked
	google.maps.event.addListener(map, 'click', function(event) {
		if (nagOpen) {
			nag.close();
			nagOpen = false;
		}
	});
}
