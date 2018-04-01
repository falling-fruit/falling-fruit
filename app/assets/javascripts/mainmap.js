// ================= functions =================

function data_link(){
  var muni = $('#muni').is(':checked');
  var bounds = map.getBounds();
  var bstr = 'nelat=' + bounds.getNorthEast().lat() + '&nelng=' + bounds.getNorthEast().lng() +
         '&swlat=' + bounds.getSouthWest().lat() + '&swlng=' + bounds.getSouthWest().lng();
  var mstr = 0;
  if(muni) mstr = 1;
  return '/locations/data.csv?muni=' + mstr + '&' + bstr + '&locale=' + I18n.locale;
}

function update_permalink(){
  var center = map.getCenter();
  var typeid = map.getMapTypeId();
  var zoom = map.getZoom();
  var permalink = '/?z=' + zoom + '&y=' + sprintf('%.05f',center.lat()) +
    '&x=' + sprintf('%.05f',center.lng()) + '&m=' + $('#muni').is(":checked") + "&t=" +
     typeid + '&l=' + $('#labels').is(":checked") + '&locale=' + I18n.locale;
  if (type_filter && type_filter.length > 0 && type_filter.sort().toString() != type_filter_default.sort().toString()) {
    permalink = permalink + "&f=" + type_filter.join(",");
  }
  if (cats != undefined){
    permalink = permalink + "&c=" + cats;
  }
  $('#permalink').attr('href',permalink);
}

function update_url(object) {
  window.history.pushState(undefined, "", $(object).attr('href'));
}

// Force url updates before leaving page (does not work on refresh)
// better?: http://stackoverflow.com/questions/824349/modify-the-url-without-reloading-the-page/3354511#3354511
// $(window).unload(function () {
//   if ($('#location_link').length > 0) {
//     update_url('#location_link');
//   } else if ($('#permalink').length > 0) {
//     update_permalink();
//     update_url('#permalink');
//   }
// });

function show_embed_html(object){
  var center = map.getCenter();
  var typeid = map.getMapTypeId();
  var zoom = map.getZoom();
  var http = location.protocol;
  var slashes = http.concat("//");
  var host = slashes.concat(window.location.hostname);
  if (type_filter && type_filter.length > 0 && type_filter.sort().toString() != type_filter_default.sort().toString()) {
    var fstr = "&f=" + type_filter.join(",");
  } else {
    var fstr = "";
  }
  if (cats != undefined) {
    var cstr = "&c=" + cats;
  } else {
    var cstr = "";
  }
  $(object).text('<iframe src="' + host + '/locations/embed?z=' + zoom + '&y=' + sprintf('%.05f',center.lat()) +
    '&x=' + sprintf('%.05f',center.lng()) + '&m=' + $('#muni').is(":checked") + "&t=" + typeid + fstr + cstr +
    '&l=' + $('#labels').is(":checked") + '&locale=' + I18n.locale +
    '" width=640 height=600 scrolling="no" style="border:none;"></iframe>').dialog({
      closeText: "close",
      modal: true,
      width: 'auto',
      minHeight: '5em',
      resizable: false,
      draggable: false,
      dialogClass: "dialog_grey"
    });
}

function show_observation_html(object){
  var center = map.getCenter();
  var typeid = map.getMapTypeId();
  var zoom = map.getZoom();
  var http = location.protocol;
  var slashes = http.concat("//");
  var host = slashes.concat(window.location.hostname);
  $(object).text('<iframe src="' + host + '/locations/embed?z=' + zoom + '&y=' + sprintf('%.05f',center.lat()) +
    '&x=' + sprintf('%.05f',center.lng()) + '&m=' + $('#muni').is(":checked") + "&t=" + typeid +
    '" width=640 height=600 scrolling="no" style="border:none;"></iframe>').dialog({
      closeText: "close",
      modal: true,
      width: 'auto',
      minHeight: '5em',
      resizable: true,
      draggable: false,
      dialogClass: "dialog_grey"
    });
}

function update_display(force,force_zoom,force_bounds){
  var zoom = map.getZoom();
  if (force_zoom != undefined) zoom = force_zoom;
  var bounds = map.getBounds();
  if (force_bounds != undefined) bounds = force_bounds;
  update_permalink();
  if (zoom <= 12) {
    if (prior_zoom > 12) hide_map_controls();
    do_clusters(bounds,zoom,$('#muni').is(':checked'),type_filter);
  } else if (zoom >= 13) {
    if (prior_zoom < 13) {
      types_hash = {};
      show_map_controls();
    }
    do_markers(bounds,skip_ids,$('#muni').is(':checked'),type_filter,cats,$('#invasive').is(':checked'));
  }
  prior_zoom = zoom;
  prior_bounds = bounds;
}

function hide_map_controls() {
  $('#hidden_controls').hide();
  $('#export_data').hide();
  $('#invasive_span').hide();
  resize_map();
}

function show_map_controls() {
  $('#get_data_link').attr('href',data_link());
  $('#hidden_controls').show();
  $('#export_data').show();
  $('#invasive_span').show();
  resize_map();
}

function resize_map() {
  if(document.getElementById('searchbar') == undefined) return;
  var headerHeight = document.getElementById('searchbar').offsetHeight + document.getElementById('menubar').offsetHeight + document.getElementById('logobar').offsetHeight;
  if (document.getElementById('mainmap_container') != undefined) {
    document.getElementById('mainmap_container').style.top = headerHeight + 'px';
  }
  if (document.getElementById('sidebar_container') != undefined) {
    document.getElementById('sidebar_container').style.top = headerHeight + 'px';
  }
}

function update_display_embedded(force, force_zoom, muni) {
  var zoom = map.getZoom();
  if(force_zoom != undefined) zoom = force_zoom;
  var bounds = map.getBounds();
  var center = map.getCenter();
  if (zoom <= 12) {
    do_clusters(bounds, zoom, muni, type_filter);
  } else if (zoom >= 13) {
    do_markers(bounds,null,muni,type_filter,cats,false);
  }
  prior_zoom = zoom;
  prior_bounds = bounds;
}
