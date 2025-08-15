// Copyright &copy; 2012 John J. Chew, III <poslfit@gmail.com>
// All Rights Reserved.

var undefined;

if (!window.console) window.console = {};
if (!window.console.log) window.console.log = function () { };

//*** Miscellaneous utilities

function compare (a,b) { return a < b ? -1 : a > b ? 1 : 0; }

function defined (x) { var y; return x !== y; }

function Div(css_class, content, attrs) {
  if (defined(attrs) && attrs != '') attrs = ' ' + attrs; else attrs = '';
  return '<div class="'+css_class+'"' + attrs + '>'+content+'</div>';
  }

function error(s) {
  var ref = document.getElementById('error');
  if (ref) {
    ref.innerHTML = s;
//  console.log(s); 
    }
  else { console.log(s); }
  }

function escapeSingleQuotes (x) { "use strict"; return x.replace(/'/g, "\\'"); }

function getElementsByClass(c) {
  "use strict";
  var allElts, c_padded, e, i, retElts;
  if (document.getElementsByClassName) {
    return document.getElementsByClassName(c);
    }
  else {
    allElts = document.getElementsByTagName("*");
    retElts = [];
    c_padded = ' ' + c + ' ';
    for (i=allElts.length-1; i>=0; i--) {
      e = allElts[i];
      if (e.className) {
	if ((" "+e.className+" ").indexOf(c_padded) !== -1) { retElts.unshift(e); }
	}
      }
    return retElts;
    }
  }

var getUniqueID = (function () { "use strict";
  var nextID = 1;
  return function (thing) {
    if (!thing.tsh_unique_id) { thing.tsh_unique_id = nextID++; }
    return thing.tsh_unique_id;
    };
  }());

function isAppleHandheld () {
  return navigator.userAgent.match(/iPhone|iPod|iPad/i);
  }

if (!Array.prototype.map) {
  Array.prototype.map = function(fn /*, thisp*/) {
    if (typeof fn != "function") throw new TypeError();
    var rv = new Array(this.length);
    var thisp = arguments[1];
    for (var i = 0; i < this.length; i++) {
      if (i in this) rv[i] = fn.call(thisp, this[i], i, this);
      }
    return rv;
    };
  }

function Range(a,b) {
  var rv = [];
  for (var i=a; i<=b; i++) { rv.push(i); }
  return rv;
  }

function setText(element, text) { "use strict";
  if (element.innerText) { element.innerText = text; }
  else { element.textContent = text; }
  }

function setTextField(element, value) { "use strict";
  var delta,
      selectionEnd = element.selectionEnd,
      selectionStart = element.selectionStart;
  if (element.value == value) { return; }
  delta = value.length - element.value.length;
  element.value = value;
  element.setSelectionRange(selectionStart + delta, selectionEnd + delta);
  }

function ucfirst (s) { 
  s += ''; 
  return s.charAt(0).toUpperCase() + s.substr(1);
  }

function UtilityFormatHTMLHalfInteger (n) {
  if (!defined(n)) { return '[undef]' };
  n += "";
  n = n.replace(/^(-*)0*\.5$/, "$1&frac12;").replace(/\.5$/, "&frac12;");
  return n;
  }

function UtilityFormatHTMLSignedInteger (x) {
  if (!defined(x)) { return '[undef]' };
  x += "";
  x = x.replace(/^-/, "&minus;").replace(/^([^+&])/, "+$1");
  return x;
  }

function UtilityOrdinal(n) {
  n += "";
  if (!n.match(/^\d+$/)) return n;
  if (n.match(/(?:^1|[^1]1)$/)) { n += 'st'; }
  else if (n.match(/(?:^2|[^1]2)$/)) { n += 'nd'; }
  else if (n.match(/(?:^3|[^1]3)$/)) { n += 'rd'; }
  else { n += 'th' };
  return n;
  }
//*** PoslFetchURL

if (!window.XMLHttpRequest) {
  window.XMLHttpRequest = 
    function() { return new ActiveXObject('Microsoft.XMLHTTP'); };
  }

function PoslFetchURL(url) {
  if (!defined(url)) { return; } // see morenotes.txt
  if (url.match(/^file:/)) {
    alert("This feature is only available when this page is fetched from a web server.");
    var back = window.location.href.replace(/[^\/]+$/, 'index.html');
    window.location = back;
    return;
    }
  this.url = url;
  this.cached = null;
  this.timestamp = null;
  }

PoslFetchURL.prototype.FetchCached = function () {
  if (!this.url) { return undefined.exit(); }
  var request = new XMLHttpRequest();
  var timestamp;
  try {
    request.open("GET", this.url, false);
    if (this.timestamp) {
      request.setRequestHeader("If-Modified-Since", this.timestamp);
      }
    request.send(null);
    }
  catch (e) {
    window.console.log('XMLHR error: ' + e);
    }
  if (request.status == 200) {
    timestamp = request.getResponseHeader('Last-Modified');
    if (timestamp) {
      this.cached = request.responseText;
      this.timestamp = timestamp;
      }
    else {
      this.cached = null;
      this.timestamp = null;
      }
    return request.responseText;
    }
  else if (request.status == 304) {
    return this.cached;
    }
  else {
    return null;
    }
  };

PoslFetchURL.prototype.FetchDirect = function () {
  var request = new XMLHttpRequest();
  var status;
  var timestamp;
  var error;
  try {
    request.open("GET", this.url, false);
    request.send(null);
    status = request.status;
    }
  catch (e) {
    status = 500;
    }
//window.console.log(this.url, status);
  if (status == 304) {
    // You'd think this couldn't happen, because you're sending a direct
    // request for an URL without specifying If-Modified-Since, but no.
    // In Chrome, at least since version 29, if you have recently loaded
    // the file you're asking for, it will be in the cache and you won't
    // be able to access it.  So in this case, we try asking for a unique
    // version of the url.
    request.open("GET", this.url + '?' + Math.random(), false);
    request.send(null);
    // you should in general add the random value on yourself though,
    // because Firefox bfCache.
    }
  if (status == 200) { 
    timestamp = request.getResponseHeader('Last-Modified');
    if (timestamp) {
      this.cached = request.responseText;
      this.timestamp = timestamp;
      }
    else {
      this.cached = null;
      this.timestamp = null;
      }
    return request.responseText;
    }
  else {
    return null;
    }
  };

//*** HTML

function HTMLArguments (argh, list) {
  return list.map(
    function (el) {
      return defined(argh[el]) ? el + '="' + argh[el] + '"' : '';
      }
    ).join(' ');
  }

function HTMLInputText (argh) {
  return '<input type=text' +
    HTMLArguments(argh, ['name','value','size','maxlength','onkeydown','pattern'])
    + ' />';
  }

//*** Config utilities

function ConfigTerminology(config, codemap) {
  if (typeof(codemap) != 'object') {
    error('bad arguments to ConfigTerminology');
    return {};
    }
  var terms = {};
  for (var code in codemap) {
    var argvp = codemap[code];
    var argi = 0;
    function replacer (str, p1) { var s = argvp[argi++]; if (!defined(s)) s = '[missing arg]'; return s; }
    var term;
    try {
      term = config._termdict.messages[code].brief+'';
      }
    catch (e) {
      console.log('unknown code: '+code);
      term = '[unknown code: '+code+']';
      }
    term = term.replace(/%[-.\d]*[ds]/g, replacer);
    terms[code] = term;
    }
  return terms;
  }

function ConfigOrdinalTerm(config, n) {
  n += "";
  if (!n.match(/^\d+$/)) return n;
  var key = 'ordnth';
  if (n.match(/(?:^1|[^1]1)$/)) { key = 'ord1st'; }
  else if (n.match(/(?:^2|[^1]2)$/)) { key = 'ord2nd'; }
  else if (n.match(/(?:^3|[^1]3)$/)) { key = 'ord3rd'; }
  var argh = new Object(); argh[key] = [n];
  var terms = ConfigTerminology(config, argh);
  var term = terms[key];
  term = term.replace(/([^0-9]+)/g, "<span class=ordinal_affix>$1</span>");
  return term;
  }

function ConfigRepeatTerm(config, n) {
  n *= 1;
  if (n < 2) return '';
  var key = 'repeat';
  var argh = new Object();
  if (n == 2) argh[key] = [];
  if (n > 2) {
    key = 'npeat';
    argh[key] = [n];
    }
  var terms = ConfigTerminology(config, argh);
  return terms[key];
  }

//*** Division utilities

function DivisionBoardTable (dp, b, config) {
  var ref = config.tables;
  if (!ref) return b;
  ref = ref[dp.name];
  if (!ref) return b;
  ref = ref[b-1];
  if (!ref) return b;
  return ref;
  }

function DivisionClasses (dp, c) {
  var old = dp.classes;
  if (defined(c)) dp.classes = c;
  return old;
  }

function DivisionCountPlayers(dp) {
  return dp.players.length - 1;
  }

function DivisionHasTables(dp, config) {
  return config.tables && config.tables[dp.name];
  }

function DivisionIsComplete(dp) {
  var i, r0, p;
  var datap = dp.players;
  if (!dp.maxr) { return 0; }
  for (i=1; i<datap.length; i++) {
    p = datap[i];
    if (!PlayerActive(p)) { continue; }
    for (r0=0; r0<=dp.maxr; r0++) {
      if (defined(p.scores[r0])) { continue; }
      return 0;
      }
    }
  return 1;
  }

function DivisionLabel(dp, config, options) {
  var label;
  if (config.division_label) {
    label = config.division_label[dp.name];
    }
  if (!defined(label)) {
    var terms = ConfigTerminology(config, {'Division':[]});
    if (options && options.format && options.format === 'html') {
      label = 
	'<span class=divname>' +
	  '<span class=label>' + terms.Division + '</span> ' +
	  '<span class=name>' + dp.name + '</span>' +
        '</span>';
      }
    else {
      label = terms.Division + ' ' + dp.name;
      }
    }
  return label;
  }

function DivisionLastPairedRound0(dp) { return dp.maxp; }

function DivisionLeastScores (dp) { 
  if (!(defined(dp) && dp.name)) return 0;
  return dp.mins+1; 
  }

function DivisionMaxRound0(dp,round0) {
  var old = dp.maxr;
  if (defined(round0)) dp.maxr = round0;
  return old;
  }

function DivisionMaxRoundPlayed (dp) { return dp.maxrp+1; }

function DivisionMostScores (dp) { return dp.maxs+1; }

function DivisionName (dp) { 
  if (!(defined(dp) && dp.name)) return '?Div?';
  return dp.name;
  }

function DivisionPlayer (dp, pid) {
  if (pid < 1) return undefined;
  if (!defined(dp)) return undefined;
  return dp.players[pid];
  }

function DivisionPlayers(dp) {
  if (!defined(dp)) return [];
  var datap = dp.players;
  return datap.slice(1);
  }

function DivisionRatingSystem (dp) {
  return dp.rating_system || 'none';
  }

function DivisionSynch(dp, tourney) {
  var datap = dp.players;
  var config = tourney.config;

  var minpairings = 999999;
  var maxpairings = -1;
  var minscores = 999999;
  var maxscores = -1;
  var maxps = -1;
  var maxps_player;
  var mins_player;
  var maxs_player;
  var caps = config.standings_spread_cap;
  var full_caps = config.spread_cap;
  var c_oppless_spread = config.oppless_spread;
  var team_wins = {};

  for (var i=1; i < datap.length; i++) {
    var p = datap[i];
    var pairingsp = p.pairings;
    var penaltiesp = p.etc.penalty;
    while (pairingsp.length && !defined(pairingsp[pairingsp.length-1])) 
      { pairingsp.pop(); }
    var npairings = pairingsp.length-1;
    var contigpairings = -1;
    while (defined(pairingsp[++contigpairings])) { }
    contigpairings--;
    var scoresp = p.scores;
    while (scoresp.length && !defined(scoresp[scoresp.length-1]))
      { scoresp.pop(); }
    var last_score_r0 = scoresp.length-1;
    var spread = 0;
    var rspread = [];
    var cspread = 0;
    var rcspread = [];
    var ratedgames = 0; 
    var ratedwins = 0; 
    var nscores = 0;
    var losses = 0;
    var rlosses = [];
    var wins = 0;
    var rwins = [];
    p.ewins1 = p.ewins2 = 0;

    var active = !p.etc.off;
    if (contigpairings < minpairings && active) 
      minpairings = contigpairings;
    if (npairings > maxpairings && active) 
      maxpairings = npairings;
    if (last_score_r0 < minscores && active) 
      { minscores = last_score_r0; mins_player = p; }
    if (last_score_r0 > maxscores && active) 
      { maxscores = last_score_r0; maxs_player = p; }

    var last_ps = -1;
    // The following line is a kludge; this refers to a ScoreBoard object.
    // TODO: restrict to this that is an instanceof ScoreBoard
    if (last_score_r0 > this.r0) last_score_r0 = this.r0;
    for (var j=0; j<=last_score_r0; j++) { // number of scores
      var oppid = pairingsp[j];
      if (oppid && active) { last_ps = j; }
      var myscore = p.scores[j];
      if (defined(myscore)) nscores++;
      if (!defined(oppid)) {
	continue;
        }
      var oppscore;
      if (oppid) {
	oppscore = datap[oppid].scores[j];
	if ((!defined(oppscore)) && defined(myscore)) {
	  oppscore = 0;
	  }
	if (defined(oppscore) && defined(myscore)) {
	  ratedgames++;
	  }
	}
      else {
	oppscore = 0;
	}
      if (!defined(myscore)) continue;
      var thisSpread = myscore;
      if (!c_oppless_spread) thisSpread -= oppscore;
      if (full_caps) {
	var cap = j < full_caps.length ? full_caps[j] : full_caps[full_caps.length-1];
	if (thisSpread > cap) {
	  thisSpread = cap;
	  }
	else if (thisSpread < -cap) {
	  thisSpread = -cap;
	  }
	cspread += thisSpread;
	rcspread.push(cspread);
	}
      if (penaltiesp) 
        thisSpread += (penaltiesp[j]||0);
      spread += thisSpread;
      rspread.push(spread);
      if (caps && !full_caps) {
	var cappedSpread = thisSpread;
	var cap = j < caps.length ? caps[j] : caps[caps.length-1];
	if (cappedSpread > cap) 
	  cappedSpread = cap;
	else if (cappedSpread < -cap) 
	  cappedSpread = -cap;
	cspread += cappedSpread;
	rcspread.push(cspread);
	}
      var result = myscore > oppscore ? 1 : myscore < oppscore ? 0 : 0.5;
      if (oppid || thisSpread) {
	wins += result;
	losses += 1 - result; 
	}
      if (oppid) {
	ratedwins += result;
	p[j < config.split1 ? 'ewins1' : 'ewins2'] += result;
	}
      rlosses.push(losses);
      rwins.push(wins);
      } //for j
    if (last_ps > maxps) { 
      maxps = last_ps;
      maxps_player = p;
      }
    p.losses = losses;
    p.nscores = nscores;
    if (defined(dp.maxr)) p.noscores = dp.maxr+1 - nscores;
    p.ratedgames = ratedgames;
    p.ratedwins = ratedwins;
    p.rlosses = rlosses;
    p.rcspread = rcspread;
    p.rspread = rspread;
    p.rwins = rwins;
    p.cspread = cspread;
    p.spread = spread;
    p.wins = wins;
    if (p.etc.team) { 
      if (!team_wins[p.etc.team]) team_wins[p.etc.team] = 0;
      team_wins[p.etc.team] += wins;
      }

    { 
      var repeats = [];
      for (var j=0; j<datap.length; j++) {
        repeats.push(0);
	}
      for (var j=0; j<pairingsp.length; j++) {
        if (pairingsp[j]) repeats[pairingsp[j]]++;
        }
      p.repeats = repeats;
    }

    }

  dp.mins = minscores;
  dp.mins_player = mins_player;
  dp.maxps = maxps;
  dp.maxps_player = maxps_player;
  dp.maxs = maxscores;
  dp.maxs_player = maxs_player;
  dp.maxp = maxpairings;
  dp.minp = minpairings;
  dp.team_wins = team_wins;

  if (config.track_firsts) { // must come after maxp computation
    DivisionSynchFirsts(dp, tourney);
    }
  }

function DivisionSynchFirsts(dp, tourney) {
  var datap = dp.players;
  var config = tourney.config;
  var bye_firsts = config.bye_firsts;
  var lastr0 = defined(dp.maxr) ? dp.maxr : undefined;
  var final_round_normal = !config.final_draw;

  for (var pi=1; pi<datap.length; pi++) {
    var p = datap[pi];
    p.p1 = p.p2 = p.p3 = p.p4 = 0;
    if (!p.etc.p12) p.etc.p12 = [];
    }
  if (!config.assign_firsts) {
    for (var pi=1; pi<datap.length; pi++) {
      var p = datap[pi];
      var scoresp = p.scores;
      var p12p = p.etc.p12;
      if (p12p.length > scoresp.length) 
        p.etc.p12 = p12p.slice(0,scoresp.length-1);
      }
    }

  var bye_count;
  for (var round0=0; round0<=dp.maxp; round0++) {
    var o12;
    var oppp;
    var p12;
    var i = 0;
    for (var pi=1; pi<datap.length; pi++) {
      var p = datap[pi];
      i++;
      var oppid = p.pairings[round0];
      if (!defined(oppid)) { p12 = 4; continue; }
      var p12p = p.etc.p12;
      if (oppid == 0) { 
	p12 = 0; 
	oppp = undefined; 
	if (bye_firsts == 'alternate' && (PlayerScore(p,round0)||0) < 0) 
	  p12 = ++bye_count[i] % 2 ? 1 : 2;
	continue; 
        }
      oppp = undefined;
      p12 = p12p[round0];
      if (oppid < p.id) { 
	if (!defined(p12p[round0])) {
	  p12 = 4;
	  }
	continue;
        }
      oppp = datap[oppid];
      var o12p = oppp.etc.p12;
      var exists = 1;
      o12 = o12p[round0];
      var p12known = p12 && p12 < 4;
      var o12known = o12 && o12 < 4;
      if (p12known) {
	if (!o12known) o12 = o12p[round0] = (0, 2, 1, 3)[p12]; 
        }
      else {
        if (o12known) p12 = p12p[round0] = (0, 2, 1, 3)[o12];
	else { exists = 0; }
        }
      if (exists) continue;
      var ofuzz = oppp.p3 + oppp.p4;
      var pfuzz = p.p3 + p.p4;
      if (pfuzz + ofuzz == 0 || round0 == 0) {
	var which = 1 +
	  (compare(p.p1, oppp.p1) || compare(oppp.p2, p.p2));
	if (which == 1 && config.assign_firsts) {
	  if (config.avoid_sr_runs && round0 > 0) {
	    for (var roundi0 = round0-1; roundi0 >= 0; roundi0--) {
	      var lastp12 = p12p[roundi0];
	      var lasto12 = o12p[roundi0];
	      if (lastp12 == lasto12) continue;
	      if (lastp12 != lasto12) {
		which = lastp12 == 1 ? 2 : 0;
		break;
		}
	      }
	    }
	  if (which == 1) {
	    if (final_round_normal || defined(lastr0) && round0 != lastr0) 
	      which = 2 * Math.floor(rand(2));
	    }
	  }
        p12 = [1, 3, 2][which];
        o12 = [2, 3, 1][which];
        }
      else {
	var diff1 = p.p1 - oppp.p1;
	var diff2 = p.p2 - oppp.p2;
	if ((compare(diff1, ofuzz) || compare(-diff2, pfuzz)) > 0) 
	  { p12 = 2; o12 = 1; }
	else if ((compare(-diff1, pfuzz) || compare(diff2, ofuzz)) > 0) 
  	  { p12 = 1; o12 = 2; }
	else if (config.assign_firsts) {
	  if (Math.random() > 0.5) { p12 = 1; o12 = 2; }
	  else { p12 = 2; o12 = 1; }
	  }
	else 
	  { p12 = o12 = 4; } 
        }
      }
    continue
      {
      if (!defined(p12)) p12=4;
      p.etc.p12[round0] = p12;
      p['p'+p12]++;
      if (oppp) {
	oppp.etc.p12[round0] = o12;
        }
      }
    }
  }

//*** Player utilities

function PlayerActive(p) { return !defined(p.etc.off); }

function PlayerBoard (p, r0, newboard) { 
  var boardp = p.etc.board;
  if (!defined(boardp)) { p.etc.board = boardp = []; }
  var oldboard = boardp[r0] || 0;
  if (defined(newboard)) {
    if (r0 > boardp.length) {
      for (var i=0; i<r0-boardp.length; i++) {
	boardp.push(0);
        }
      }
    boardp[r0] = newboard;
//  p->Division()->Dirty(1);
    }
  return oldboard;
  }

function PlayerBort (p, r0, dp, config) {
  var bort = PlayerBoard(p, r0);
  if (DivisionHasTables(dp, config)) 
    bort = DivisionBoardTable(dp, bort, config);
  return bort;
  }

function PlayerClass (p) {
  return p.etc['class'] ? p.etc['class'].join(' ') : '';
  }

function PlayerCountOpponents(p) {
  return p.pairings ? p.pairings.length : 0;
  }

function PlayerCountRoundRepeats (p, opp, r0) { 
  var oid = opp.id;
  var repeats = 0;
  var pairingsp = p.pairings;
  var aid;
  for (var i=0; i<pairingsp.length; i++) {
    if (i > r0) break;
    aid = pairingsp[i];
    if (defined(aid) && aid == oid) repeats++;
    }
  return repeats;
  }

function PlayerCountScores(p) {
  if (!defined(p)) return 0;
  return p.scores ? p.scores.length : 0;
  }

function PlayerFirst(p, round0) {
  if (!defined(p)) return 0;
  if (round0 < 0) return 0;
//return defined(p.etc.p12[round0]) ? p.etc.p12[round0] : (p.wins || 0);
  return (p.etc && p.etc.p12 && defined(p.etc.p12[round0])) ?
    p.etc.p12[round0] : 0;
  }

function PlayerID (p) { 
  if (!(defined(p) && p.id)) {
    console.log('Bad player, called from: '+PlayerID.caller);
    return '?Plyr?';
    }
  return p.id;
  }

function PlayerLosses(p) { 
  if (!defined(p)) return 0;
  return p.losses; 
  }

function PlayerName (p) {
  if (!defined(p)) return '?';
  var name = p.name || '?';
  name = name.replace(/,\s*$/, '');
  return name;
  }

function PlayerNewRating(p, r0) {
  if (!defined(p)) return 0;
  if (r0 < 0) return p.rating;
  if (defined(p.etc.newr)) {
    if (defined(p.etc.newr[r0])) return p.etc.newr[r0];
    if (p.etc.newr.length) return p.etc.newr[p.etc.newr.length-1];
    }
  return 0;
  }

function PlayerOpponent(p, r0, dp) {
  if (!defined(p)) return undefined;
  return p.pairings[r0] && dp.players[p.pairings[r0]];
  }

function PlayerOpponentID(p, r0) {
  if (!defined(p)) return 0;
  return p.pairings[r0];
  }

function PlayerPrettyName(p, config) {
  if (!defined(p)) return '?';
  if (!p.prettyname) {
    var name = PlayerName(p);
    name = name.replace(/^Zxqkj, Winter$/, 'Winter');
    if (config.surname_last) 
      name = name.replace(/^([^,]+), (.*)$/, "$2 $1");
    p.prettyname = name;
    }
  return p.prettyname;
  }

function PlayerRating(p) {
  if (!defined(p)) return 0;
  return p.rating || 0;
  }

function PlayerFullID(p, dp, tourney) {
  var dname = '';
  if (TournamentCountDivisions(tourney) > 1) {
    dname = DivisionName(dp) + '';
    if (dname.match(/\d$/)) dname += '-';
    }
  else dname = '#';
  return dname + PlayerID(p);
  }

function PlayerRoundCappedRank(p, round0, newrank) {
  var ranksp = p.etc.rcrank;
  if (!defined(ranksp)) { p.etc.rcrank = ranksp = []; }
  var round = round0 + 1;
  var oldrank = ranksp[round];
  if (defined(newrank)) {
    if (round >= 0) ranksp[round] = newrank;
    }
  if ((!defined(newrank)) && !defined(oldrank)) {
    oldrank = 0;
    }
  return oldrank;
  }

function PlayerRoundCappedSpread(p, round0) {
  if (round0 < 0) return 0;
  return defined(p.rcspread[round0]) ? p.rcspread[round0] : (p.cspread || 0);
  }

function PlayerRoundLosses(p, round0) {
  if (round0 < 0) return 0;
  if (!p.rwins) return '***';
  return defined(p.rlosses[round0]) ? p.rlosses[round0] : (p.losses || 0);
  }

function PlayerRoundRank(p, round0, newrank) {
  var ranksp = p.etc.rrank;
  if (!defined(ranksp)) { p.etc.rrank = ranksp = []; }
  var round = round0 + 1;
  var oldrank = ranksp[round];
  if (defined(newrank)) {
    if (round >= 0) ranksp[round] = newrank;
    }
  if ((!defined(newrank)) && !defined(oldrank)) {
    oldrank = 0;
    }
  return oldrank;
  }

function PlayerRoundSpread(p, round0) {
  if (round0 < 0) return 0;
  return defined(p.rspread[round0]) ? p.rspread[round0] : (p.spread || 0);
  }

function PlayerRoundWins(p, round0) {
  if (round0 < 0) return 0;
  if (!p.rwins) return '***';
  return defined(p.rwins[round0]) ? p.rwins[round0] : (p.wins || 0);
  }

function PlayerScore(p, round0, newscore, dp) {
  var scoresp = p.scores;
  if (!defined(scoresp)) return undefined;
  var oldscore = scoresp[round0];
  if (defined(newscore)) {
    if (round0 >= 0 
      && (tourney.config.allow_gaps 
	? round0 < (DivisionMaxRound0(dp)||0)+1
	: round0 <= scoresp.length)) {
      scoresp[round0] = newscore;
      }
    }
  return oldscore && (oldscore == 9999 ? undefined : oldscore);
  }

function PlayerScoreboardName (p) {
  if (!defined(p)) return '?';
  return p.etc.sbname ? p.etc.sbname.join(' ') : PlayerName(p);
  }

function PlayerSortByCappedStanding (sr0, ps, config) {
  var spread_bad = config.spread_bad ? -1 : 1;
  return ps.sort(function (a,b) {
//  console.log(['a', a.name, a.rwins[sr0], a.rlosses[sr0], a.rspread[sr0]].join(', '));
//  console.log(['b', b.name, b.rwins[sr0], b.rlosses[sr0], b.rspread[sr0]].join(', '));
    return sr0 >= 0 ? 
      (compare(defined(b.rwins[sr0]) ? b.rwins[sr0] : b.wins, defined(a.rwins[sr0]) ? a.rwins[sr0] : a.wins) ||
      (compare(defined(a.rlosses[sr0]) ? a.rlosses[sr0] : a.losses, defined(b.rlosses[sr0]) ? b.rlosses[sr0] : b.losses)) ||
      spread_bad*(compare(defined(b.rcspread[sr0]) ? b.rcspread[sr0] : b.cspread, defined(a.rcspread[sr0]) ? a.rcspread[sr0] : a.cspread)) || 
      compare(b.rating, a.rating) ||
      compare(b.rnd, a.rnd))
    : (compare(b.rating, a.rating) || compare(b.rnd, a.rnd))
    ; });
  }

function PlayerSortByStanding (sr0, ps, config) {
  var spread_bad = config.spread_bad ? -1 : 1;
  return ps.sort(function (a,b) {
//  console.log(['a', a.name, a.rwins[sr0], a.rlosses[sr0], a.rspread[sr0]].join(', '));
//  console.log(['b', b.name, b.rwins[sr0], b.rlosses[sr0], b.rspread[sr0]].join(', '));
    return sr0 >= 0 ? 
      (compare(defined(b.rwins[sr0]) ? b.rwins[sr0] : b.wins, defined(a.rwins[sr0]) ? a.rwins[sr0] : a.wins) ||
      (compare(defined(a.rlosses[sr0]) ? a.rlosses[sr0] : a.losses, defined(b.rlosses[sr0]) ? b.rlosses[sr0] : b.losses)) ||
      spread_bad*(compare(defined(b.rspread[sr0]) ? b.rspread[sr0] : b.spread, defined(a.rspread[sr0]) ? a.rspread[sr0] : a.spread)) || 
      compare(b.rating, a.rating) ||
      compare(b.rnd, a.rnd))
    : (compare(b.rating, a.rating) || compare(b.rnd, a.rnd))
    ; });
  }

function PlayerSpliceInactive(psp, count, round0) {
  if (round0 < 0) return;
  for (var i=0; i<psp.length; i++) {
    var p = psp[i];
    var off = p.etc.off;
    if (!defined(off)) continue;
    psp.splice(i--, 1);
    
    var pairingsp = p.pairings;
    if (pairingsp.length < round0) continue;
    var scoresp = p.scores;
    for (var j=round0; j<round0+count; j++) {
      if (!defined(pairingsp[j])) pairingsp[j] = 0;
      if (!defined(scoresp[j])) scoresp[j] = off[0];
      }
    }
  }

function PlayerSpread(p) { return p.spread; }

function PlayerTaggedName(p, style, dp, tourney) {
  if (!defined(style)) style = '';
  var clean_name = (style == 'print' && p.etc.pname)
    ? p.etc.pname.join(' ')
    : PlayerPrettyName(p, tourney.config);
  var team = tourney.config.show_teams ? '/' + PlayerTeam(p) : '';
  return (defined(p) && clean_name.length) 
    ? clean_name + ' (' + PlayerFullID(p, dp, tourney) + team + ')' 
    : 'nobody';
  }

function PlayerTeam(p) {
  return p.etc.team ? p.etc.team.join(' ') : '';
  }

function PlayerWins(p) { return p.wins; }

//*** Tournament utilities

function TournamentCountDivisions (tourney) { return tourney.divisions.length; }

function TournamentDivisions (tourney) { return tourney.divisions; }

// unlike Perl version, dname must already be canonicalised
function TournamentGetDivisionByName (tourney, dname) {
  for (var di=0; di<tourney.divisions.length; di++) {
    var dp = tourney.divisions[di];
    if (DivisionName(dp) == dname) return dp;
    }
  return undefined;
  }

function TournamentSynch (tourney) { 
  for (var di=0; di<tourney.divisions.length; di++) {
    DivisionSynch(tourney.divisions[di], tourney);
    }
  }
