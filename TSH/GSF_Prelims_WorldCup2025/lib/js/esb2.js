"use strict";

var tourney;

var undefined;

var gCachedESBMsgMode = '';
var gCachedESBMsgText = '';
var gTerms;

var gcControlHeight = 20;

if (isAppleHandheld()) {
  setTimeout(function () { scrollTo(0,1) }, 1);
  }

function getWindowHeight () {
  if (isAppleHandheld()) {
    return document.documentElement.clientHeight + 160;
    }
  if (defined(window.innerHeight)) 
    return window.innerHeight - 3;
  else if (defined(document.documentElement) && document.documentElement.clientHeight) 
    return document.documentElement.clientHeight;
  else if (defined(document.body) && document.body.clientHeight) 
    return document.body.clientHeight;
  return 640;
  };
  
function getWindowWidth () {
  if (isAppleHandheld()) {
    return document.documentElement.clientWidth - 3;
    }
  if (defined(window.innerWidth)) 
    return window.innerWidth - 18;
  else if (defined(document.documentElement) && document.documentElement.clientWidth) 
    return document.documentElement.clientWidth;
  else if (defined(document.body) && document.body.clientWidth) 
    return document.body.clientWidth;
  return 640;
  };
  
function listContains (list, value) {
  var i;
  for (var i=0; i<list.length; i++) {
     if (list[i] === value) return true;
     }
  return false;
  }

// ScoreBoardMessage, written by G. Vincent Castellano

function ScoreBoardMessage (argh) {
  this.max_x;
  this.max_y;
  this.object = argh.object;
  this.sb = argh.scoreboard;
  this.Serial = 0;
  this.Text = "";
  this.windowHeight = undefined;
  this.windowWidth = undefined;
  this.x = 5; //Starting x coord.
  this.xoffset = 1; //Move 1px every step
  this.y = 5; //Starting y coord.
  this.yoffset = 1; //Move 1px every step
  }

ScoreBoardMessage.prototype.Go = function (mode, text) {
  var span = this.object;
  this.Serial++;
  this.x = 5;
  this.windowWidth  = getWindowWidth();
  this.windowHeight = getWindowHeight();
  span.innerHTML = '';
  this.Text = text; // this.wordwrap(20, 60, 'soft', text);
  if (text) {
    span.appendChild( document.createTextNode(text));
    if (mode == 'hide') { this.sb.Hide(); }
    if (mode == 'reveal') { this.sb.Show(); }
    this.max_x = this.windowWidth - span.offsetWidth; //maximum x coord.
    this.max_y = this.windowHeight - span.offsetHeight; //maximum y coord.
    this.Move(this.Serial);
    }
  else { this.sb.Show(); }
  };

ScoreBoardMessage.prototype.Move = function(MySerial) {
  if (MySerial != this.Serial) { return; } 
  this.x += this.xoffset;
  this.y += this.yoffset;
  //Move the image to the new location
  this.object.style.top = this.y+'px';
  this.object.style.left = this.x+'px';
  //if reach boundaries, reset offset vectors
  if ((this.x+this.xoffset > this.max_x) || (this.x+this.xoffset < 0))
    { this.xoffset *=-1; }
  if ((this.y+this.yoffset > this.max_y) || (this.y+this.yoffset < 0))
    { this.yoffset *=-1; }
  // call this.Move every 100 ms
  var closureThis = this;
  window.setTimeout(function () {closureThis.Move(MySerial)},100);
}

// ScoreBoardPlayer

function ScoreBoardPlayer (sb, data, id) {
  this.sb = sb;
  this.id = id;
  the_sbs[id] = this;
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
//    if (dir == 'x') console.log(dir,range,stopping_distance,'braking');
      if (this['delta_'+dir] != 0)
	this['delta_'+dir] -= this['delta_'+dir] / Math.abs(this['delta_'+dir]);
      }
    // not at maximum warp
    else if (range != 0 && speed < this['max_speed_'+dir]) {
//    if (dir == 'x') console.log(dir,range,stopping_distance,'accelerating');
//    this['delta_'+dir] += range / Math.abs(range);
      this['delta_'+dir] += (Math.floor(2.5*Math.random())) * range / Math.abs(range);
      }
    }
  // get moving
  else if (range != 0) {
    this['delta_'+dir] += range / Math.abs(range);
    }
  }

ScoreBoardPlayer.prototype.DragOver = function(event) {
  if (listContains(event.dataTransfer.types, "application/x-tsh-sb")) {
    event.preventDefault();
    return false;
    }
  return true;
  };

ScoreBoardPlayer.prototype.Drop = function(event) {
  var sbid = event.dataTransfer.getData("application/x-tsh-sb");
  var sb = the_sbs[sbid];
  if (sb) {
    sb.SplitDrop(event);
    event.preventDefault();
    return false;
    }
  else {
    console.log(this.id, 'Drop', "unknown sb", sbid);
    }
  };

ScoreBoardPlayer.prototype.JSName = function () { return "the_sbs['"+this.id+"']"; }

ScoreBoardPlayer.prototype.Render = function(lastp, outofthemoney, withcontainer) {
  if (this.sb.style == 'compact') return this.RenderCompact(lastp, outofthemoney, withcontainer);
  var p = this.data;
  var sb = this.sb;
  if (withcontainer) this.visible = false;
  var dp = sb.dp;
  var r0 = sb.r0;
  var r1 = sb.r1;
  var seed = dp.seeds[p.id-1];
  var html = '';
  var config = sb.tourney.config;
  var team_class;
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
//  var is_out_of_money = outofthemoney ? ' nomoney' : '';
    var is_out_of_money = ''; // temporarily disabled 2012-12-28
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
    if (config.scoreboard_teams && PlayerTeam(this)) 
      { team_class = ' team_' + PlayerTeam(this); }
    else { team_class = '';
    if (config.scoreboard_team_colours || config.scoreboard_team_colors) {
      is_in_money = is_out_of_money = '';
      }
    if (withcontainer) html += '<div id="'+this.id+'" class="sbp'+is_in_money+is_out_of_money+is_block_leader+team_class+'" style="position:absolute;left:0;top:0;display:none" ondragover="return '+this.JSName()+'.DragOver(event)" ondrop="return '+this.JSName()+'.Drop(event)">';
    html += '<table class=metable cellspacing=0 cellpadding=0 style="font-size:inherit"><tr><td><div class=me>';
    html += "<div class=rank>"
      + ConfigOrdinalTerm(config,crank)
      + "</div>";
    if (defined(PlayerScore(p, r0))) html += "<div class=old>"+gTerms.was+"<br>" + ConfigOrdinalTerm(config,lrank) + "</div>\n";
    if (sb.thai_points) html += "<div class=\"handicap\"><span class=label>HP</span><br><span class=value>" + (2*wins+((p.etc.handicap && p.etc.handicap[0])||0)) + "</span></div>\n";
    var currency_symbol = config.currency_symbol || '$';
    if (is_in_money) 
      html += "<div class=money>"+currency_symbol+"</div>";
    if (config.rating_system.match(/^(sudoku)/)) html += '<div class=wl>' + spread + '</div>';
    else html += "<div class=wl>" + UtilityFormatHTMLHalfInteger(wins)
	+ "&ndash;"
	+ UtilityFormatHTMLHalfInteger (losses) 
	+ (config.no_scores ? '' : ' ' + UtilityFormatHTMLSignedInteger(spread))
      + "</div>";
  }
  html += FormatPlayerPhotoName(this,{'id':this.id+'_mi','show_id':1});
  if (!config.rating_system.match(/^(none|glixo|sudoku)/)) { 
    var oldr = p.rating
    var newr = PlayerNewRating(p, r0);
    var delta = UtilityFormatHTMLSignedInteger(newr-oldr);
    html += "<div class=newr>"+newr+"</div>\n";
    if (oldr) {
      html += "<div class=oldr>="+oldr+"<br>"+delta+"</div>\n";
      }
    else {
      html += "<div class=oldr>"+gTerms.was+"<br>unrated</div>\n";
      }
  }
  html += "</div></td>\n"; // me
  html += "<td><div class=opp>\n"; // opp
  var last = this.RenderLastOpponent();
  var next = this.RenderNextOpponent();
  if (last) {
    html += '<div class="last'+(next ? '' : ' nonext')+'"><div class=title>'+gTerms.Last_Game_sb;
    if (config.entry == 'tagged') {
      var tag = p.etc && p.etc.tag && p.etc.tag[r0];
      if (tag) html += ' ' + tag;
      }
    html +="</div>"+last+"</div>\n";
    }
  if (next) {
    html += '<div class="next'+(last ? '' : ' nolast')+'"><div class=title>'+gTerms.Next_Game_sb+"</div>"+next+"</div>\n";
    }
  if (!config.rating_system.match(/^(sudoku)/)) { // record
    var record = '';
    var nrounds = PlayerCountScores(p);
    if (nrounds > r1) nrounds = r1;
    if (nrounds > 1) {
      var maxw = 12;
      if (nrounds > maxw) {
	maxw = Math.floor((nrounds+maxw-1)/maxw);
	maxw = Math.floor((nrounds+maxw-1)/maxw); // doubled line, sic
	var ar0 = 0;
	record += '<div class=rdss>';
	while (ar0 < nrounds) {
	  var lastr0 = ar0 + maxw-1;
	  if (lastr0 > nrounds-1) lastr0 = nrounds-1;
	  record += '<div class=rds>';
	  for (var i0=ar0; i0<=lastr0; i0++) {
	    record += this.RenderRoundRecord(i0);
	    }
	  record += '</div>';
	  ar0 = lastr0 + 1;
	  }
	record += '</div>';
	}
      else {
	for (var ar0=0; ar0<nrounds; ar0++) {
          record += this.RenderRoundRecord(ar0);
	  }
	}
      }
    if (record) {
//    html += "<div class=record><div class=title>Rec<br>ord</div>"+record+"</div>\n";
      html += "<div class=record>"+record+"</div>\n";
      }
    }
  html += '</div></td></tr></table>'; // opp
  if (withcontainer) html += '</div>'; // sbp
  return html;
  }

ScoreBoardPlayer.prototype.RenderCompact = function(lastp, outofthemoney, withcontainer) {
  var p = this.data;
  var sb = this.sb;
  if (withcontainer) this.visible = false;
  var dp = sb.dp;
  var r0 = sb.r0;
  var r1 = sb.r1;
  var html = '';
  var config = sb.tourney.config;
  {
    var crank;
    var spread;
    if (sb.is_capped) { 
      crank = PlayerRoundCappedRank(p, r0);
      spread = PlayerRoundCappedSpread(p, r0);
      }
    else {
      crank = PlayerRoundRank(p, r0);
      spread = PlayerRoundSpread(p, r0);
      }
    var is_in_money = InTheMoney(sb, p) ? ' money' : '';
//  var is_out_of_money = outofthemoney ? ' nomoney' : '';
    var is_out_of_money = ''; // temporarily disabled 2012-12-28
    var wins = PlayerRoundWins(p, r0);
    var losses = PlayerRoundLosses(p, r0);
    if (withcontainer) html += '<div id="'+this.id+'" class="sbp compact'+is_in_money+is_out_of_money+'" style="position:absolute;left:0;top:0;display:none">';
    html += "<div class=rank>"
      + ConfigOrdinalTerm(config,crank)
      + "</div>";
    if (sb.thai_points) html += "<div class=\"handicap\"><span class=label>HP</span><span class=value>" + (2*wins+((p.etc.handicap && p.etc.handicap[0])||0)) + "</span></div>\n";
    var currency_symbol = config.currency_symbol || '$';
    if (config.rating_system.match(/^(sudoku)/)) html += '<div class=wl>' + spread + '</div>';
    else html += "<div class=wl>" + UtilityFormatHTMLHalfInteger(wins)
	+ "&ndash;"
	+ UtilityFormatHTMLHalfInteger (losses) 
	+ (config.no_scores ? '' : ' ' + UtilityFormatHTMLSignedInteger(spread))
      + "</div>";
  }
  if (!config.rating_system.match(/^(none|glixo|sudoku)/)) { 
    var oldr = p.rating
    var newr = PlayerNewRating(p, r0);
    html += "<div class=rating>";
    if (oldr) {
      html += oldr+"&rarr;";
      }
    html += newr+"</div>\n";
  }
  {
    /*
    var optionsp = {'id':this.id+'_mi','show_id':'at-end','container':'div'};
    html += HeadShot(this, optionsp);
    html += TagName(this.sb, p, optionsp);
    */
    var optionsp = {'id':this.id+'_mi','show_id':'at-end','container':'none'};
    html += '<div class=name>';
    html += HeadShot(this, optionsp);
    optionsp.container = 'none';
    optionsp.subcontainer = 'div';
    html += TagName(this.sb, p, optionsp);
    if (config.rating_system.match(/^(sudoku)/)) html += this.RenderLastOpponents();
    html += '</div>';
  }
  html += "</div>\n"; // me
  html += "<div class=opp>\n"; // opp
  { // next game
    var next = '';
    var oppid = PlayerOpponentID(p,r0+1);
    if (oppid) {
      var op = PlayerOpponent(p,r0+1, dp);
      var opp = sb.pmap[op.id];
      var first = PlayerFirst(p,r0+1);
      var repeats = PlayerCountRoundRepeats(p,op, r0+1);
      var board = RenderBoard(sb,PlayerBoard(p,r0+1));
      first = first == 1 ? gTerms['1st'] : first == 2 ? gTerms['2nd'] : '';
      next += "<div class=where>"+first+board+"</div>\n";
/*
      var optionsp = {'id':this.id+'_ni','show_id':'at-end','container':'div'};
      next += HeadShot(opp, optionsp);
      next += TagName(opp.sb, opp.data, optionsp);
*/
      var optionsp = {'id':this.id+'_ni','show_id':'at-end','container':'none'};
      next += '<div class=name>';
      next += HeadShot(opp, optionsp);
      optionsp.container = 'none';
      optionsp.subcontainer = 'div';
      next += TagName(opp.sb, opp.data, optionsp);
      next += '</div>';
      if (repeats > 1) {
	next += "<div class=repeats>"+ConfigRepeatTerm(config, repeats)+"</div>";
	}
      }
    else if (defined(oppid)) {
      next += "<div class=bye>"+gTerms.bye+"</div>";
      }
    if (next) {
//    html += "<div class=next><div class=title>"+gTerms.Next_Game_sb+"</div>"+next+"</div>\n";
      html += "<div class=next>"+next+"</div>\n";
      }
  }
  html += '</div>'; // opp
  if (withcontainer) html += '</div>'; // sbp
  return html;
  }

ScoreBoardPlayer.prototype.RenderLastOpponent = function () {
  var p = this.data;
  var sb = this.sb;
  var config = sb.tourney.config;
  if (config.rating_system.match(/^(sudoku)/)) return this.RenderLastOpponents();
  var dp = sb.dp;
  var r0 = sb.r0;
  var ms, os;
  var last = '';
  var oppid = PlayerOpponentID(p, r0);
  if (oppid) {
    var op = PlayerOpponent(p, r0, dp);
    var opp = sb.pmap[op.id];
//    if (!opp) { console.log('cannot find '+op.id+' in pmap'); }
    if (opp) {
      os = PlayerScore(op, r0);
      }
    else { // corrupt data, or inactive opponent
      }
    if (defined(os)) {
      ms = PlayerScore(p, r0);
      if (config.no_scores) {
	last += ms > os ? gTerms.W : ms == os ? gTerms.T : gTerms.L;
	}
      else {
	var spread = UtilityFormatHTMLSignedInteger(ms - os);
	last += "<div class=gs>"+ms+"&minus;"+os+"="+spread+"</div>";
	}
      }
    else {
      last += "<div class=gsn>no score yet</div>";
      }
    var first = PlayerFirst(p, r0);
    first = first == 1 ? gTerms['1st'] : first == 2 ? gTerms['2nd'] : '';
    var board = RenderBoard(sb, PlayerBoard(p, r0));

    last += "<div class=where>"+first+board+" vs.</div>\n";
    last += "<div class=hs>" 
      + FormatPlayerPhotoName(opp,{'id':this.id+'_li'}) 
      + "</div>";
    }
  else if (r0 >= 0) { // bye
    ms = PlayerScore(p,r0);
    ms = defined(ms) ?  ms >= 0 ? '+' + ms : ms : '';
    last += "<div class=bye>"+gTerms.bye+' '+ms+"</div>";
    }
  return last;
  }

ScoreBoardPlayer.prototype.RenderLastOpponents = function () {
  var p = this.data;
  var sb = this.sb;
  var config = sb.tourney.config;
  if (!config.rating_system.match(/^(sudoku)/))  return undefined;
  var dp = sb.dp;
  var r0 = sb.r0;
  var ms;
  var last = '';
  for (ri0=0; ri0<=r0; ri0++) {
    ms = PlayerScore(p, ri0);
    if (defined(ms)) last += ' <span class=score>' + ms + '</span>';
    else last += ' <span class=noscore>-</span>';
    }
  return last;
  }

ScoreBoardPlayer.prototype.RenderNextOpponent = function () {
  var p = this.data;
  var sb = this.sb;
  var config = sb.tourney.config;
  if (config.rating_system.match(/^(sudoku)/)) { return undefined; }
  var dp = sb.dp;
  var r0 = sb.r0;
  var next = '';
  var oppid = PlayerOpponentID(p,r0+1);
  if (oppid) {
    var op = PlayerOpponent(p,r0+1, dp);
    var opp = sb.pmap[op.id];
    var first = PlayerFirst(this.data,r0+1);
    var repeats = PlayerCountRoundRepeats(p,op,r0+1);
    var board = RenderBoard(sb,PlayerBoard(p,r0+1));
    first = first == 1 ? gTerms['1st'] : first == 2 ? gTerms['2nd'] : '';
    if (repeats > 1) {
      next += "<div class=repeats>"+ConfigRepeatTerm(config, repeats)+"</div>";
      }
    next += "<div class=where>"+first+board+" vs.</div>\n";
    next += "<div class=hs>" 
      +FormatPlayerPhotoName(opp,{'id':this.id+'_ni','show_id':'at-end'})
      + "</div>";
    }
  else if (defined(oppid)) {
    next += "<div class=bye>"+gTerms.bye+"</div>";
    }
  return next;
  }

ScoreBoardPlayer.prototype.RenderRoundRecord = function (r0) {
  var record = ''; 
  var dp = this.sb.dp;
  var config = this.sb.tourney.config;
  var ms, os;

  ms = this.data.scores[r0];
  record += "<div class=rd>";
  if (this.data.pairings[r0]) {
    os = dp.players[this.data.pairings[r0]].scores[r0];
    if (defined(os)) {
      record += ms > os ? "<div class=win>"+gTerms.W+"</div>"
	: ms < os ? "<div class=loss>"+gTerms.L+"</div>"
	: "<div class=tie>"+gTerms.T+"</div>";

      }
    else {
      record += "<div class=unknown>?</div>";
      }
    }
  else if (defined(ms)) { record += ms > 0 ? "<div class=bye>"+gTerms.B+"</div>"
      : ms < 0 ? "<div class=forfeit>"+gTerms.F+"</div>"
      : "<div class=missed>&ndash;</div>";
    }
  if (config.track_firsts) {
    var p12 = PlayerFirst(this.data, r0);
    if (p12 && (""+p12).match(/^[12]$/)) {
      record += "<div class=p"+p12+">"+p12+"</div>";
      }
    else {
      record += "<div class=p0>&ndash;</div>";
      }
    }
  record += "</div>";
  return record;
  }

ScoreBoardPlayer.prototype.Rerender = function (lastp, outofthemoney) {
  var ref = document.getElementById(this.id);
  if (!ref) { 
    console.log("SBP.Rerender(): Can't get DOM object for "+this.id);
    return; 
    }
  ref.innerHTML = this.Render(lastp, outofthemoney, false);
  if (InTheMoney(this.sb, this.data)) ref.className = 'sbp money';
  else if (outofthemoney) ref.className = 'sbp nomoney';
  else ref.className = 'sbp';
  if (this.sb.style == 'compact') ref.className += ' compact';
  else if (this.sb.style == '2013') ref.className += ' 2013';
  this.Resize();
  }

ScoreBoardPlayer.prototype.Resize = function () {
  var aspect = this.sb.tourney.config.player_photo_aspect_ratio || 1;
  var ref = document.getElementById(this.id);
  if (!ref) {
    return;
    }
  ref.style.height = this.sb.cell_height + 'px';
  ref.style.width = this.sb.cell_width + 'px';
  if (this.sb.style == 'compact') {
    this.SetPhotoSize('_mi',   this.sb.photo_size, aspect * this.sb.photo_size  );
    this.SetPhotoSize('_mi_f', this.sb.photo_size, this.sb.photo_size);
    this.SetPhotoSize('_li',   this.sb.photo_size, aspect * this.sb.photo_size);
    this.SetPhotoSize('_li_f', this.sb.photo_size, undefined);
    this.SetPhotoSize('_ni',   this.sb.photo_size, aspect * this.sb.photo_size);
    this.SetPhotoSize('_ni_f', this.sb.photo_size, this.sb.photo_size);
    }
  else {
    this.SetPhotoSize('_mi',   this.sb.photo_size  , aspect * this.sb.photo_size  );
    this.SetPhotoSize('_mi_f', this.sb.photo_size/3, undefined);
    this.SetPhotoSize('_li',   this.sb.photo_size/2, aspect * this.sb.photo_size/2);
    this.SetPhotoSize('_li_f', this.sb.photo_size/6, undefined);
    this.SetPhotoSize('_ni',   this.sb.photo_size/2, aspect * this.sb.photo_size/2);
    this.SetPhotoSize('_ni_f', this.sb.photo_size/6, undefined);
    }
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
  var columns;
  if (sb.style == 'compact') {
    columns = 1;
    }
  else {
    columns = sb.columns;
    }
  if (pi < 0 || pi >= sb.rows * columns) {
    this.SetVisible(false);
    return;
    }
  var i = pi % columns;
  var j = Math.floor(pi/columns);
  var ref = document.getElementById(this.id);
  if (animated) {
    this.target_x = i * sb.cell_hspacing;
    this.target_y = j * sb.cell_vspacing + gcControlHeight;
    if (sb.banner_height) this.target_y += sb.banner_height+5;
//  console.log(po,pi,this.target_x,this.target_y,this.visible);
    }
  else {
    this.current_x = i * sb.cell_hspacing;
    this.current_y = j * sb.cell_vspacing + gcControlHeight;
    if (sb.banner_height) this.current_y += sb.banner_height+5;
    this.delta_x = 0;
    this.delta_y = 0;
    }
  ref.style.left = this.current_x + 'px';
  ref.style.top = this.current_y + 'px';
//console.log('SBP.SetPosition', this.id, ref.style.left, ref.style.top);
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
  if (!ref) { 
    console.log("SBP.Tick(): Can't get DOM object for "+this.id) 
    return;
    }
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
  var is_moving = this.delta_x || this.delta_y;
  var opacity = 1;
  if (is_moving) opacity = .5;
  ref.style.opacity = opacity;
  // The following is for compatibility with IE8 and earlier
  ref.style.filter = 'alpha(opacity=' + Math.floor(100*opacity) + ')';
  return is_moving;
  }

// TSH::Command::ScoreBoard

var root_sb_id;
var the_sbs = {};
var thai_name_cache = {};

// constructor
function ScoreBoard(argh) {
  if (defined(the_sbs[argh.id])) {
    alert("Internal error: duplicate ScoreBoard ID: "+argh.id);
    return;
    }
  the_sbs[argh.id] = this;
  this.id = argh.id; // render the scoreboard in the object with this CSS ID

  this.pfu = new PoslFetchURL(argh.url);

  // blink parameters
  this.blink_count = 0;
  this.blink_rate =  0;
  this.blink_state = 0;
  // banner parameters
  this.banner_height = argh.banner_height;
  this.banner_url = argh.banner_url;
  // settings display
  this.settingsVisible = false;

  // split screen parameters
  this.children = undefined; // link to children objects if present
  this.child_share = 0; // negative if children side-by-side, positive if child stacked
  this['parent'] = argh['parent']; // link back to parent scoreboard, if present
  if (this['parent']) this.tourney = this['parent'].tourney;

  // which players to display
  this.offset = argh.offset; // offset of first displayed rank from top actual rank
  this.columns = argh.columns;
  this.rows = argh.rows; // number of rows to display

  // links to TSH structures
  this.dname = argh.dname;
  this.dp = undefined;

  this.message = new ScoreBoardMessage({
    'object':argh.message_object,
    'scoreboard':this
    });
  this.order = 'board';
  this.orders = ['ranked','id','board'];
  // round number being displayed
  this.r1 = 0;
  this.real_r1 = 0;
  // refresh rate parameters
  this.reload_rate = 20 * (argh.refresh || 10);
  this.reload_count = 0;
  // scroll parameters
  this.scroll_count = 0;
  this.scroll_rate = 0;
  this.styles = ['normal', 'compact', 'blink'];
  this.url = argh.url;
  this.viewing_live = true;
  if (window.localStorage) {
    // TODO: why aren't we loading columns, rows and offset here?
    this.show_photos = parseInt(localStorage.getItem('show_photos'));
    this.style = localStorage.getItem('style');
    if (!this.dname) this.dname = localStorage.getItem('dname');
    if (isNaN(this.show_photos)) this.show_photos = 1;
    }
  else {
    this.show_photos = 1;
    this.style = 'normal'; 
    }
  this.Synch(false, false);
  }

ScoreBoard.prototype.AdjustColumns = function(delta) {
  var ref;

  this.columns += delta;
  if (this.columns < 1) this.columns = 1;
  if (window.localStorage) localStorage.setItem('columns', this.columns);

  ref = document.getElementById(this.id+'_sbctl_columns');
  ref.innerHTML = this.columns;
  ref = document.getElementById(this.id+'_sbctl_minus_columns');
  if (ref) ref.disabled = this.columns > 1 ? false : true;

  this.AdjustOffset(0);
  this.Resize();
  this.UpdatePositions(true);
  }

ScoreBoard.prototype.AdjustDivision = function(dname) {
  var di, dname, dname2, ref;
  this.dname = dname;
  this.dp = undefined;
  if (window.localStorage) localStorage.setItem('dname', dname);
  for (var di=1; di<=TournamentCountDivisions(this.tourney); di++) { 
    dname2 = DivisionName(TournamentDivisions(this.tourney)[di-1]);
    ref = document.getElementById(this.id+'_sbctl_'+dname2+'_div');
    if (ref) ref.disabled = dname2 == this.dname ? true : false;
    else error("No element "+this.id+'_sbctl_'+dname2+'_div');
    }
  this.Synch(false, false); // build player data structures
  this.Render(); // build player DOM objects
  this.Resize(); // size objects correctly
  this.AdjustOffset(0);
  this.UpdatePositions(true); // position objects correctly
  }

ScoreBoard.prototype.AdjustFont = function(delta) {
  var ref = this.DOMReference();
  var size = 1*this.RenderMyFont().replace(/%$/,'');

  size += delta;
  if (size < 10) size = 10;
  if (ref) { ref.style.fontSize = size + '%'; }

  ref = document.getElementById(this.id+'_sbctl_font');
  ref.innerHTML = this.RenderMyFont();
  ref = document.getElementById(this.id+'_sbctl_minus10_font');
  if (ref) ref.disabled = size >= 20 ? false : true;
  ref = document.getElementById(this.id+'_sbctl_minus1_font');
  if (ref) ref.disabled = size >= 11 ? false : true;

  if (delta) {
    this.Resize();
    }
  }

ScoreBoard.prototype.AdjustOffset = function(delta) {
  var columns, maxOffset, ref;
  if (this.style == 'compact') { columns = 1; }
  else { columns = this.columns; }
  this.offset += delta;
  maxOffset = this.ps.length - columns - 1;
  if (this.offset > maxOffset) this.offset = maxOffset;
  if (this.offset < 0) this.offset = 0;
  if (window.localStorage) localStorage.setItem('offset', this.offset);

  ref = document.getElementById(this.id+'_sbctl_rank');
  ref.innerHTML = (this.offset + 1) + '&ndash;' + Math.min(this.ps.length, this.offset + columns * this.rows);
  ref = document.getElementById(this.id+'_sbctl_minus5_rank');
  if (ref) ref.disabled = this.offset > 4 ? false : true;
  ref = document.getElementById(this.id+'_sbctl_minus1_rank');
  if (ref) ref.disabled = this.offset > 0 ? false : true;
  ref = document.getElementById(this.id+'_sbctl_plus1_rank');
  if (ref) ref.disabled = this.offset <= maxOffset ? false : true;
  ref = document.getElementById(this.id+'_sbctl_plus5_rank');
  if (ref) ref.disabled = this.offset <= maxOffset - 5 ? false : true;

  this.UpdatePositions(true);
//this.Resize();
//this.Render();
  }

ScoreBoard.prototype.AdjustPhotos = function(newvalue) {
  var ref;
  this.show_photos = newvalue;
  if (window.localStorage) localStorage.setItem('show_photos', this.show_photos);
  ref = document.getElementById(this.id+'_sbctl_off_photo');
  if (ref) ref.disabled = newvalue ? false : true;
  ref = document.getElementById(this.id+'_sbctl_on_photo');
  if (ref) ref.disabled = newvalue ? true : false;
  this.Synch(true, false);
  }

ScoreBoard.prototype.AdjustRound = function(delta, no_fetch) {
  var curr_ref = document.getElementById(this.id+'_sbctl_round');
  var prev_ref = document.getElementById(this.id+'_sbctl_previous_round');
  var next_ref = document.getElementById(this.id+'_sbctl_next_round');
  if (this.viewing_live) {
    if (delta < 0) {
      this.viewing_live = false;
      this.real_r1--;
      if (next_ref) next_ref.style.display = 'inline';
      }
    this.r1 = this.real_r1;
    this.r0 = this.r1 - 1;
    }
  else {
    this.r1 += delta;
    if (this.r1 < 0) this.r1 = 0;
    else if (this.r1 >= this.real_r1) {
      this.r1 = this.real_r1;
      this.viewing_live = true;
      if (next_ref) next_ref.style.display = 'none';
      }
    this.r0 = this.r1 - 1;
    }
  if (prev_ref) prev_ref.style.display = this.r1 > 0 ? 'inline' : 'none';
  if (curr_ref) curr_ref.innerHTML = this.RenderRound();
  if (!no_fetch) this.Synch(true, false);
  }

ScoreBoard.prototype.AdjustRows = function(delta) {
  var ref;

  this.rows += delta;
  if (this.rows < 1) this.rows = 1;
  if (window.localStorage) localStorage.setItem('rows', this.rows);

  ref = document.getElementById(this.id+'_sbctl_rows');
  ref.innerHTML = this.rows;
  ref = document.getElementById(this.id+'_sbctl_minus_rows');
  if (ref) ref.disabled = this.rows > 1 ? false : true;

  this.AdjustOffset(0);
  this.Resize();
  this.UpdatePositions(true);
  }

ScoreBoard.prototype.AdjustScroll = function(delta) {
  var ref;

  this.scroll_rate += delta;
  if (this.scroll_rate < 0) this.scroll_rate = 0;
  this.scroll_count = this.scroll_rate;

  ref = document.getElementById(this.id+'_sbctl_scroll');
  ref.innerHTML = this.RenderScrollRate();
  ref = document.getElementById(this.id+'_sbctl_slower_scroll');
  if (ref) ref.disabled = this.scroll_rate > 0 ? false : true;
  ref = document.getElementById(this.id+'_sbctl_faster_scroll');
  if (ref) ref.disabled = this.scroll_rate <= 14 ? false : true;
  }

ScoreBoard.prototype.AdjustSplit = function(delta) {
  var child_share, ref, split;
  var parent = this['parent'];

  if (!parent) { 
    ref = document.getElementById(this.id+'_sbctl_split');
    ref.innerHTML = this.RenderMySize();
    ref = document.getElementById(this.id+'_sbctl_minus5_split');
    ref.disabled = true;
    ref = document.getElementById(this.id+'_sbctl_minus1_split');
    ref.disabled = true;
    ref = document.getElementById(this.id+'_sbctl_plus1_split');
    ref.disabled = true;
    ref = document.getElementById(this.id+'_sbctl_plus5_split');
    ref.disabled = true;
    return;
    }
  split = this.MyShareAmongSiblings();
  split += delta/100;

  if (split > 1) this.offset = 1;
  if (split < 0) this.offset = 0;
  
  child_share = this.BirthOrder() ? 1 - split : split;
  if (parent.child_share < 0) { child_share = -child_share; }
  parent.child_share = child_share;

//if (window.localStorage) localStorage.setItem('split', this.split);

  ref = document.getElementById(this.id+'_sbctl_split');
  ref.innerHTML = this.RenderMySize();
  ref = document.getElementById(this.id+'_sbctl_minus5_split');
  if (ref) ref.disabled = split >= 0.05 ? false : true;
  ref = document.getElementById(this.id+'_sbctl_minus1_split');
  if (ref) ref.disabled = split >= 0.01 ? false : true;
  ref = document.getElementById(this.id+'_sbctl_plus1_split');
  if (ref) ref.disabled = split <= 0.99 ? false : true;
  ref = document.getElementById(this.id+'_sbctl_plus5_split');
  if (ref) ref.disabled = split <= 0.95 ? false : true;

  if (delta) {
    parent.Resize();
    parent.UpdatePositions(true);
    }
  }

ScoreBoard.prototype.AdjustStyle = function(newvalue) {
  var style, style_ref, this_ref;
  this.style = newvalue;
  this_ref = document.getElementById(this.id);
  if (window.localStorage) localStorage.setItem('style', this.style);
  if (this.style == 'compact') {
    if (this.rows < 20) this.rows = 20;
    }
  else {
    if (this.rows > 10) this.rows = 10;
    }
  if (this.style == 'blink') {
    this.blink_rate = 60;
    this.blink_count = 0;
    this.blink_state = 0;
    this_ref.className = 'alt' + (this.child_share ? 'p' : '0');
    }
  else {
    this.blink_rate = 0;
    this_ref.className = this.style;
    }
  for (var si=0; si<this.styles.length; si++) {
    style = this.styles[si];
    style_ref = document.getElementById(this.id+'_sbctl_'+style+'_style');
    if (style_ref) style_ref.disabled = style == this.style ? true : false;
    else error("No element "+this.id+'_sbctl_'+style+'_style');
    }
  this.Synch(true, false);
  this.Resize(); 
  this.UpdatePositions(true);
//this.reload_rate = 20*1000;// TODO DEBUG ONLY
  }

ScoreBoard.prototype.BirthOrder = function () {
  return this.id.replace(/^.*[^0-9]/,'');
  }

ScoreBoard.prototype.Close = function () {
  this['parent'].CloseChild(this.BirthOrder());
  }

ScoreBoard.prototype.CloseChild = function (birth_order) {
  var i;
  for (i=0; i<this.children.length; i++) {
    delete the_sbs[this.id+'_c'+i]; // they'll get recreated
    }
  this.children.splice(birth_order, 1);
  if (this.children.length == 1) {
    this.dname = this.children[0].dname;
    this.children = null;
    this.child_share = null;
    }
  else {
    console.log('Cannot close child when we do not have two.');
    return;
    }
  this.Synch(false, false);
  this.Render();
  this.Resize();
  this.UpdatePositions(true);
  }

ScoreBoard.prototype.DOMReference = function () {
  return document.getElementById(this.id);
  };

ScoreBoard.prototype.DragStart = function (event) {
  event.dataTransfer.effectAllowed = "move";
  event.dataTransfer.setData("application/x-tsh-sb", this.id);
  event.dataTransfer.setData("text/plain", "tsh enhanced scoreboard pane "+this.id);
  };

function FormatPlayerPhotoName(pp, optionsp) {
  if (defined(pp)) {
    return HeadShot(pp, optionsp) + TagName(pp.sb, pp.data, optionsp);
    }
  else {
    return '<div class=nohead>?</div>';
    }
  }

function HeadShot (pp, optionsp) {
  var p = pp.data;
  var id = optionsp.id;
  var tourney = pp.sb.tourney;
  var config = tourney.config;
  var container = optionsp.container || 'div';
  if (config.player_photos && pp.sb.show_photos) {
    var s = '';
    if (container != 'none') s += '<' + container + ' class=head>';
    s += '<img class=head src="'
      + p.photo
      + '" alt="[head shot]" id="'
      + id
      + '">';
    if (config.scoreboard_teams && PlayerTeam(p)) {
      if (PlayerTeam(p).length == 1) {
	s += '<span class=team><div class=label>'+PlayerTeam(p).toUpperCase()+'</div></span>';
	}
      else {
	s += '<span class=team><img src="http://www.worldplayerschampionship.com/images/flags/'
	  + PlayerTeam(p).toLowerCase()
	  + '.gif" id="'+id+'_f" alt=""></span>';
        }
      }
    if (container != 'none') s += "</" + container + ">";
    return s;
    }
  else {
    return "&nbsp;";
    }
  }

function InTheMoney (sb, p) {
  var dp = sb.dp;
  var r0 = sb.r0;
  var config = sb.tourney.config;
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

// used by external routines to initialize a root scoreboard
// TODO: check if one already exists?
function KeepLoadingScoreBoard(argh) {
  var the_sb = new ScoreBoard(argh);
  if (defined(root_sb_id)) {
    alert("internal error: duplicate root_sb_id");
    return;
    }
  if (!defined(argh.id)) {
    alert("internal error: no root_sb_id");
    return;
    }
  root_sb_id = argh.id;
  the_sb.Render();
  the_sb.Resize();
  the_sb.AdjustOffset(0);
  the_sb.AdjustPhotos(the_sb.show_photos);
  the_sb.AdjustSplit(0);
  the_sb.AdjustStyle(the_sb.style);
  window.onresize = function () { the_sb.Resize(); the_sb.UpdatePositions(true); }
  var ticker = function () {
    if (!document.getElementById(the_sb.id)) return;
    window.setTimeout(ticker, 50);
    if (the_sb) the_sb.Tick();
    }
  ticker();
  }

ScoreBoard.prototype.Height = function () { 
  if (this['parent']) {
    return this.DOMReference().offsetHeight;
    }
  else {
    return getWindowHeight() - (this.banner_height ? this_banner_height + 5 : 0);
    }
  };

ScoreBoard.prototype.Hide = function () { 
  this.DOMReference().style.display = 'none';
  }

ScoreBoard.prototype.HideSettings = function () { 
//console.log('HideSettings');
  var ref = document.getElementById(this.id+'_ctlbox');
  if (!ref) { error(this, 'HideSettings', 'no control box', this.id); return; }
  if (!ref.className.match(/ hidden/)) ref.className += ' hidden';
  this.settingsVisible = false;
  }

ScoreBoard.prototype.JSName = function () { return "the_sbs['"+this.id+"']"; }

// Called to initially create all necessary DOM objects
ScoreBoard.prototype.Render = function () {
  var config = this.tourney.config;
  var html = '';
  var myname = this.JSName();
  var ref = this.DOMReference();
  var dname;
  if (!ref) { alert('Cannot find element "'+this.id+'".'); return; }
  ref.className = 'altp'; // may be overridden by a blink in a child
  html += '<div class=sib0 id="'+this.id+'_c0" style="position:absolute;width:99%"><table class="scoreboard';
    if (config.rating_system.match(/^(sudoku)/)) html += ' sudoku';
  html += '" style="font-size:inherit"><tr><td>';
  html += this.RenderTable();
  html += '</td></tr></table>';
  html += '</div>';

  html += '<div class=splitter id="'+this.id+'_split" style="position:absolute;background-color:white;opacity:0.25" draggable="true" ondragstart="'+this.JSName()+'.DragStart(event)"></div>';
  html += this.RenderControls();
//console.log(this.id+'_split');
  html += '<div class=sib1 id="'+this.id+'_c1" style="position:absolute"></div>';
  if (this.banner_height) {
    html += '<iframe class=sbban src="'+this.banner_url+'" height='+this.banner_height+' width="100%" scrolling=no seamless style="position:absolute;top:0px;left:0px;">Please upgrade to a browser that supports iframes.</iframe>';
    }
  ref.innerHTML = html;
  }

ScoreBoard.prototype.GearClick = function () {
  var ref = document.getElementById(this.id+'_ctlbox');
  if (!ref) { error("no control box", this.id); return; }
//console.log('GearClick',ref.style.display);
  if (this.settingsVisible) this.HideSettings();
  else this.ShowSettings();
  }

ScoreBoard.prototype.MyShareAmongSiblings = function () {
  var size;
  var parent = this['parent'];
  if (parent) {
    size = Math.abs(parent.child_share);
    if (this.BirthOrder()) { size = 1 - size; }
    return size;
    }
  else {
    return undefined;
    }
  }

function RenderBoard (sb, b) {
  var board = '';
  if (b) {
    if (sb.c_has_tables) {
      if (sb.c_has_tables) 
	board = DivisionBoardTable(sb.dp, b, sb.tourney.config);
      }
    else if (!sb.c_no_boards) {
      board = b;
      }
    if ((board+"").length) board = " \@"+board;
    }
  return board;
  }

ScoreBoard.prototype.RenderControls = function () {
  var html = '';
  var myname = this.JSName();
  var title =
    (this.tourney.config.event_name ?
      this.tourney.config.event_name + ' ' : '') +
    (TournamentCountDivisions(this.tourney) > 1 ?
      gTerms['Division'] + ' '+ this.dname : '');
  html += '<style type="text/css">'+
    'body.enhanced.scoreboard div.sbctl.tools { left:auto; right:5; z-index: 5}' +
    'body.enhanced.scoreboard div.ctlbox { z-index:10;position:absolute;top:20px;right:20px;opacity:0.90;background-color:white }' +
    'body.enhanced.scoreboard div.ctlbox.hidden { display: none }' +
    'body.enhanced.scoreboard div.ctlbox table.ctls th { text-align: right; font-weight: normal; font-style: italic; padding: 0.1em 0.25em }' +
    'body.enhanced.scoreboard div.ctlbox table.ctls td { white-space: nowrap; padding: 0.1em 0.25em }' +
    'body.enhanced.scoreboard div.ctlbox table.ctls td.close { font-weight: bold; border-bottom: 1px solid black }' +
    'body.enhanced.scoreboard div.ctlbox table.ctls td.close button { float: right; }' +
    'body.enhanced.scoreboard div.ctlbox table.ctls tr > * { color: black; vertical-align: top; }' +
    'body.enhanced.scoreboard div.ctlbox table.ctls button { border-width:1px; background-color: #ffffff }'+
    'body.enhanced.scoreboard div.ctlbox table.ctls button:disabled { background-color: #e0e0e0 }'+
    'body.enhanced.scoreboard div.ctlbox table.ctls button.output { background-color: #ffffff; color: #b0b0b0 }'+
    '</style>';
  html += '<div class="sbctl title" style="top:'+(this.banner_height||0)+'" id="'+this.id+'_title">'+title+'</div>';
  html += '<div class="sbctl tools" style="top:'+(this.banner_height||0)+'" id="'+this.id+'_sbctl_tools">';
  html += '<span id=error></span> ';
  html += '<span class=note id=sbctl_note>&nbsp;</span> ';
  html += '<a href="#" title="Reload Now" onclick="'+myname+'.reload_count = 0;'+myname+'.Synch(true, false);return false">\u21bb</a> ';
  html += this['parent'] ? '<a href="#" title="Close Pane" onclick="'+myname+'.Close();return false">x</a> ': ''; // close button if we have a parent to close to
//html += '<span id="'+this.id+'_sbctl_split">';
  html += '<a href="#" title="Split Top and Bottom" onclick="'+myname+'.Split(0);return false">\u00f7</a> ';
  html += '<a href="#" title="Split Left and Right" onclick="'+myname+'.Split(1);return false">\u00b7|\u00b7</a> ';
//html += '</span>'; // buttons to split horizontally or vertically
  html += '<a href="#" title="View Previous Round" onclick="'+myname+'.AdjustRound(-1, false);return false" id='+this.id+'_sbctl_previous_round>\u226a</a> ';
  html += '<span id='+this.id+'_sbctl_round>' + this.RenderRound() + '</span> ';
  html += '<a href="#" title="View Next Round" onclick="'+myname+'.AdjustRound(1, false);return false" id='+this.id+'_sbctl_next_round style="display:none">\u226b</a> ';
  html += '<a class=gear href="#" title="Scoreboard Settings" onclick="'+myname+'.GearClick();return false">\u2699</a> ';
  html += '</div>'; // sbctl tools
  html += '<div class="ctlbox '+(this.settingsVisible ? '' : ' hidden')+'" id="'+this.id+'_ctlbox"><table class=ctls>';
    html += '<tr><td class=close colspan=2>Scoreboard Settings<button onclick="'+myname+'.GearClick()">X</button></td></tr>';
    if (TournamentCountDivisions(this.tourney) > 1) {
      html += this.RenderControlsDivisions();
      }
    html += '<tr><th>'+gTerms.rows+'</th><td><button onclick="'+myname+'.AdjustRows(-1);return false" id='+this.id+'_sbctl_minus_rows>&ndash;</button><button class=output id='+this.id+'_sbctl_rows>'+this.rows+'</button><button onclick="'+myname+'.AdjustRows(1);return false" id='+this.id+'_sbctl_plus_rows>+</button></td></tr>';
    html += '<tr><th>'+gTerms.columns+'</th><td><button onclick="'+myname+'.AdjustColumns(-1);return false" id='+this.id+'_sbctl_minus_columns>&ndash;</button><button class=output id='+this.id+'_sbctl_columns>'+this.columns+'</button><button onclick="'+myname+'.AdjustColumns(1);return false" id='+this.id+'_sbctl_plus_columns>+</button></td></tr>';
    html += '<tr><th>'+gTerms.photos+'</th><td><button onclick="'+myname+'.AdjustPhotos(1);return false" id='+this.id+'_sbctl_on_photo>'+ gTerms.photos_on+'</button><button onclick="'+myname+'.AdjustPhotos(0);return false" id='+this.id+'_sbctl_off_photo>'+gTerms.photos_off+'</button></td></tr>';
    html += '<tr><th>'+gTerms.style+'</th><td>'+this.RenderControlsStyles() + '</td></tr>';
    html += '<tr><th>'+gTerms.ranks+'</th><td><button onclick="'+myname+'.AdjustOffset(-5);return false" id='+this.id+'_sbctl_minus5_rank>-5</button><button onclick="'+myname+'.AdjustOffset(-1);return false" id='+this.id+'_sbctl_minus1_rank>-1</button><button class=output id='+this.id+'_sbctl_rank disabled>'+(this.offset+1)+'</button><button onclick="'+myname+'.AdjustOffset(1);return false" id='+this.id+'_sbctl_plus1_rank>+1</button><button onclick="'+myname+'.AdjustOffset(5);return false" id='+this.id+'_sbctl_plus5_rank>+5</button></td></tr>';
    html += '<tr><th>'+gTerms.scroll+'</th><td><button onclick="'+myname+'.AdjustScroll(-1);return false" id='+this.id+'_sbctl_slower_scroll' + (this.scroll_rate > 0 ? '' : ' disabled')+'>'+gTerms.slower+'</button><button class=output id='+this.id+'_sbctl_scroll>'+this.RenderScrollRate()+'</button><button onclick="'+myname+'.AdjustScroll(1);return false" id='+this.id+'_sbctl_faster_scroll>'+gTerms.faster+'</button></td></tr>';
    html += '<tr><th>'+gTerms.pane_size+'</th><td><button onclick="'+myname+'.AdjustSplit(-5);return false" id='+this.id+'_sbctl_minus5_split>-5</button><button onclick="'+myname+'.AdjustSplit(-1);return false" id='+this.id+'_sbctl_minus1_split>-1</button><button class=output id='+this.id+'_sbctl_split disabled>'+this.RenderMySize()+'</button><button onclick="'+myname+'.AdjustSplit(1);return false" id='+this.id+'_sbctl_plus1_split>+1</button><button onclick="'+myname+'.AdjustSplit(5);return false" id='+this.id+'_sbctl_plus5_split>+5</button></td></tr>';
    html += '<tr><th>'+gTerms.font_size+'</th><td><button onclick="'+myname+'.AdjustFont(-10);return false" id='+this.id+'_sbctl_minus10_font>-10</button><button onclick="'+myname+'.AdjustFont(-1);return false" id='+this.id+'_sbctl_minus1_font>-1</button><button class=output id='+this.id+'_sbctl_font disabled>'+this.RenderMyFont()+'</button><button onclick="'+myname+'.AdjustFont(1);return false" id='+this.id+'_sbctl_plus1_font>+1</button><button onclick="'+myname+'.AdjustFont(10);return false" id='+this.id+'_sbctl_plus10_font>+10</button></td></tr>';
  html += '</table></div>';
  html += '</div>';
  return html;
  };

ScoreBoard.prototype.RenderControlsDivisions = function () {
  var dname;

  var html = '<tr><th>' + gTerms.division + '</th><td>';
  var myname = this.JSName();

  for (var di=1; di<=TournamentCountDivisions(this.tourney); di++) { 
    dname = DivisionName(TournamentDivisions(this.tourney)[di-1]);
    html += '<button onclick="' + myname + '.AdjustDivision('+"'"+dname+"'"+');return false" class=division id="'+this.id+'_sbctl_'+dname+'_div"' + (dname == this.dname ? ' disabled' : '') + '>' + dname + '</button>';
    }
  html += '</td></tr>';
  return html;
  }

ScoreBoard.prototype.RenderControlsStyles = function () {
  var style;

  var html = '';
  var myname = this.JSName();

  for (var si=0; si<this.styles.length; si++) {
    style = this.styles[si];
    html += '<button onclick="'+myname+'.AdjustStyle('+"'"+style+"'"+');return false" id='+this.id+'_sbctl_'+style+'_style>'+ gTerms['style_'+style]+'</button>';
    }
  return html;
  }

ScoreBoard.prototype.RenderMyFont = function () {
  var size;
  var ref = this.DOMReference();
  if (!ref) { return '100%'; }
  size = ref.style.fontSize;
  if (defined(size) && size) { return size; }
  else { return '100%'; }
  }

ScoreBoard.prototype.RenderMySize = function () {
  var size = this.MyShareAmongSiblings();
  if (defined(size)) { return Math.round(size*100) + '%'; }
  else { return '100%'; }
  }

ScoreBoard.prototype.RenderRound = function () {
  if (this.viewing_live) {
    return '';
    }
  else {
    return gTerms.Round + ' ' + this.r1;
    }
  }

ScoreBoard.prototype.RenderScrollRate = function () {
  if (this.scroll_rate) {
//  return Math.floor(1000/this.scroll_rate)/10;
    return Math.floor(300/this.scroll_rate)/10;
    }
  else {
    return 'stopped';
    }
  }

ScoreBoard.prototype.RenderTable = function () {
//console.log(this.id,'RenderTable');
  var dp = this.dp;
  var myname = this.JSName();
  var html = '';
  html += '<div id=sbs>';
//html += '<div id=sbs onmouseover="'+myname+'.HideSettings();return false">';

  for (var po = 0; po < this.ps.length; po++) {
    var sbp = this.ps[po];
    var p = sbp.data;
    var out_of_the_money = po + 1 >= dp.first_out_of_the_money[this.r0];
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
  };

// should be called whenever our display size changes,
// typically followed by a call to UpdatePositions()
ScoreBoard.prototype.Resize = function () {
  var child0_dom, child1_dom, parent_banner_height, splitter_dom, winHeight, winWidth;
  var splitterWidth = 5;
  var winHeight = this.Height();
  var winWidth = this.Width();
  var myref = this.DOMReference();
//console.log('resize', this.id, winHeight, winWidth);
  // if we have kids, then assign their metrics
  if (this.child_share) {
    myref.className = 'altp'; // setting it to alt0 or alt1 nests blinking and fails
    child0_dom = document.getElementById(this.id+'_c0');
    child1_dom = document.getElementById(this.id+'_c1');
    splitter_dom = document.getElementById(this.id+'_split');

    if (this.child_share > 0) { // split top and bottom
      child1_dom.style.height = ((winHeight-splitterWidth) * this.child_share) + 'px';
      child1_dom.style.width = winWidth + 'px';
      winHeight = (winHeight-splitterWidth) * (1 - this.child_share);
      child1_dom.style.left = "0px";
      child1_dom.style.top = (winHeight + splitterWidth + (this.banner_height||0)) + 'px'; // the modified winHeight
      child0_dom.style.height = winHeight + 'px';
      child0_dom.style.width = winWidth + 'px';
      child0_dom.style.left = "0px";
      child0_dom.style.top = (this.banner_height||0) + 'px'; 
      splitter_dom.style.left = "0px";
      splitter_dom.style.top = (winHeight + (this.banner_height||0)) + 'px';
      splitter_dom.style.height = splitterWidth + 'px';
      splitter_dom.style.width = winWidth + 'px';
      }
    else { // split left and right
      child1_dom.style.height = winHeight + 'px';
      child1_dom.style.width = ((winWidth-splitterWidth) * (1+this.child_share)) + 'px';
      winWidth = (winWidth-splitterWidth) * (-this.child_share);
      child1_dom.style.left = (winWidth + splitterWidth) + 'px'; // the modified winWidth
      child1_dom.style.top = (this.banner_height||0) + 'px';
      child0_dom.style.height = winHeight + 'px';
      child0_dom.style.width = winWidth + 'px';
      child0_dom.style.left = "0px"; 
      child0_dom.style.top = (this.banner_height||0) + 'px';
      splitter_dom.style.left = winWidth + 'px';
      splitter_dom.style.top = (this.banner_height||0) + 'px';
      splitter_dom.style.height = winHeight + 'px';
      splitter_dom.style.width = splitterWidth + 'px';
      }
    if (this.children) { // child_share gets set before children
      this.children[0].Resize();
      this.children[1].Resize();
      }
    return; // rest is for leaf nodes
    }

//console.log('resize-squeezed', this.id, winHeight, winWidth);
  if (this.style == 'compact') {
    var aspect = this.tourney.config.player_photo_aspect_ratio || 1;
    this.cell_vspacing= Math.floor((winHeight-gcControlHeight) / this.rows);
    this.cell_height = this.cell_vspacing - 1;
    this.cell_hspacing = winWidth;
    this.cell_width = winWidth;
    this.photo_size = Math.floor(0.9 * this.cell_height/aspect);
    }
  else {
    this.cell_vspacing= Math.floor((winHeight-gcControlHeight) / this.rows);
//  console.log(this.id,this.cell_vspacing,winHeight,this.rows,gcControlHeight);
    this.cell_height = this.cell_vspacing - 5;
    this.cell_hspacing = Math.floor(winWidth / this.columns);
    this.cell_width = this.cell_hspacing - 9; // 5 seems tight on TVs
    this.photo_size = Math.max(24, Math.min(Math.round(this.cell_width-112), this.cell_height-112));
    }
//console.log('cell size',this.id,'c,r',this.columns,this.rows,'w,h',this.cell_width,this.cell_height,'hsp,vsp',this.cell_hspacing,this.cell_vspacing);
  if (this.ps) {
    for (var i=0; i<this.ps.length;i++) {
      this.ps[i].Resize();
      }
    }
  }

ScoreBoard.prototype.RerenderNote = function() {
  var note = '';
  var team_count = 0;
  for (var team in this.dp.team_wins) { team_count++; }
  if (team_count == 2) {
    note += '. Teams: ';
    for (var team in this.dp.team_wins) {
      note += ' ' + team + ' ' + this.dp.team_wins[team];
      }
    }
  var ref = document.getElementById('sbctl_note');
  if (ref) {
    ref.innerHTML = note;
    }
  }

function SetupTerminology(cfg) {
  return ConfigTerminology(cfg, { 
    '1st':[],
    '2nd':[],
    'B':[],
    'bye':[],
    'columns':[],
    'division':[],
    'Division':[],
    'data_loaded':[],
    'faster':[],
    'font_size':[],
    'F':[],
    'L':[],
    'Last_Game_sb':[],
    'Next_Game_sb':[],
    'pane_size':[],
    'photos':[],
    'photos_on':[],
    'photos_off':[],
    'style':[],
    'style_blink':[],
    'style_compact':[],
    'style_normal':[],
    'ranks':[],
    'Rec-ord':[],
    'Round':[],
    'rows':[],
    'scroll':[],
    'slower':[],
    'T':[],
    'W':[],
    'was':[]
    });
  }

ScoreBoard.prototype.SetTourney = function (tourney) {
  this.tourney = tourney;
  if (this.children) {
    this.children[0].SetTourney(tourney);
    this.children[1].SetTourney(tourney);
    }
  }

ScoreBoard.prototype.Show = function () { 
  this.DOMReference().style.display = 'block';
  }

ScoreBoard.prototype.ShowSettings = function () { 
//console.log(this,'ShowSettings');
  var ref = document.getElementById(this.id+'_ctlbox');
  if (!ref) { console.log(this, 'ShowSettings', 'no control box', this.id); return; }
  ref.className = ref.className.replace(/ hidden/,'');
  this.settingsVisible = true;
  }

ScoreBoard.prototype.Split = function (dir) {
  var child_id, child_js, ref;

//console.log(this.id,'Split',this.children);
  if (this.children) { alert('cannot currently have more than two children'); return; }
  if (dir == 0) { // split top and bottom
    this.child_share = 0.5;
    }
  else { // split left and right
    this.child_share = -0.5;
    }
  this.Resize();
  this.UpdatePositions(true);

  // make children
  this.children = [];
  for (var i=0; i<2; i++) {
    child_id = this.id + '_c' +i;
    this.children[i] = child_js = new ScoreBoard({
      id: child_id,
      url: this.url,
      dname: this.dname,
      columns: this.columns,
      rows: this.rows,
      offset: this.offset,
      style: this.style,
      'parent': this,
      });
    child_js.Render();
    child_js.Resize();
    child_js.UpdatePositions(true);
    }
  // hide controls
  ref = document.getElementById(this.id+'_sbctl_tools'); 
  if (ref) ref.style.display = 'none'; 
  ref = document.getElementById(this.id+'_title'); 
  if (ref) ref.style.display = 'none'; 
  this.HideSettings();
  }

ScoreBoard.prototype.SplitDrop = function (event) {
  var y1, y2;
  var newShare;
  if (this.child_share > 0) {
    y1 = event.clientY || event.y;
    y2 = this.Height();
    if (this.banner_height) {
      y1 -= this.banner_height + 5;
      y2 -= this.banner_height + 5;
      }
    newShare = y2 ? 1 - y1 / y2 : 0.5
    if (newShare > 0.9) newShare = 0.9;
    else if (newShare < 0.1) newShare = 0.1;
    }
  else if (this.child_share < 0) {
//  console.log('x', this, event, event.x, this.Width());
    newShare = -(event.clientX || event.x)/this.Width();
    if (newShare < -0.9) newShare = -0.9;
    else if (newShare > -0.1) newShare = -0.1;
    }
  else {
    console.log(this.id, 'SplitDrop', event, this.child_share, 'no children');
    return;
    }
  this.child_share = newShare;
  this.Resize();
  this.UpdatePositions(true);
  };

// create SBP object for each player 
// - DOM objects get created by RenderTable
ScoreBoard.prototype.StorePlayers = function (ps) {
  this.ps = [];
  for (var i=0; i<ps.length; i++) {
    this.ps.push(new ScoreBoardPlayer(this, ps[i], this.id + '_' +ps[i].id));
    }
  }

// is_update should be false the first time to require allocation of new
// player data structures, and true thereafter to inhibit it
//
// no_fetch should be false to fetch new data from the server, else true
ScoreBoard.prototype.Synch = function(is_update, no_fetch) {
  var content, newt, tourney;
  if (this.children) {
    this.children[0].Synch(is_update, no_fetch);
    this.children[1].Synch(is_update, no_fetch);
    }
  error('checking for updates');
  if (no_fetch || this.parent) {
    tourney = this.tourney;
    }
  else {
    content = this.tourney ? this.pfu.FetchCached() : this.pfu.FetchDirect();
    if (content) eval(content); else {
      error('null content returned');
      return false;
      }
    if (newt) this.SetTourney(tourney = newt); else {
      error('server reply did not contain tournament data');
      this.tourney = undefined;
      return false;
      }
    if (tourney.esb.message.text != gCachedESBMsgText || tourney.esb.message.mode != gCachedESBMsgMode) {
      if (tourney.esb.message.text === '') {
	tourney.esb.message.mode = 'reveal';
        }
      gCachedESBMsgText = tourney.esb.message.text;
      gCachedESBMsgMode = tourney.esb.message.mode;
      this.message.Go(tourney.esb.message.mode, tourney.esb.message.text);
      }
    error('processing new data');
    gTerms = SetupTerminology(tourney.config);
    }

  if (this.children) {
    if (is_update) { // propagate
      this.children[0].UpdatePositions(true);
      this.children[1].UpdatePositions(true);
      }
    return;
    }

  // else we are a leaf node and need to figure out our content
  this.UpdateContent(is_update);

  return true;
  }

function TagName(sb, p, optionsp) {
  if (!optionsp) optionsp = {};
  var name = PlayerScoreboardName(p);
  var is_chinese = PlayerTeam(p).match(/^(?:HKG|MYS|SGP|TWN)$/) && name.match(/ .* /);
  var is_thai = p.xthai;
  var container = optionsp.container || 'div';
  var subcontainer = optionsp.subcontainer || 'span';
  var rv;
  if (!defined(is_thai)) {
    if (name.match(/Charnwit$/))
      is_thai = 1;
    else if (PlayerTeam(p) == 'THA') {
      rv = name.match(/^(.*), (.*)$/);
      if (rv && rv.length == 3) {
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
    var after_id = '';
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
    if ((sb.style != 'compact') && rv) {
      var surname1 = rv[1];
      var surname2 = rv[2];
      if (surname2.length < surname1.length + given.length) {
	given = given+' '+surname1 + "-";
	surname = surname2;
	}
      }
    if (optionsp.show_id) {
      var classn = sb.has_classes ? '/' + PlayerClass(p) : '';
      var idclass = p.id + classn;
      var dname = TournamentCountDivisions(sb.tourney) > 1 ? sb.dname : '#';
      if (optionsp.show_id == 'at-end' || sb.style == 'compact') {
	after_id = '<' + subcontainer + ' class=end_id>(#' + idclass + ')</' + subcontainer + '>';
	}
      else if (surname.length > given.length) {
	given += " (" + dname + idclass + ")";
	}
      else {
	surname += " (" + dname + idclass + ")";
	}
      }
    name = '';
    if (container != 'none') name += "<" + container + " class=name>";
    name += "<" + subcontainer + " class=given>" + given + "</" + subcontainer + ">"
      + "<" + subcontainer + " class=surname>" + surname + "</" + subcontainer + ">"
      + after_id;
    if (container != 'none') name += "</" + container + ">";
    }
  else { // school scrabble tagging
    var names = name.split(/\s+/);
    var split = 0;
    var half = names.join(' ').length/2;
    for (var i = 0; i < names.length; i++) {
      if (names.slice(0,i+1).join(' ').length > half) {
	if (Math.abs(names.slice(0,i+1).join(' ').length-half) > 
	  Math.abs(names.slice(0,i).join(' ').length-half)) {
	  split = i;
	  }
	else {
	  split = i+1;
	  }
	break;
        }
      }
    if (optionsp.show_id) {
      var classn = sb.has_classes ? '/' + PlayerClass(p) : '';
      var idclass = p.id + classn;
      var dname = TournamentCountDivisions(sb.tourney) > 1 ? sb.dname : '#';
      if (optionsp.show_id == 'at-end' || sb.style == 'compact') {
	after_id = '<' + subcontainer + ' class=end_id>(#' + idclass + ')</' + subcontainer + '>';
	}
      else {
	names.push(" (" + dname + idclass + ")");
        }
      }
    if (names.length> 1 && split == 0) { split = 1; }
    if (name.length <= 12) { split = 0; }
    name = "<" + container + " class=name><span class=given>"
      + names.slice(0,split).join(' ')
      + "</span><span class=surname>"
      + names.slice(split).join(' ')
      + "</span></" + container + ">";
    }
  return name;
  }

// to be called every 0.05 s
ScoreBoard.prototype.Tick = function () {
//console.log(this.id,"Tick()", (new Date()).getTime()/1000);
  // if we are the root node and our timer has expired, reload data from the server
  if ((!this['parent']) && this.reload_rate) {
    // reload scoreboard every this.reload_rate ticks, 
    // keeping track of phase in this.reload_count
    this.reload_count++;
//  error(this.reload_count);
    if (0 == this.reload_count % 20) { error((this.reload_rate-this.reload_count)/20+'...'); }
    if (this.reload_count >= this.reload_rate) {
      this.reload_count = 0;
      this.Synch(true, false);
      }
    }
  // if we have scoreboard children, propagate to them and we're done
  if (this.children) {
    this.children[0].Tick(); 
    this.children[1].Tick(); 
    return;
    }
  // else we are a leaf node
  // propagate tick to players, set active if any report a change
  var active = 0;
  for (var i=0; i<this.ps.length; i++) {
    if (this.ps[i].Tick()) active = 1;
    }
  // if players have finished any resize-induced movements and are inactive
  // and the scoreboard is in scroll mode, scroll all the players down 1 rank
  if ((!active) && this.scroll_rate) {
    if (this.scroll_count++ >= 200 / this.scroll_rate) {
      this.scroll_count = 0;
      var columns;
      if (this.style == 'compact') { columns = 1; }
      else { columns = this.columns; }
      // if we have reached the end of bottom of the list, start over at top
      if (this.offset + this.rows * columns >= this.ps.length) {
	this.offset = 0;
        this.AdjustOffset(0);
        }
      // else scroll down one rank
      else {
        this.AdjustOffset(1);
        }
      }
    }
  // if in blink mode
  if (this.blink_rate) {
    // see if it is time to alternate presentation
    this.TickBlink();
    }
  }

// scoreboard class blinks alt0 and alt1 each period
ScoreBoard.prototype.TickBlink = function() {
  this.blink_count++;
  if (this.blink_count >= this.blink_rate) {
    this.blink_count = 0;
    var ref = document.DOMReference();
    if (!ref) { error('Cannot find element "'+this.id+'".'); return; }
    this.blink_state = 1 - this.blink_state;
    ref.className = 'alt' + (this.child_share ? 'p' : this.blink_state);
//  error("changed state to "+ref.className);
    }
  }

// Update scoreboard content
// - is_update should be false the first time object is updated to generate
//   player objects, then true thereafter to move them around without freeing
//   and reallocating them
ScoreBoard.prototype.UpdateContent = function(is_update) {
  var tourney = this.tourney;
  var dp = TournamentGetDivisionByName(tourney, this.dname);
  this.dp = dp;
  if (!dp) { alert('Cannot find division "'+this.dname+'".'); return; }
  DivisionSynch(dp, tourney);
  this.real_r1 = DivisionMostScores(dp);
  this.AdjustRound(0, true);
  var r0 = this.r0;
  this.has_classes = DivisionClasses(dp);
  this.c_no_boards = (tourney.config.no_boards || '');
  this.is_capped = tourney.config.standings_spread_cap || tourney.config.spread_cap;
  this.thai_points = tourney.config.thai_points;
  this.c_has_tables = DivisionHasTables(dp, tourney.config);

  // ComputeRanks, ComputeRatings, ComputeSeeds are done in saveJSON.pm
  var ps = DivisionPlayers(dp);
  PlayerSpliceInactive(ps, 0, 0);
  switch(this.order) {
    case 'ranked':
      ps = this.is_capped ? PlayerSortByCappedStanding(r0, ps, tourney.config)
	: PlayerSortByStanding(r0, ps, tourney.config);
      break;
    case 'id':
      break;
    case 'board':
      ps.sort(function(a,b){
	return compare(PlayerBoard(a,r0),PlayerBoard(b,r0)) ||
	compare(Math.min(a.id,PlayerOpponentID(a,r0+1)||0),
	  Math.min(b.id,PlayerOpponentID(b,r0+1)||0))
      });
      break;
    }
  // ps contains the player data in rank order
  // this.ps contains the player objects in display order
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
      var out_of_the_money = po + 1 >= dp.first_out_of_the_money[this.r0];
      out_of_the_money = ''; // temporarily disabled 2012-12-28
      this.ps[po].Rerender(po ? ps[po-1] : undefined, out_of_the_money);
      }
//  var t1 =[];for (var i=0;i<ps.length;i++) { t1.push(ps[i].id); }
//  var t2 =[];for (var i=0;i<ps.length;i++) { t2.push(this.ps[i].data.id); }
//  console.log('ps',t1,'this.ps',t2);
    this.UpdatePositions(true);
    }
  else {
    // rebuild all the player objects and store them in this.ps
    this.StorePlayers(ps);
    }
  this.RerenderNote();
  this.pmap = []; // maps player id to SBP structure
  for (var i=0; i<this.ps.length; i++) {
    this.pmap[this.ps[i].data.id] = this.ps[i];
    }
  error(gTerms.data_loaded);
  }

// called to move all objects to their correct locations
ScoreBoard.prototype.UpdatePositions = function(animated) {
//console.log('update');
  if (this.children) {
    this.children[0].UpdatePositions(animated);
    this.children[1].UpdatePositions(animated);
    return;
    }
  if (!defined(this.ps)) return;
  for (var i = 0; i < this.ps.length; i++) {
//  console.log('u',this.ps[i].id);
    this.ps[i].SetPosition(i, animated);
    }
  }

ScoreBoard.prototype.Width = function () { 
  if (this['parent']) {
    return this.DOMReference().offsetWidth;
    }
  else {
    return getWindowWidth();
    }
  };

// TSH::Division

function DivisionClasses (dp, c) {
  var old = dp.classes;
  if (defined(c)) dp.classes = c;
  return old;
  }

// not currently used
//
// function DivisionComputeRanks(dp, sr0) {
//   var sorted = PlayerSortByStanding(sr0, DivisionPlayers(dp), tourney.config)
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

function DivisionMaxRound0(dp,round0) {
  var old = dp.maxr;
  if (defined(round0)) dp.maxr = round0;
  return old;
  }

function DivisionMostScores(dp) {
  return dp.maxs + 1;
  }

// TSH::Utility
