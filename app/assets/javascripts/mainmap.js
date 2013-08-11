function data_link(){
  var muni = $('#muni').is(':checked'); 
  var bounds = map.getBounds();
  var bstr = 'nelat=' + bounds.getNorthEast().lat() + '&nelng=' + bounds.getNorthEast().lng() +
         '&swlat=' + bounds.getSouthWest().lat() + '&swlng=' + bounds.getSouthWest().lng();
  var mstr = 0;
  if(muni) mstr = 1;
  return '/locations/data.csv?muni=' + mstr + '&' + bstr;
}


function update_permalink(){
  var center = map.getCenter();
  var typeid = map.getMapTypeId();
  var zoom = map.getZoom();
  var permalink = '/?z=' + zoom + '&y=' + sprintf('%.05f',center.lat()) +
    '&x=' + sprintf('%.05f',center.lng()) + '&m=' + $('#muni').is(":checked") + "&t=" + typeid;
  $('#permalink').attr('href',permalink);
}

function update_url(object) {
  window.history.pushState({},"", $(object).attr('href'));
}

function show_embed_html(object){
  var center = map.getCenter();
  var typeid = map.getMapTypeId();
  var zoom = map.getZoom();
  var http = location.protocol;
  var slashes = http.concat("//");
  var host = slashes.concat(window.location.hostname);
  $(object).text('<iframe src="' + host + '/locations/embed?z=' + zoom + '&y=' + sprintf('%.05f',center.lat()) +
    '&x=' + sprintf('%.05f',center.lng()) + '&m=' + $('#muni').is(":checked") + "&t=" + typeid + 
    '&width=400&height=400" width=400 height=400 scrolling="no" style="border: 0;"></iframe>').dialog(); 
}

function update_display(force,force_zoom){
  var zoom = map.getZoom();
  if(force_zoom != undefined) zoom = force_zoom;
  var bounds = map.getBounds();
  var center = map.getCenter();
  update_permalink();
  if(zoom <= 12){
    $('#hidden_controls').hide();
    $('#export_data').hide();
    var height = document.getElementById('searchbar').offsetHeight + document.getElementById('menubar').offsetHeight + 
                 document.getElementById('logobar').offsetHeight;
    document.getElementById('mainmap_container').style.top = height + 'px';
    if(zoom > 8)
      do_clusters(bounds,zoom,$('#muni').is(':checked'));
    else if((zoom != prior_zoom) || force)
      do_clusters(undefined,zoom,$('#muni').is(':checked'));
  }else if(zoom >= 13){
    $('#get_data_link').attr('href',data_link());
    $('#hidden_controls').show();
    $('#export_data').show();
    do_markers(bounds,null,$('#muni').is(':checked'));
    var height = document.getElementById('searchbar').offsetHeight + document.getElementById('menubar').offsetHeight + document.getElementById('logobar').offsetHeight;
    document.getElementById('mainmap_container').style.top = height + 'px';
  }
  prior_zoom = zoom;
  prior_bounds = bounds;
}

function update_display_embedded(force,force_zoom,muni){
  var zoom = map.getZoom();
  if(force_zoom != undefined) zoom = force_zoom;
  var bounds = map.getBounds();
  var center = map.getCenter();
  if(zoom <= 12){
    if(zoom > 8)
      do_clusters(bounds,zoom,muni);
    else if((zoom != prior_zoom) || force)
      do_clusters(undefined,zoom,muni);
  }else if(zoom >= 13){
    do_markers(bounds,null,muni);
  }
  prior_zoom = zoom;
  prior_bounds = bounds;
}
