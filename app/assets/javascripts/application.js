// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery_ujs
//= require jquery.ui.all
//= require jquery.cookie
//= require jquery-outside-events
//= require select2
//= require sprintf
//= require dataTables/jquery.dataTables
//= require shadowbox
//= require infowindowShadowbox

// Resize below-header content on window resize
function resize_content() {
  var siteHeaderHeight = document.getElementById('menubar').offsetHeight + document.getElementById('logobar').offsetHeight;
	if (document.getElementById('content_container') != undefined) {
		document.getElementById('content_container').style.top = siteHeaderHeight + 'px';
	} else {
    var mapHeaderHeight = siteHeaderHeight + document.getElementById('searchbar').offsetHeight;
	  if (document.getElementById('mainmap_container') != undefined) {
		  document.getElementById('mainmap_container').style.top = mapHeaderHeight + 'px';
		  google.maps.event.trigger(map,'resize');
	  }
	  if (document.getElementById('sidebar_container') != undefined) {
		  document.getElementById('sidebar_container').style.top = mapHeaderHeight + 'px';
	  }
	}
}