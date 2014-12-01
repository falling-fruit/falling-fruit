Shadowbox.init({
  players: ['img'], 
  skipSetup: true,
  cache: false,
  animate: false,
  animateFade: false,
  showOverlay: true,
  overlayOpacity: 0.6,
  counterType: "default",
  continuous: true,
  displayCounter: true,
  // Prevent arrows from switching photos and panning map
  // Custom next on-image control
  onOpen: function() {
    if (typeof map == "object" & typeof map.setOptions == "function") map.setOptions({keyboardShortcuts: false})
    var nextLink = $('<a>').attr('id', 'sb-custom-nav-next');
    if (Shadowbox.hasNext()) {
      nextLink.bind('click', function(event) {Shadowbox.next();});
    } else {
      nextLink.bind('click', function(event) {Shadowbox.close();});
    }
    $('#sb-body').append(nextLink);
    // previous currently unused
    // sb-custom-nav-previous
  },
  onClose: function() {
    if (typeof map == "object" & typeof map.setOptions == "function") map.setOptions({keyboardShortcuts: true})
    $('#sb-custom-nav-next').remove();
  },
});