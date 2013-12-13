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
    '&x=' + sprintf('%.05f',center.lng()) + '&m=' + $('#muni').is(":checked") + "&t=" + typeid +
    '&l=' + $('#labels').is(":checked");
  if (type_filter != undefined) {
  	permalink = permalink + "&f=" + type_filter;
  }
  $('#permalink').attr('href',permalink);
}

function update_display(force,force_zoom){
  var zoom = map.getZoom();
  if(force_zoom != undefined) zoom = force_zoom;
  var bounds = map.getBounds();
  var center = map.getCenter();
  update_permalink();
  if(zoom <= 12){
    $('.hidden_controls').hide();
    $('#export_data').hide();
    if(zoom > 8)
      do_clusters(bounds,zoom,$('#muni').is(':checked'),type_filter);
    else if((zoom != prior_zoom) || force)
      do_clusters(undefined,zoom,$('#muni').is(':checked'),type_filter);
  }else if(zoom >= 13){
    $('#get_data_link').attr('href',data_link());
    $('.hidden_controls').show();
    $('#export_data').show();
    do_markers(bounds,null,$('#muni').is(':checked'),type_filter);
  }
  prior_zoom = zoom;
  prior_bounds = bounds;
}
