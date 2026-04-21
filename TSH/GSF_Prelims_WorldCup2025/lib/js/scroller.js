    var lastoffset = -1;
    function scroller () {
      var h;
      var offset;
      if (typeof(window.innerHeight == 'number')) {
	// non-IE
	h = window.innerHeight;
        }
      else if (document.documentElement && document.documentElement.clientHeight) {
	// IE 6+ standards compliant
	h = document.documentElement.clientHeight;
	}
      else {
	// IE 4
	h = document.body.clientHeight;
        }
      if (typeof(window.pageYOffset) == 'number') {
	// netscape
	offset = window.pageYOffset;
        }
      else if (document.body && document.body.scrollTop) {
	// DOM
	offset = document.body.scrollTop;
        }
      else {
	// IE6 standards compliant
	offset = document.documentElement.scrollTop;
        }
      window.scrollTo(0, offset + 1);
      if (lastoffset == offset) {
    	setTimeout('backtotop()', 1000);
	}
      else {
  	setTimeout('scroller()', 30);
  	}
      lastoffset = offset;
    }
    function backtotop () {
      window.scrollTo(0,0);
      setTimeout('scroller()', 1000);
      }
    setTimeout('scroller()', 300);
