// http://jsfiddle.net/Nfx6A/5/

$('input,textarea').keyup(function(){
   setDirection($(this));
})

function checkRTL(s) {
  var ltrChars = 'A-Za-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02B8\u0300-\u0590\u0800-\u1FFF'+'\u2C00-\uFB1C\uFDFE-\uFE6F\uFEFD-\uFFFF',
      rtlChars = '\u0591-\u07FF\uFB1D-\uFDFD\uFE70-\uFEFC',
      rtlDirCheck = new RegExp('^[^'+ltrChars+']*['+rtlChars+']');
  return rtlDirCheck.test(s);
};

function setDirection(selector) {
  var string = selector.val();
  for (var i=0; i<string.length; i++) {
    var isRTL = checkRTL( string[i] );
    var dir = isRTL ? 'RTL' : 'LTR';
    if (dir === 'RTL') var finalDirection = 'RTL';
    if (finalDirection == 'RTL') dir = 'RTL';
  }
  if (dir=='LTR') {
    selector.css("direction", "ltr");
  } else {
    selector.css("direction", "rtl");
  }
};
