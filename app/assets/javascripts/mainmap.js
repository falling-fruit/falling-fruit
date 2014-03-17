// ================= functions =================
  
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
    '&x=' + sprintf('%.05f',center.lng()) + '&m=' + $('#muni').is(":checked") + "&t=" +
     typeid + '&l=' + $('#labels').is(":checked");
  if (type_filter != undefined) {
  	permalink = permalink + "&f=" + type_filter;
  }
  $('#permalink').attr('href',permalink);
}

// function update_url(object) {
//   window.history.pushState(undefined, "", $(object).attr('href'));
// }

// Force url updates before leaving page (does not work on refresh)
// better?: http://stackoverflow.com/questions/824349/modify-the-url-without-reloading-the-page/3354511#3354511
// $(window).unload(function () {
// 	if ($('#location_link').length > 0) {
// 		update_url('#location_link');
// 	} else if ($('#permalink').length > 0) {
// 		update_permalink();
// 		update_url('#permalink');
// 	}
// });

function show_embed_html(object){
  var center = map.getCenter();
  var typeid = map.getMapTypeId();
  var zoom = map.getZoom();
  var http = location.protocol;
  var slashes = http.concat("//");
  var host = slashes.concat(window.location.hostname);
  if (type_filter != undefined) {
  	var fstr = "&f=" + type_filter;
  } else {
    var fstr = "";
  }
  $(object).text('<iframe src="' + host + '/locations/embed?z=' + zoom + '&y=' + sprintf('%.05f',center.lat()) +
    '&x=' + sprintf('%.05f',center.lng()) + '&m=' + $('#muni').is(":checked") + "&t=" + typeid + fstr +
    '&l=' + $('#labels').is(":checked") + 
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
  $('#s2id_type_filter').select2('disable', true);
  if (typeof type_filter != 'number') type_filter = undefined;
  var zoom = map.getZoom();
  if (force_zoom != undefined) zoom = force_zoom;
  var bounds = map.getBounds();
  if (force_bounds != undefined) bounds = force_bounds;
  update_permalink();
  if (zoom <= 12) {
    if (prior_zoom > 12) hide_map_controls();
    if (zoom > 8) {
      do_clusters(bounds,zoom,$('#muni').is(':checked'),type_filter);
    } else if ((zoom != prior_zoom) || force) {
      do_clusters(undefined,zoom,$('#muni').is(':checked'),type_filter);
    }
    if (!mobile) do_cluster_types(bounds,zoom,$('#muni').is(':checked'));
  } else if (zoom >= 13) {
    if (prior_zoom < 13) {
      types_hash = {};
      show_map_controls();
    }
    do_markers(bounds,skip_ids,$('#muni').is(':checked'),type_filter);
  }
  prior_zoom = zoom;
  prior_bounds = bounds;
  $('#s2id_type_filter').select2('enable', true);
}

function hide_map_controls() {
    $('#hidden_controls').hide();
    $('#export_data').hide();
    if (!mobile) {
			if (document.getElementById('searchbar') != undefined) {
				var height = document.getElementById('searchbar').offsetHeight + document.getElementById('menubar').offsetHeight + 
										 document.getElementById('logobar').offsetHeight;
				document.getElementById('mainmap_container').style.top = height + 'px';
			}
  }
}

function show_map_controls() {
    $('#get_data_link').attr('href',data_link());
    $('#hidden_controls').show();
    $('#export_data').show();
    if (!mobile) {
			if (document.getElementById('searchbar') != undefined) {
				var height = document.getElementById('searchbar').offsetHeight + document.getElementById('menubar').offsetHeight + document.getElementById('logobar').offsetHeight;
				document.getElementById('mainmap_container').style.top = height + 'px';
			}
		}
}

function update_display_embedded(force, force_zoom, muni) {
  var zoom = map.getZoom();
  if(force_zoom != undefined) zoom = force_zoom;
  var bounds = map.getBounds();
  var center = map.getCenter();
  if (zoom <= 12) {
    if (zoom > 8)
      do_clusters(bounds,zoom,muni,type_filter);
    else if ((zoom != prior_zoom) || force)
      do_clusters(undefined,zoom,muni,type_filter);
  } else if (zoom >= 13) {
    do_markers(bounds,null,muni,type_filter);
  }
  prior_zoom = zoom;
  prior_bounds = bounds;
}
