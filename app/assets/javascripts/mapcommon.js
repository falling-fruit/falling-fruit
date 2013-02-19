  // ================= globals ==================

  var map;
  var geocoder;
  var prior_bounds = null;
  var prior_zoom = null;
  var allow_refresh = true;
  var markersArray = [];
  var labelsArray = [];
  var markerIdArray = [];
  var boundMarkersArray = [];
  var labelsOn = false;
  var pb = null;

  // ================= functions =================

  // will avoid adding duplicate markers (using location id)
  function add_markers_from_json(mdata,rich,skip_id){
    var len = mdata.length;
    alert(skip_id);
    for(var i = 0; i < len; i++){
      var lid = mdata[i]["location_id"];
      if((skip_id != undefined) && (skip_id == parseInt(lid)) continue;
      if((lid != undefined) && (markerIdArray.indexOf(lid) >= 0)) continue;
      if(!rich){
        var m = new google.maps.Marker({
            icon: mdata[i]["picture"],
            position: new google.maps.LatLng(mdata[i]["lat"],mdata[i]["lng"]), 
            map: map,
            title: mdata[i]["title"],
            draggable: false
          });
      }else{
        var w = mdata[i]["width"];
        var h = mdata[i]["height"];
        var wo = parseInt(w/2,10);
        var ho = parseInt(h/2,10);
        var m = new RichMarker({
            content: '<div style="background:url(' + mdata[i]["picture"] + ');height:'+h+
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
            anchor: RichMarkerPosition.MIDDLE,
          });

      }
      markersArray.push(m);
      markerIdArray.push(mdata[i]["location_id"]);
    }
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

  function do_clusters(bounds){
      if(allow_refresh == false) return;
      allow_refresh = false;
      var bstr = '';
      var gstr = 'method=grid&grid=40.0';
      if(bounds != undefined){
        var ne = bounds.getNorthEast();
        var sw = bounds.getSouthWest();
        bstr = 'nelat=' + ne.lat() + '&nelng=' + ne.lng() + 
               '&swlat=' + sw.lat() + '&swlng=' + sw.lng();
        if(map.getZoom() < 9)
          gstr = 'method=grid&grid=' + Math.abs((sw.lng()-ne.lng())/10.0);
        else
          gstr = 'method=kmeans&n=5';
      }
      new Ajax.Request('/locations/cluster.json?' + gstr + '&' + bstr, {
                method: 'get',
                onSuccess: function(response) {
                  json = jQuery.parseJSON(response.responseText);
                  if(json.length > 0){
                    clear_markers();
                    add_markers_from_json(json,true);
                  }
                  google.maps.event.addListenerOnce(map, 'idle', function(){
                    allow_refresh = true;
                  }); 
                },
                onFailure: function() { allow_refresh = true; }
              });
  }

  function add_marker_infobox(i){ 
    var marker = markersArray[i];
    var id = markerIdArray[i];
    google.maps.event.addListener(marker, 'click', function(){
      new Ajax.Request('/locations/' + id + '/infobox', {
        onSuccess: function(response) {
          var infowindow = new google.maps.InfoWindow({content: response.responseText });
          infowindow.open(map, marker)
        }
      });
    });
  }

  // FIXME: possible optimization---only grab markers for (bounds-prior_bounds) area
  function do_markers(bounds,skip_id){
    if(allow_refresh == false) return;
    allow_refresh = false;
    var bstr = '';
    if(bounds != undefined){
      bstr = 'nelat=' + bounds.getNorthEast().lat() + '&nelng=' + bounds.getNorthEast().lng() + 
             '&swlat=' + bounds.getSouthWest().lat() + '&swlng=' + bounds.getSouthWest().lng();
    }
    if(pb != null) pb.start(200);
    new Ajax.Request('/locations/markers.json?' + bstr, {
              method: 'get',
              onSuccess: function(response) {
                json = jQuery.parseJSON(response.responseText);
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
                  if(pb != null) pb.updateBar(1);
                  add_marker_infobox(i);
                }
                if(labelsOn) labelize_markers();
                allow_refresh = true;
                if(pb != null) pb.hide();
              },
              onFailure: function() { allow_refresh = true; }
    });
  }

  function recenter_map(){
    navigator.geolocation.getCurrentPosition(function(position){
        var lat = position.coords.latitude;
        var lon = position.coords.longitude;
        loc = new google.maps.LatLng(lat,lon);
        map.panTo(loc);
        map.setZoom(15);
        // update markers once we're done panning and zooming
        google.maps.event.addListenerOnce(map, 'idle', function(){
          do_markers(map.getBounds());
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
        content: '<div style="text-align: center;margin-top:1em;font-size:10pt;padding:0;font-weight:bold;">' +
                 '<a href="/locations/new?lat=' + latLng.lat() + '&lng=' + latLng.lng() + 
                 '">Click to add a source here</a><br><span class="subtext">(You can drag this thing too)</span></div>'
    });
    infowindow.open(map,marker);
    // Listen to drag & drop
    google.maps.event.addListener(marker, 'dragend', function() {
        var infowindow = new google.maps.InfoWindow({
          content: '<div style="text-align: center;margin-top:1em;font-size:10pt;padding:0;font-weight:bold;">' +
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
         var mapLabel = new MapLabel({
           text: marker.getTitle(),
           position: marker.getPosition(),
           map: map,
           fontSize: 10,
           align: 'right'
         });
         labelsArray.push(mapLabel);
         mapLabel.set('position', marker.getPosition());
         boundMarkersArray.push(marker);
         // only necessary if we want them to drag or something
         marker.bindTo('map', mapLabel);
         marker.bindTo('position', mapLabel);
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

  function search_filter(){
    var search = $('search').value;
    var len = markersArray.length;
    for(var i = 0; i < len; i++){
      var marker = markersArray[i];
      var label = labelsArray[i];
      if(marker == undefined) continue;
      if(search == ""){
        marker.setVisible(true);
        label.set('map',map);
      }else if(marker.getTitle().search(new RegExp(search,"i")) >= 0){
        marker.setVisible(true);
        label.set('map',map);
      }else{
        marker.setVisible(false);
        label.set('map',null);
      }
    }
  }

  // see: https://developers.google.com/maps/documentation/javascript/geocoding 
  function recenter_map_to_address() {
    geocoder.geocode( { 'address': $("address").value }, function(results, status) {
      if (status == google.maps.GeocoderStatus.OK) {
        map.panTo(results[0].geometry.location);
        map.setZoom(15);
        // update markers once we're done panning and zooming
        google.maps.event.addListenerOnce(map, 'idle', function(){
          do_markers(map.getBounds());
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
