var tourney;

// general utilities

function compare (a,b) { return a < b ? -1 : a > b ? 1 : 0; }

function defined (x) { var y; return x !== y; }
var undefined;

if (!window.console) window.console = {};
if (!window.console.log) window.console.log = function () { };

function error(s) {
  var ref = document.getElementById('error');
  if (ref) { ref.innerHTML = s; }
  else { console.log(s); }
  }

function getWindowHeight () {
  if (window.innerHeight) 
    return window.innerHeight - 18;
  else if (document.documentElement && document.documentElement.clientHeight) 
    return document.documentElement.clientHeight;
  else if (document.body && document.body.clientHeight) 
    return document.body.clientHeight;
  return 640;
  };
  
function getWindowWidth () {
  if (window.innerWidth) 
    return window.innerWidth - 18;
  else if (document.documentElement && document.documentElement.clientWidth) 
    return document.documentElement.clientWidth;
  else if (document.body && document.body.clientWidth) 
    return document.body.clientWidth;
  return 640;
  };
  
// PoslFetchURL

if (!window.XMLHttpRequest) {
  window.XMLHttpRequest = 
    function() { return new ActiveXObject('Microsoft.XMLHTTP'); }
  }

function PoslFetchURL(url) {
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
  request.open("GET", this.url, false);
  if (this.timestamp) {
    request.setRequestHeader("If-Modified-Since", this.timestamp);
    }
  request.send(null);
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
  }

// ScoreBoardPlayer

function ScoreBoardPlayer (sb, data, id) {
  this.sb = sb;
  this.id = id;
  this.data = data;
  this.current_x = 0;
  this.current_y = 0;
  this.delta_x = 0;
  this.delta_y = 0;
  this.target_x = 0;
  this.target_y = 0;
  this.max_speed_x = 100;
  this.max_speed_y = 100;
  this.visible = false;
  }

ScoreBoardPlayer.prototype.Accelerate = function(dir) {
  var range = this['target_'+dir] - this['current_'+dir];
  var speed = Math.abs(this['delta_'+dir]);
  if (speed != 0) {
    var stopping_distance = (speed+1) * (speed + 2) / 2;
    // overshot or about to overshoot
    if (compare(range,0) != compare(this['delta_'+dir],0) 
      || Math.abs(range) < stopping_distance) {
      if (this['delta_'+dir] != 0)
	this['delta_'+dir] -= this['delta_'+dir] / Math.abs(this['delta_'+dir]);
      }
    // not at maximum warp
    else if (range != 0 && speed < this['max_speed_'+dir]) {
      this['delta_'+dir] += range / Math.abs(range);
      }
    }
  // get moving
  else if (range != 0) {
    this['delta_'+dir] += range / Math.abs(range);
    }
  }

ScoreBoardPlayer.prototype.Render = function(lastp, outofthemoney, withcontainer) {
  p = this.data;
  var sb = this.sb;
  if (withcontainer) this.visible = false;
  var dp = sb.dp;
  var r0 = sb.r0;
  var r1 = sb.r1;
  var seed = dp.seeds[p.id-1];
  var html = '';
  var config = tourney.config;
  {
    var crank, lrank, spread;
    if (sb.is_capped) {
      crank = PlayerRoundCappedRank(p, r0);
      lrank = r0 > 0 ? PlayerRoundCappedRank(p, r0 - 1) : seed;
      spread = PlayerRoundCappedSpread(p, r0);
      }
    else {
      crank = PlayerRoundRank(p, r0);
      lrank = r0 > 0 ? PlayerRoundRank(p, r0 - 1) : seed;
      spread = PlayerRoundSpread(p, r0);
      }
    var is_in_money = InTheMoney(sb, p) ? ' money' : '';
    var is_out_of_money = outofthemoney ? ' nomoney' : '';
    var wins = PlayerRoundWins(p, r0);
    var losses = PlayerRoundLosses(p, r0);
    var is_block_leader = '';
    if (sb.first_rank == 1 && !defined(lastp)) {
//    html += '<div class="wlb'+is_in_money+is_out_of_money+'"><div class=w>P<br>R<br>I<br>Z<br>E</div></div>';
//    is_block_leader = 1;
      }
    else if (!is_in_money) {
      var lastw = defined(lastp) ? PlayerRoundWins(lastp, r0) : -1;
      if (lastw != wins 
	|| InTheMoney(sb, lastp)
	) {
//	html += '<div class="wlb'+is_in_money+is_out_of_money+'"><div class=w>' + UtilityFormatHTMLHalfInteger(wins).replace(/(\d|&frac12;)/g, '$&<br>').replace(/<br>$/,'') + '</div></div>';
//	is_block_leader = 1;
	}
      }
    if (is_block_leader) is_block_leader = " leader";
    if (withcontainer) html += '<div id="'+this.id+'" class="sbp'+is_in_money+is_out_of_money+is_block_leader+'" style="position:absolute;left:0;top:0;display:none">';
    html += '<table cellspacing=0 cellpadding=0><tr><td><div class=me>';
    html += "<div class=rank>"
      + UtilityOrdinal(crank)
      + "</div>";
    if (defined(PlayerScore(p, r0))) html += "<div class=old>was<br>" + UtilityOrdinal(lrank) + "</div>\n";
    if (sb.thai_points) html += "<div class=\"handicap\"><span class=label>HP</span><br><span class=value>" + (2*wins+((p.etc.handicap && p.etc.handicap[0])||0)) + "</span></div>\n";
    var currency_symbol = config.currency_symbol || '$';
    if (is_in_money) 
      html += "<div class=money>"+currency_symbol+"</div>";
    html += "<div class=wl>" + UtilityFormatHTMLHalfInteger(wins)
	+ "&ndash;"
	+ UtilityFormatHTMLHalfInteger (losses) 
	+ ' ' 
	+ UtilityFormatHTMLSignedInteger(spread)
      + "</div>";
  }
  html += FormatPlayerPhotoName(this,{'id':this.id+'_mi','show_id':1});
  { 
    var oldr = p.rating
    var newr = PlayerNewRating(p);
    var delta = UtilityFormatHTMLSignedInteger(newr-oldr);
    html += "<div class=newr>"+newr+"</div>\n";
    if (oldr) {
      html += "<div class=oldr>="+oldr+"<br>"+delta+"</div>\n";
      }
    else {
      html += "<div class=oldr>was<br>unrated</div>\n";
      }
  }
  html += "</div></td>\n"; // me
  html += "<td><div class=opp>\n"; // opp
  { // last game
    var last = '';
    var oppid = PlayerOpponentID(p, r0);
    if (oppid) {
      var op = PlayerOpponent(p, r0, dp);
      var opp = sb.pmap[op.id];
//    if (!opp) { console.log('cannot find '+op.id+' in pmap'); }
      var os = PlayerScore(op, r0);
      if (defined(os)) {
	var ms = PlayerScore(p, r0);
	var spread = UtilityFormatHTMLSignedInteger(ms - os);
	last += "<div class=gs>"+ms+"&minus;"+os+"="+spread+"</div>";
	}
      else {
	last += "<div class=gsn>no score yet</div>";
	}
      var first = PlayerFirst(p, r0);
      first = first == 1 ? '1st' : first == 2 ? '2nd' : '';
      var board = RenderBoard(sb, PlayerBoard(p, r0));

      last += "<div class=where>"+first+board+" vs.</div>\n";
      last += "<div class=hs>" 
	+ FormatPlayerPhotoName(opp,{'id':this.id+'_li'}) 
	+ "</div>";
      }
    else if (r0 >= 0) { // bye
      var ms = PlayerScore(p,r0);
      ms = defined(ms) ?  ms >= 0 ? '+' + ms : ms : '';
      last += "<div class=bye>bye "+ms+"</div>";
      }
    if (last) {
      html += "<div class=last><div class=title>Last:</div>"+last+"</div>\n";
      }
  }
  { // next game
    var next = '';
    var oppid = PlayerOpponentID(p,r0+1);
    if (oppid) {
      var op = PlayerOpponent(p,r0+1, dp);
      var opp = sb.pmap[op.id];
      var first = PlayerFirst(p,r0+1);
      var repeats = PlayerCountRoundRepeats(p,op, r0+1);
      var board = RenderBoard(sb,PlayerBoard(p,r0+1));
      first = first == 1 ? '1st' : first == 2 ? '2nd' : '';
      if (repeats > 1) {
	next += "<div class=repeats>"
	  +(repeats==2?"repeat":repeats+"peat")
	  +"</div>";
	}
      next += "<div class=where>"+first+board+" vs.</div>\n";
      next += "<div class=hs>" 
	+FormatPlayerPhotoName(opp,{'id':this.id+'_ni'})
	+ "</div>";
      }
    else if (defined(oppid)) {
      next += "<div class=bye>bye</div>";
      }
    if (next) {
      html += "<div class=next><div class=title>Next:</div>"+next+"</div>\n";
      }
  }
  { // record
    var record = '';
    var nscores = PlayerCountScores(p);
    if (nscores > 1) {
      var maxw = 12;
      if (nscores > maxw) {
	maxw = Math.floor((nscores+maxw-1)/maxw);
	maxw = Math.floor((nscores+maxw-1)/maxw); // doubled line, sic
	var r0 = 0;
	record += '<div class=rdss>';
	while (r0 < nscores) {
	  var lastr0 = r0 + maxw-1;
	  if (lastr0 > nscores-1) lastr0 = nscores-1;
	  record += '<div class=rds>';
	  for (var i0=r0; i0<=lastr0; i0++) {
	    record += this.RenderRoundRecord(i0);
	    }
	  record += '</div>';
	  r0 = lastr0 + 1;
	  }
	record += '</div>';
	}
      else {
	for (var r0=0; r0<nscores; r0++) {
          record += this.RenderRoundRecord(r0);
	  }
	}
      }
    if (record) {
      html += "<div class=record><div class=title>Rec<br>ord</div>"+record+"</div>\n";
      }
    }
  html += '</div></td></tr></table>'; // opp
  if (withcontainer) html += '</div>'; // sbp
  return html;
  }

ScoreBoardPlayer.prototype.RenderRoundRecord = function (r0) {
  var record = ''; 
  var dp = this.sb.dp;

  var ms = this.data.scores[r0];
  record += "<div class=rd>";
  if (this.data.pairings[r0]) {
    var os = dp.players[this.data.pairings[r0]].scores[r0];
    if (defined(os)) {
      record += ms > os ? "<div class=win>W</div>"
	: ms < os ? "<div class=loss>L</div>"
	: "<div class=tie>T</div>";

      }
    else {
      record += "<div class=unknown>?</div>";
      }
    }
  else if (defined(ms)) { record += ms > 0 ? "<div class=bye>B</div>"
      : ms < 0 ? "<div class=forfeit>F</div>"
      : "<div class=missed>&ndash;</div>";
    }
  var p12 = PlayerFirst(p, r0);
  if (p12 && (""+p12).match(/^[12]$/)) {
    record += "<div class=p"+p12+">"+p12+"</div>";
    }
  else {
    record += "<div class=p0>&ndash;</div>";
    }
  record += "</div>";
  return record;
  }

ScoreBoardPlayer.prototype.Rerender = function (lastp, outofthemoney) {
  var ref = document.getElementById(this.id);
  ref.innerHTML = this.Render(lastp, outofthemoney, false);
  if (InTheMoney(this.sb, this.data)) ref.className = 'sbp money';
  else if (outofthemoney) ref.className = 'sbp nomoney';
  else ref.className = 'sbp';
  this.Resize();
  }

ScoreBoardPlayer.prototype.Resize = function () {
  var aspect = tourney.config.player_photo_aspect_ratio || 1;
  var ref = document.getElementById(this.id);
  if (!ref) {
    return;
    }
  ref.style.height = this.sb.cell_height + 'px';
  ref.style.width = this.sb.cell_width + 'px';
  this.SetPhotoSize('_mi',   this.sb.photo_size  , aspect * this.sb.photo_size  );
  this.SetPhotoSize('_mi_f', this.sb.photo_size/3, undefined);
  this.SetPhotoSize('_li',   this.sb.photo_size/2, aspect * this.sb.photo_size/2);
  this.SetPhotoSize('_li_f', this.sb.photo_size/6, undefined);
  this.SetPhotoSize('_ni',   this.sb.photo_size/2, aspect * this.sb.photo_size/2);
  this.SetPhotoSize('_ni_f', this.sb.photo_size/6, undefined);
  }

ScoreBoardPlayer.prototype.SetPhotoSize = function (subid, width, height) {
  var ref = document.getElementById(this.id + subid);
  if (ref) {
    if (width) ref.style.width = Math.round(width) + 'px';
    if (height) ref.style.height = Math.round(height) + 'px';
    }
  }

ScoreBoardPlayer.prototype.SetPosition = function (po, animated) {
  var sb = this.sb;
  var pi = po - sb.offset;
  if (pi < 0 || pi >= sb.rows * sb.columns) {
    this.SetVisible(false);
    return;
    }
  var i = pi % sb.columns;
  var j = Math.floor(pi/sb.columns);
  var ref = document.getElementById(this.id);
  if (animated) {
    this.target_x = i * sb.cell_hspacing;
    this.target_y = j * sb.cell_vspacing + 20;
//  console.log(po,pi,this.target_x,this.target_y,this.visible);
    }
  else {
    this.current_x = i * sb.cell_hspacing;
    this.current_y = j * sb.cell_vspacing + 20;
    this.delta_x = 0;
    this.delta_y = 0;
    }
  ref.style.left = this.current_x + 'px';
  ref.style.top = this.current_y + 'px';
  this.SetVisible(true);
  }

ScoreBoardPlayer.prototype.SetTarget = function (x, y) {
  this.target_x = x;
  this.target_y = y;
  }

ScoreBoardPlayer.prototype.SetVisible = function (bool) {
  if (bool == this.visible) return;
  this.visible = bool;
  var ref = document.getElementById(this.id);
  if (this.visible) {
    this.current_x = this.target_x;
    this.current_y = this.target_y;
    ref.style.left = this.current_x + 'px';
    ref.style.top = this.current_y + 'px';
    ref.style.display = 'block';
    }
  else {
    ref.style.display = 'none';
    }
  }

ScoreBoardPlayer.prototype.Tick = function () {
  var ref = document.getElementById(this.id);
  if (this.delta_x) {
    this.current_x += this.delta_x;
    ref.style.left = this.current_x + 'px';
    }
  if (this.delta_y) {
    this.current_y += this.delta_y;
    ref.style.top = this.current_y + 'px';
    }
  this.Accelerate('x');
  this.Accelerate('y');
  return this.delta_x || this.delta_y;
  }

// TSH::Command::ScoreBoard

var the_sb;
var thai_name_cache = {};

ScoreBoard.prototype.AdjustColumns = function(delta) {
  this.columns += delta;
  if (this.columns < 1) this.columns = 1;
  this.Resize();
  this.Update(true);
  }

ScoreBoard.prototype.AdjustOffset = function(delta) {
  this.offset += delta;
  if (this.offset < 0) this.offset = 0;
  this.Update(true);
//this.Resize();
//this.Render();
  }

ScoreBoard.prototype.AdjustRows = function(delta) {
  this.rows += delta;
  if (this.rows < 1) this.rows = 1;
  this.Resize();
  this.Update(true);
  }

ScoreBoard.prototype.AdjustScroll = function(delta) {
  this.scroll_rate += delta;
  if (this.scroll_rate < 0) this.scroll_rate = 0;
  this.scroll_count = this.scroll_rate;
  }

ScoreBoard.prototype.Fetch = function(is_update) {
  error('checking for updates');
  var content = this.pfu.FetchCached();
  var newt;
  if (content) eval(content); else {
    error('null content returned');
    return false;
    }
  if (newt) tourney = newt; else {
    error('server reply did not contain tournament data');
    return false;
    }
  error('processing new data');

  var dp = GetDivisionByName(this.dname);
  this.dp = dp;
  if (!dp) { alert('Cannot find division "'+this.dname+'".'); return; }
  DivisionSynch(dp);
  var r1 = this.r1 = DivisionMostScores(dp);
  var r0 = this.r0 = r1 - 1;
  this.has_classes = DivisionClasses(dp);
  this.c_no_boards = (tourney.config.no_boards || '');
  this.is_capped = tourney.config.standings_spread_cap;
  this.thai_points = tourney.config.thai_points;
  this.c_has_tables = DivisionHasTables(dp);

  // ComputeRanks, ComputeRatings, ComputeSeeds are done in saveJSON.pm
  var ps = DivisionPlayers(dp);
  PlayerSpliceInactive(ps, 0, 0);
  if (this.is_capped) {
    ps = PlayerSortByCappedStanding(r0, ps);
    }
  else {
    ps = PlayerSortByStanding(r0, ps);
    }
  if (is_update) {
    for (var po=0; po<ps.length; po++) {
      var p = ps[po];
      if (this.ps[po].data.id != p.id) {
	var j;
//	console.log('looking for '+p.id);
	for (j=po+1; j<ps.length; j++) {
//	  console.log('trying '+this.ps[j].data.id);
	  if (this.ps[j] && this.ps[j].data.id == p.id) {
	    this.ps.splice(po, 0, this.ps.splice(j,1)[0]);
//          console.log('now','ps',t1,'this.ps',t2);
	    break;
	    }
	  }
	if (j == ps.length) {
	  error("Player roster unexpectedly changed, cannot find "+p.name+" reloading.");
          this.StorePlayers(ps);
	  return true;
	  }
        }
      this.ps[po].data = p;
      var out_of_the_money = po + 1 >= dp.first_out_of_the_money;
      this.ps[po].Rerender(po ? ps[po-1] : undefined, out_of_the_money);
      }
//  var t1 =[];for (var i=0;i<ps.length;i++) { t1.push(ps[i].id); }
//  var t2 =[];for (var i=0;i<ps.length;i++) { t2.push(this.ps[i].data.id); }
//  console.log('ps',t1,'this.ps',t2);
    this.Update(true);
    }
  else 
    this.StorePlayers(ps);
  this.pmap = []; // maps player id to SBP structure
  for (var i=0; i<this.ps.length; i++) {
    this.pmap[this.ps[i].data.id] = this.ps[i];
    }
  error('data loaded');
  return true;
  }

function FormatPlayerPhotoName(pp, optionsp) {
  if (defined(pp)) {
    return HeadShot(pp, optionsp.id) + TagName(pp.sb, pp.data, optionsp);
    }
  else {
    return '<div class=nohead>p</div>';
    }
  }

function GetDivisionByName(dname) {
  for (var dnum = 0; dnum < tourney.divisions.length; dnum++) {
    if (tourney.divisions[dnum].name == dname) return tourney.divisions[dnum];
    }
  }

function HeadShot (pp, id) {
  var p = pp.data;
  var config = tourney.config;
  if (config.player_photos) {
    var s = '<div class=head><img class=head src="'
      + p.photo
      + '" alt="[head shot]" id="'
      + id
      + '">';
    if (config.scoreboard_teams && PlayerTeam(p)) {
      s += '<span class=team><img src="http://www.worldplayerschampionship.com/images/flags/'
	+ PlayerTeam(p).toLowerCase()
	+ '.gif" id="'+id+'_f" alt=""></span>';
      }
    s += "</div>";
    return s;
    }
  else {
    return "&nbsp;";
    }
  }

function InTheMoney (sb, p) {
  var dp = sb.dp;
  var r0 = sb.r0;
  var config = tourney.config;
  var crank;
  if (sb.is_capped) {
    crank = PlayerRoundCappedRank(p, r0);
    }
  else {
    crank = PlayerRoundRank(p, r0);
    }
  var is_in_money = 0;
  var prize_bands = config.prize_bands;
  if (prize_bands) {
    var prize_band = prize_bands[dp.name];
    if (prize_band) {
      if (crank <= prize_band[prize_band.length-1]) {
	is_in_money = 1;
	}
      }
    }
  return is_in_money;
  }

function KeepLoadingScoreBoard(argh) {
  the_sb = new ScoreBoard(argh);
  the_sb.Render();
  the_sb.Resize();
  the_sb.AdjustOffset(0);
  window.onresize = function () { the_sb.Resize(); the_sb.Update(true); }
  var ticker = function () {
    if (!document.getElementById(the_sb.id)) return;
    window.setTimeout(ticker, 50);
    the_sb.Tick();
    }
  ticker();
  }

function ScoreBoard(argh) {
  this.pfu = new PoslFetchURL(argh.url);
  this.columns = argh.columns;
  this.dname = argh.dname;
  this.dp = undefined;
  this.id = argh.id;
  this.offset = argh.offset;
  this.rows = argh.rows;
  this.reload_rate = 20 * (argh.refresh || 10);
  this.reload_count = 0;
  this.scroll_count = 0;
  this.scroll_rate = 0;
  this.url = argh.url;
  this.Fetch(false);
  }

ScoreBoard.prototype.Render = function () {
//alert('SB.Render');
  var html = '';
  var ref = document.getElementById(this.id);
  if (!ref) { alert('Cannot find element "'+this.id+'".'); return; }
  html += '<table class=scoreboard><tr><td>';
  html += this.RenderTable();
  html += '</td></tr></table>';
  html += '<div class=sbctl>tsh scoreboard controls: <a href="#" onclick="the_sb.AdjustRows(-1);return false">fewer</a> <a href="#" onclick="the_sb.AdjustRows(1);return false">more</a> rows <a href="#" onclick="the_sb.AdjustColumns(-1);return false">fewer</a> <a href="#" onclick="the_sb.AdjustColumns(1);return false">more</a> columns <a href="#" onclick="the_sb.AdjustOffset(-1);return false">higher</a> <a href="#" onclick="the_sb.AdjustOffset(1);return false">lower</a> ranks <a href="#" onclick="the_sb.AdjustScroll(-1);return false">slower</a> <a href="#" onclick="the_sb.AdjustScroll(1);return false">faster</a> scroll <a href="#" onclick="the_sb.reload_count = 0;the_sb.Fetch(true);return false">refresh now</a> <span id=error></span></div>';
  ref.innerHTML = html;
  }

function RenderBoard (sb, b) {
  var board = '';
  if (b) {
    if (sb.c_has_tables) {
      if (sb.c_has_tables) board = DivisionBoardTable(sb.dp, b);
      }
    else if (!sb.c_no_boards) {
      board = b;
      }
    if ((board+"").length) board = " \@"+board;
    }
  return board;
  }

ScoreBoard.prototype.RenderTable = function () {
  var dp = this.dp;
  var html = '';
  html += '<div id=sbs>';

  for (var po = 0; po < this.ps.length; po++) {
    var sbp = this.ps[po];
    var p = sbp.data;
    var out_of_the_money = po + 1 >= dp.first_out_of_the_money;
    html += sbp.Render(po ? this.ps[po-1].data : undefined, out_of_the_money, true);
    }
  html += '</div><br clear=all>';
  if (0) html += '\
<script language="JavaScript" type="text/javascript"><!--\
  function fix_sizes () {\
  var p = document.getElementById(\'sbs\').firstChild\
  var maxh, minh;\
  maxh = minh = p.offsetHeight;\
  while (p = p.nextSibling) {\
if ((p.className != \'sbp\' && p.className != \'sbp money\') { continue) // ; }\
    if (maxh < p.offsetHeight) { maxh = p.offsetHeight; }\
    if (minh > p.offsetHeight) { minh = p.offsetHeight; }\
    }\
  p = document.getElementById(\'sbs\').firstChild;\
  p.style.height = maxh;\
  while (p = p.nextSibling) {\
if ((p.className != \'sbp\' && p.className != \'sbp money\') { continue) // ; }\
    p.style.height = maxh;\
    }\
  }\
  setTimeout(\'fix_sizes()\', 1000);\
--></script>\
';
  return html;
  }

ScoreBoard.prototype.Resize = function () {
  var winHeight = getWindowHeight();
  var winWidth = getWindowWidth();
  this.cell_hspacing = Math.floor(winWidth / this.columns);
  this.cell_vspacing= Math.floor((winHeight-20) / this.rows);
  this.cell_width = this.cell_hspacing - 5;
  this.cell_height = this.cell_vspacing - 5;
  this.photo_size = Math.max(24, Math.min(Math.round(this.cell_width-112), this.cell_height-112));
  if (this.ps) {
    for (var i=0; i<this.ps.length;i++) {
      this.ps[i].Resize();
      }
    }
  }

ScoreBoard.prototype.StorePlayers = function (ps) {
  this.ps = [];
  for (var i=0; i<ps.length; i++) {
    this.ps.push(new ScoreBoardPlayer(this, ps[i], this.id + '_' +ps[i].id));
    }
  }

function TagName(sb, p, optionsp) {
  if (!optionsp) optionsp = {};
  var name = PlayerName(p);
  var is_chinese = PlayerTeam(p).match(/^(?:MYS|SGP)$/) && name.match(/ .* /);
  var is_thai = p.xthai;
  var rv;
  if (!defined(is_thai)) {
    if (name.match(/Charnwit$/))
      is_thai = 1;
    else if (PlayerTeam(p) == 'THA') {
      rv = name.match(/^(.*), (.*)$/);
      if (rv.length == 3) {
	if (thai_name_cache[rv[2]] && thai_name_cache[rv[2]] != name) {
	  is_thai = 0;
	  }
	else {
	  thai_name_cache[rv[2]] = name;
	  is_thai = 1;
	  }
	}
      else { is_thai = 0; }
      }
    else { is_thai = 0; }
    p.xthai = is_thai;
    }

  rv = name.match(/^(.*), (.*)$/);
  if (rv) {
    var given = rv[2];
    var surname = rv[1];
    if (is_thai) {
      surname = '';
      }
    else if (is_chinese) {
      if (name == 'Wee, Ming Hui Hubert') {
	given = 'Wee Ming';
	surname = 'Hui Hubert';
        }
      else {
	given = rv[1];
	surname = rv[2];
        }
      }
    rv = surname.match(/^(.*)-(.*)$/);
    if (rv) {
      var surname1 = rv[1];
      var surname2 = rv[2];
      if (surname2.length < surname1.length + given.length) {
	given = given+' '+surname1 + "-";
	surname = surname2;
	}
      }
    if (optionsp.show_id) {
      var classn = sb.has_classes ? '/' + PlayerClass(p) : '';
      if (surname.length > given.length) {
	given += " (#" + p.id + classn + ")";
	}
      else {
	surname += " (#" + p.id + classn + ")";
	}
      }
    name = "<div class=name>"
      + "<span class=given>" + given + "</span>"
      + "<span class=surname>" + surname + "</span>"
      + "</div>";
    }
  else { // school scrabble tagging
    var names = name.split(/\s+/);
    var split;
    var half = names.join(' ').length/2;
    for (var i = 0; i < names.length; i++) {
      if (names.slice(0,1).join(' ').length > half) {
	if (Math.abs(names.slice(0,i).join(' ').length-half) > 
	  Math.abs(names.slice(0,i-1).join(' ').length-half)) {
	  split = i;
	  }
	else {
	  split = i+1;
	  }
	break;
        }
      }
    if (names.length> 1 && split == 0) { split = 1; }
    name = "<div class=name><span class=given>"
      + names.slice(0,split-1).join(' ')
      + "</span><span class=surname>"
      + names.slice(split, names.length-1).join(' ')
      + "</span></div>";
    }
  return name;
  }

// to be called every 0.05 s
ScoreBoard.prototype.Tick = function () {
  var active = 0;
  for (var i=0; i<this.ps.length; i++) {
    if (this.ps[i].Tick()) active = 1;
    }
  if (this.reload_rate) {
    this.reload_count++;
//  error(this.reload_count);
    if (0 == this.reload_count % 20) {
      error('...'+(this.reload_rate-this.reload_count)/20);
      }
    if (this.reload_count >= this.reload_rate) {
      this.reload_count = 0;
      this.Fetch(true);
      }
    }
  if ((!active) && this.scroll_rate) {
    if (this.scroll_count++ >= 40 / this.scroll_rate) {
      this.scroll_count = 0;
      if (this.offset + this.rows * this.columns >= this.ps.length) {
	this.offset = 0;
        this.AdjustOffset(0);
        }
      else {
        this.AdjustOffset(1);
        }
      }
    }
  }

ScoreBoard.prototype.Update = function(animated) {
//console.log('update');
  for (var i = 0; i < this.ps.length; i++) {
    this.ps[i].SetPosition(i, animated);
    }
  }

// TSH::Division

function DivisionBoardTable (dp, b) {
  var config = tourney.config;
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

// not currently used
//
// function DivisionComputeRanks(dp, sr0) {
//   var sorted = PlayerSortByStanding(sr0, DivisionPlayers(dp))
//   PlayerSpliceInactive(sorted, 1, sr0);
//   var lastw = -1;
//   var lastl = -1;
//   var lasts = 0;
//   var rank = 0;
//   for (var i=0; i<sorted.length; i++) {
//     var p = sorted[i];
//     var wins = PlayerRoundWins(p,sr0);
//     var losses = PlayerRoundLosses(p,sr0);
//     var spread = PlayerRoundSpread(p,sr0);
//     if (wins != lastw || spread != lasts || losses != lastl) {
//       lastw = wins;
//       lastl = losses;
//       lasts = spread;
//       rank = i+1;
//       }
//     PlayerRoundRank(p, sr0, rank);
//     }
//   }

function DivisionCountPlayers(dp) {
  return dp.players.length - 1;
  }

function DivisionHasTables(dp) {
  return tourney.config.tables && tourney.config.tables[dp.name];
  }

function DivisionMaxRound0(dp,round0) {
  var old = dp.maxr;
  if (defined(round0)) dp.maxr = round0;
  return old;
  }

function DivisionMostScores(dp) {
  return dp.maxs + 1;
  }

function DivisionSynch(dp) {
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
    for (var j=0; j<=last_score_r0; j++) { // number of scores
      var oppid = pairingsp[j];
      if (oppid && active) { last_ps = j; }
      var myscore = p.scores[j];
      if (defined(myscore)) nscores++;
      if (!defined(oppid)) {
	if (defined(myscore)) {
	  var name = PlayerTaggedName(p, dp);
	  var r1 = j + 1;
	  }
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
	if (thisSpread > full_caps) {
	  thisSpread = full_caps;
	  }
	else if (thisSpread < -full_caps) {
	  thisSpread = -full_caps;
	  }
	}
      if (penaltiesp) 
        thisSpread += (penaltiesp[j]||0);
      spread += thisSpread;
      rspread.push(spread);
      if (caps) {
	var cappedSpread = thisSpread;
	if (cappedSpread > caps[j]) 
	  cappedSpread = caps[j];
	else if (cappedSpread < -caps[j]) 
	  cappedSpread = -caps[j];
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

  if (config.track_firsts) { // must come after maxp computation
    DivisionSynchFirsts(dp);
    }
  }

function DivisionPlayers(dp) {
  var datap = dp.players;
  return datap.slice(1);
  }

function DivisionSynchFirsts(dp) {
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

// TSH::Player

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

function PlayerClass (p) {
  return p.etc['class'] ? p.etc['class'].join(' ') : '';
  }

function PlayerCountRoundRepeats (opp, r0) { 
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
  return p.scores ? p.scores.length : 0;
  }

function PlayerFirst(p, round0) {
  if (round0 < 0) return 0;
  return defined(p.etc.p12[round0]) ? p.etc.p12[round0] : (p.wins || 0);
  }

function PlayerName (p) {
  var name = p.name || '?';
  name = name.replace(/,\s*$/, '');
  return name;
  }

function PlayerNewRating(p) {
  return defined(p.etc.newr) ? p.etc.newr[0] : 0;
  }

function PlayerOpponent(p, r0, dp) {
  return p.pairings[r0] && dp.players[p.pairings[r0]];
  }

function PlayerOpponentID(p, r0) {
  return p.pairings[r0];
  }

function PlayerPrettyName(p) {
  if (!p.prettyname) {
    var name = PlayerName(p);
    name = name.replace(/^Zxqkj, Winter$/, 'Winter');
    if (tourney.config.surname_last) 
      name = name.replace(/^([^,]+), (.*)$/, "$2 $1");
    p.prettyname = name;
    }
  return p.prettyname;
  }

function PlayerRoundLosses(p, round0) {
  if (round0 < 0) return 0;
  return defined(p.rlosses[round0]) ? p.rlosses[round0] : (p.losses || 0);
  }

function PlayerRoundRank(p, round0, newrank) {
  var ranksp = p.rrank;
  if (!defined(ranksp)) { p.rrank = ranksp = []; }
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
  return defined(p.rwins[round0]) ? p.rwins[round0] : (p.wins || 0);
  }

function PlayerScore(p, round0, newscore, dp) {
  var scoresp = p.scores;
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

function PlayerSortByStanding (sr0, ps) {
  return ps.sort(function (a,b) {
    return sr0 >= 0 ? 
      (compare(defined(b.rwins[sr0]) ? b.rwins[sr0] : b.wins, defined(a.rwins[sr0]) ? a.rwins[sr0] : a.wins) ||
      (compare(defined(a.rlosses[sr0]) ? a.rlosses[sr0] : a.losses, defined(b.rlosses[sr0]) ? b.rlosses[sr0] : b.losses)) ||
      (compare(defined(b.rspread[sr0]) ? b.rspread[sr0] : b.spread, defined(a.rspread[sr0]) ? a.rspread[sr0] : a.spread)) || 
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

function PlayerTaggedName(p, style, dp) {
  if (!defined(style)) style = '';
  var clean_name = (style == 'print' && p.etc.pname)
    ? p.etc.pname.join(' ')
    : PlayerPrettyName(p);
  var fullid = FullID(p);
  var team = '';
  var config = tourney.config;
  if (tourney.config.show_teams)
    team = '/' + PlayerTeam(p);
  return (defined(p) && clean_name.length) ? clean_name + ' (' + fullid + team + ')' : 'nobody';
  }

function PlayerTeam(p) {
  return p.etc.team ? p.etc.team.join(' ') : '';
  }

// TSH::Utility

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
  if (n.match(/(?:^1|^[^1]1|.[^1]1)$/)) { n += 'st'; }
  else if (n.match(/(?:^2|^[^1]2|.[^1]2)$/)) { n += 'nd'; }
  else if (n.match(/(?:^3|^[^1]3|.[^1]3)$/)) { n += 'rd'; }
  else { n += 'th' };
  return n;
  }
