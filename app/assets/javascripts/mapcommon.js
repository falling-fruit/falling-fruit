  // ================= globals ==================

  var map;
  var geocoder;
  var prior_bounds = null;
  var prior_zoom = null;
  var markersArray = [];
  var labelsArray = [];
  var openMarker = null;
  var openInfoWindow = null;
  var markerIdArray = [];
  var boundMarkersArray = [];
  var labelsOn = false;
  var last_search = null;
  var pb = null;
  var markersLoadedEvent = document.createEvent("Event");
  markersLoadedEvent.initEvent("markersloaded",true,true);

  // ================= functions =================

  // will avoid adding duplicate markers (using location id)
  function add_markers_from_json(mdata,rich,skip_id){
    var len = mdata.length;
    for(var i = 0; i < len; i++){
      var lid = mdata[i]["location_id"];
      if((skip_id != undefined) && (skip_id == parseInt(lid))) continue;
      if((lid != undefined) && (markerIdArray.indexOf(lid) >= 0)) continue;
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
        markersArray.push(m);
        markerIdArray.push(mdata[i]["location_id"]);
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
          markersArray.push(m);
          markerIdArray.push(undefined);
      }
    }
    document.dispatchEvent(markersLoadedEvent);
  }

  // Removes the overlays from the map
  function clear_markers() {
    if (markersArray) {
      for (var i = 0; i < markersArray.length; i++ ) {
        markersArray[i].setMap(null);
        markersArray[i] = null;
        markerIdArray[i] = null;
      }
    }
    markersArray.length = 0;
    markersArray = [];
    markerIdArray.length = 0;
    makerIdArray = [];
  }

  function do_clusters(bounds,zoom,muni){
      var bstr = '';
      var gstr = 'method=grid&grid=' + zoom;
      if(bounds != undefined){
        var ne = bounds.getNorthEast();
        var sw = bounds.getSouthWest();
        bstr = 'nelat=' + ne.lat() + '&nelng=' + ne.lng() + 
               '&swlat=' + sw.lat() + '&swlng=' + sw.lng();
      }
      mstr = 0;
      if(muni) mstr = 1;
      if(pb != null) pb.start(200);
      new Ajax.Request('/locations/cluster.json?muni=' + mstr + '&' + gstr + '&' + bstr, {
                method: 'get',
                onSuccess: function(response) {
                  json = jQuery.parseJSON(response.responseText);
                  if(json.length > 0){
                    clear_markers();
                    add_markers_from_json(json,true);
                  }
                  if(pb != null) pb.hide();
                },
                onFailure: function() {  
                  if(pb != null) pb.hide();
                }
              });
  }

  function open_marker_by_id(id){
    for (var i = 0; i < markersArray.length; i++ ) {
      if(markerIdArray[i] == id){
        new Ajax.Request('/locations/' + id + '/infobox', {
          onSuccess: function(response) {
            var infowindow = new google.maps.InfoWindow({content: response.responseText });
            google.maps.event.addListener(infowindow,'closeclick',function(){
              openInfoWindow = null;
              openMarker = null;
            });
            infowindow.open(map, markersArray[i]);
            openInfoWindow = infowindow;
          }
        });
        openMarker = markersArray[i];
        return true;
      }
    }
    return false;
  }

  function add_marker_infobox(i){ 
    var marker = markersArray[i];
    var id = markerIdArray[i];
    google.maps.event.addListener(marker, 'click', function(){
      if(openMarker === marker) return;
      if(openInfoWindow != null) openInfoWindow.close()
      new Ajax.Request('/locations/' + id + '/infobox', {
        onSuccess: function(response) {
          var infowindow = new google.maps.InfoWindow({content: response.responseText });
          google.maps.event.addListener(infowindow,'closeclick',function(){
            openInfoWindow = null;
            openMarker = null;
          });
          infowindow.open(map, marker);
          openInfoWindow = infowindow;
        }
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

  function do_markers(bounds,skip_id,muni){
    var bstr = '';
    if(bounds != undefined){
      bstr = 'nelat=' + bounds.getNorthEast().lat() + '&nelng=' + bounds.getNorthEast().lng() + 
             '&swlat=' + bounds.getSouthWest().lat() + '&swlng=' + bounds.getSouthWest().lng();
    }
    mstr = 0;
    if(muni) mstr = 1;
    if(pb != null) pb.start(200);
    new Ajax.Request('/locations/markers.json?muni=' + mstr + '&' + bstr, {
              method: 'get',
              onSuccess: function(response) {
                json = jQuery.parseJSON(response.responseText);
                if(pb != null) pb.setTotal(json.length);
                // remove any cluster-type markers 
                var i = markerIdArray.indexOf(undefined);
                while(i >= 0){
                  markersArray[i].setMap(null);
                  markersArray[i] = null;
                  markerIdArray[i] = null;
                  markersArray.splice(i,1);
                  markerIdArray.splice(i,1);
                  i = markerIdArray.indexOf(undefined);
                }
                add_markers_from_json(json,false,skip_id);
                // make markers clickable
                for (var i = 0; i < markersArray.length; ++i) {
                  add_marker_infobox(i);
                }

                if(labelsOn) labelize_markers();

                n = json.length;
                if(n > 0){
                  nt = json[0]["n"];
                  if((n < nt) && (nt >= 500)){
                    $("pg_text").innerHTML = n + " of " + nt + " visible";
                  }else{
                    pb.hide();
                  }
                }else{
                  pb.hide();
                }

                search_filter(last_search);
              },
              onFailure: function() { 
                if(pb != null) pb.hide();
              }
    });
  }

  function recenter_map(){
    navigator.geolocation.getCurrentPosition(function(position){
        var lat = position.coords.latitude;
        var lon = position.coords.longitude;
        loc = new google.maps.LatLng(lat,lon);
        map.panTo(loc);
        map.setZoom(15);
        $('hidden_controls').show();
        // update markers once we're done panning and zooming
        google.maps.event.addListenerOnce(map, 'idle', function(){
          do_markers(map.getBounds(),null,$('muni').checked);
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
    var i = markerIdArray.indexOf(-1);
    if(i < 0) return;
    var marker = markersArray[i];
    var id = markerIdArray[i];
    marker.setMap(null);
    markerIdArray.splice(i,1);
    markersArray.splice(i,1);
  }

  // Add a marker with an open infowindow
  function place_add_marker(latLng) {
    var marker = new google.maps.Marker({
        position: latLng, 
        map: map,
        draggable: true
    });
    markersArray.push(marker);
    markerIdArray.push(-1);
    // Set and open infowindow
    var infowindow = new google.maps.InfoWindow({
        content: '<div id="newmarker">' +
                 '<a href="/locations/new?lat=' + latLng.lat() + '&lng=' + latLng.lng() + 
                 '">Click to add a source here</a><br><span class="subtext">(You can drag this thing too)</span></div>'
    });
    infowindow.open(map,marker);
    // Listen to drag & drop
    google.maps.event.addListener(marker, 'dragend', function() {
        var infowindow = new google.maps.InfoWindow({
          content: '<div id="newmarker">' +
                 '<a href="/locations/new?lat=' + this.getPosition().lat() + '&lng=' + this.getPosition().lng() + 
                 '">Click to add a source here</a><br><span class="subtext">(You can drag this thing too)</span></div>'
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
         var marker = markersArray[i];
         if(!marker.getVisible()) continue;
         var pos = marker.getPosition();
         var mapLabel = new MapLabel({
           text: marker.getTitle(),
           // bad hack to prevent marker from overlapping with label
           position: new google.maps.LatLng(pos.lat()-0.00003,pos.lng()),
           map: map,
           fontSize: 13,
           fontColor: '#990000',
           strokeColor: '#efe8de',
           strokeWeight: 5,
           align: 'center'
         });
         labelsArray.push(mapLabel);
         boundMarkersArray.push(marker);
         marker.bindTo('map', mapLabel);
       } 
       labelsOn = true;
  }

  function delabelize_markers() {
        var len = boundMarkersArray.length;
        for(var i = 0; i < len; i++){
          var marker = boundMarkersArray[i]
          marker.unbind('map');
          marker.unbind('position');
          boundMarkersArray[i] = null;
        }
        boundMarkersArray = [];
        len = labelsArray.length;
        for(var i = 0; i < len; i++){
          var lab = labelsArray[i];
          lab.set('text','');
          lab.set('map',null);
          labelsArray[i] = null;
        }
        labelsArray = [];
        labelsOn = false;
  }

  function search_filter(search){
    if(search == null) return;
    last_search = search;
    var len = markersArray.length;
    for(var i = 0; i < len; i++){
      var marker = markersArray[i];
      var label = labelsArray[i];
      if(marker == undefined) continue;
      if(search == ""){
        marker.setVisible(true);
        if(label != undefined) label.set('map',map);
      }else if(marker.getTitle().search(new RegExp(search,"i")) >= 0){
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
    geocoder.geocode( { 'address': $("address").value }, function(results, status) {
      if (status == google.maps.GeocoderStatus.OK) {
        map.setZoom(15)
        map.panTo(results[0].geometry.location);
        $('hidden_controls').show();
        // update markers once we're done panning and zooming
        google.maps.event.addListenerOnce(map, 'idle', function(){
          do_markers(map.getBounds(),null,$('muni').checked);
        });
        var cross = new google.maps.Marker({
          icon: '/cross.png',
          position: results[0].geometry.location, 
          map: map,
          draggable: false
        });
      } else {
        alert("Geocode was not successful for the following reason: " + status);
      }
    });
  }
