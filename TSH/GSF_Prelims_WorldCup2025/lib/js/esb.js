"use strict";

var TSH_ESB_RCS_Version = "$Revision: 1.69 $";
var TSH_ESB_Version = TSH_ESB_RCS_Version.replace(/^.* ([.\d]+).*/,"$1");

var tourney;

var undefined;

var gCachedESBMsgMode = '';
var gCachedESBMsgText = '';
var gTerms;

var gcControlHeight = 20;

if (isAppleHandheld()) {
  setTimeout(function () { scrollTo(0,1) }, 1);
  }

function getSearchVariables () {
  var i, keyValuePair, keyValuePairs;
  var hash = {};
  if (window.location.search.length === 0) return hash;
  var parseValue = function (s) {
    if (/^\s*$/.test(s)) { return null; }
    if (/^(true|false)$/i.test(s)) { return s.toLowerCase() === "true"; }
    if (isFinite(s)) { return parseFloat(s); }
    return s;
    };
  keyValuePairs = window.location.search.substr(1).split("&");
  for (i=0; i < keyValuePairs.length; i++) {
    keyValuePair = keyValuePairs[i].split("=");
    hash[unescape(keyValuePair[0])] =
      keyValuePair.length > 1 ? parseValue(unescape(keyValuePair[1])) : null;
    }
  return hash;
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
    // TODO: on resize recalculate max_x, max_y
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
  if ((this.x+this.xoffset > this.max_x)) { this.xoffset = -1; }
  else if (this.x+this.xoffset < 0) { this.xoffset = 1; }
  if ((this.y+this.yoffset > this.max_y)) { this.yoffset = -1; }
  else if (this.y+this.yoffset < 0) { this.yoffset = 1; }
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

// Render a head shot given a player's data object and some options
ScoreBoard.prototype.HeadShot = function(p, optionsp) {
  var id = optionsp.id;
  var tourney = this.tourney;
  var config = tourney.config;
  var container = optionsp.container || 'div';
  var photoURL;
  if (config.player_photos && this.SettingsGet('photo')) {
    if (config.player_moods && p.etc.photomood) {
      photoURL = ScoreBoardPlayer.MoodPhotoURL(p, this.r1-1);
      }
    else {
      photoURL = p.photo;
      }
    if (!photoURL) photoURL = 'no-such-url.gif';
    else if (photoURL.match(/^pix\//)) {
      photoURL = this.SettingsGet('root') + '/' + photoURL;
      }
    var s = '';
    if (container != 'none') s += '<' + container + ' class=head>';
    s += '<img class="head'+
      (config.player_moods ? ' mood' + Math.floor(p.etc.rmood[this.r1-1]/10) : '') +
      '"' +
      ' src="' +
      photoURL +
      '" alt="[head shot]" id="' +
      id +
      '">';
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
//  return "&nbsp;";
    return ''; // 2016-05-14
    }
  }

// return a JavaScript expression that evaluates to this
ScoreBoardPlayer.prototype.JSName = function () { return "the_sbs['"+this.id+"']"; }

// the things that want to call this use don't have an SBP, just a SBP.data
ScoreBoardPlayer.MoodPhotoURL = function (data,r0) { 
  return data.etc.photomood[Math.floor(
    (data.etc.rmood[r0]-.1)*data.etc.photomood.length/100)];
  };

ScoreBoardPlayer.prototype.Render = function(lastp, outofthemoney, withcontainer) {
  var style = this.sb.SettingsGet('style');
  if (!style) { console.log('no value for style'); return; }
  var sinfo = ScoreBoard.cStyleInfo[this.sb.SettingsGet('style')];
  if (!sinfo) { console.log('no info for style '+style); return; }
  var fname = sinfo.renderer;
  if (!fname) { console.log('no renderer for style '+style); return; }
  return this[fname](lastp, outofthemoney, withcontainer);
  }

ScoreBoardPlayer.prototype.RenderCard = function(lastp, outofthemoney, withcontainer) {
  var ms, oid, opp, os, r0, row, value;
  var html = '';
  var p = this.data;
  var sb = this.sb;
  var dp = sb.dp;
  var rows = [];
  var config = sb.tourney.config;
  var columns = 6;
  var has_board_or_p12 = config.track_firsts || sb.c_has_tables || !config.no_boards;
  var has_board_and_p12 = config.track_firsts && (sb.c_has_tables || !config.no_boards);
  if (has_board_or_p12) columns++;
  var c_linked = (!!sb.SettingsGet('dispatcher')) || !!sb.SettingsGet('selflink');

  if (withcontainer) {
    this.visible = false;
    html += '<div id="'+this.id+'" class="sbp card" style="position:absolute;left:0;top:0;display:none" ondragover="return '+this.JSName()+'.DragOver(event)" ondrop="return '+this.JSName()+'.Drop(event)">';
    }
  else {
    // support for scrolling children of draggable elements poor
//  console.log('TODO: should adjust overflow?');
    }

  html += '<table class=scorecard>';
  html += '<thead><tr><th class=top colspan='+columns+'>'+sb.FormatPlayerPhotoName(p,{'id':this.id+'me','show_id':1}) + '</th></tr>';
  html += '<tr class=headings><th class=round>'+gTerms.Rnd+'</th>';
  if (has_board_or_p12) { 
    html += '<th class="bp12';
    if (has_board_and_p12) html += ' both';
    html += '">';
    if (sb.c_has_tables) html += '<div class=table>' + gTerms.Table+ '</div>';
    else if (!config.no_boards) html += '<div class=board>' + gTerms.Board+ '</div>';
    if (config.track_firsts) html += '<div class=p12>' + gTerms.p12+ '</div>';
    html += '</th>';
    }
  html += '<th class=opponent>'+gTerms.Opponent+'</th>' +
    '<th class=score>'+gTerms.Score+'</th>' +
    '<th class=spread>'+gTerms.Spread+'</th>' +
    '<th class=wl>'+gTerms.W_L+'</th>' +
    '<th class=rank>'+gTerms.Rank+'</th>' +
    '</tr></thead><tbody>';
  for (r0=0; ;r0++) {
    var oid = PlayerOpponentID(p, r0);
    if (!defined(oid)) break;
    row = '<tr><td class=round><div class=round>'+(r0+1)+'<div></td>';
    if (has_board_or_p12) {
      row += '<td class="bp12';
      if (has_board_and_p12) row += ' both';
      row += '">';
      if (config.track_firsts) {
	value = PlayerFirst(p, r0);
	value = value == 1 ? gTerms['1st'] : value == 2 ? gTerms['2nd'] : '';
	row += '<div class=p12>' + value + '</div>';
	}
      if (sb.c_has_tables) row += '<div class=table>' + sb.RenderBoard(p, r0, {'style':'at'}) + '</div>';
      else if (!config.no_boards) row += '<div class=board>' + sb.RenderBoard(p, r0, {'style':'at'}) + '</div>';
      row += '</td>';
      }
    if (oid) {
      opp = PlayerOpponent(p,r0,dp);
      row += '<td class=opponent>'+sb.FormatPlayerPhotoName(opp,{'id':this.id+'o'+r0,'show_id':1,'linked':c_linked}) + '</td>';
      ms = PlayerScore(p,r0);
      if (defined(ms)) {
	os = PlayerScore(opp,r0) || 0;
	row += '<td class=score>' + ms + '&ndash;'+ os +'</td>';
	value = ms - os;
	row += '<td class=spread><div class=roundSpread>'+UtilityFormatHTMLSignedInteger(value)+'</div><div class=cume>='+
	  UtilityFormatHTMLSignedInteger((sb.is_capped?
	    PlayerRoundCappedSpread:PlayerRoundSpread)(p, r0))+'</div></td>';
	row += '<td class="wl '+(value>0?'W':value<0?'L':'T')+'">'+UtilityFormatHTMLHalfInteger(PlayerRoundWins(p,r0))+'&ndash;'+UtilityFormatHTMLHalfInteger(PlayerRoundLosses(p,r0))+'</td>';
	row += '<td class=rank>'+(sb.is_capped?PlayerRoundCappedRank:PlayerRoundRank)(p,r0)+'</td>';
        }
      else {
	row += '<td class=score>&nbsp;</td>'+
	  '<td class=spread>&nbsp;</td>'+
	  '<td class=wl>&nbsp;</td>'+
	  '<td class=rank>&nbsp;</td>'
	  ;
        }
      }
    else {
      if (config.track_firsts) row += '<td class=p12>&nbsp;</td>';
      row += '<td class=opponent>'+gTerms.bye+'</td>';
      value = UtilityFormatHTMLSignedInteger(PlayerScore(p, r0));
	row += '<td class=score>'+value+'</td>';
      row += '<td class=spread><div class=roundSpread>'+value+'</div><div class=cume>'+
	UtilityFormatHTMLSignedInteger((sb.is_capped?
	  PlayerRoundCappedSpread:PlayerRoundSpread)(p, r0))+'</div></td>';
      row += '<td class="wl B">'+UtilityFormatHTMLHalfInteger(PlayerRoundWins(p,r0))+'&ndash;'+UtilityFormatHTMLHalfInteger(PlayerRoundLosses(p,r0))+'</td>';
      row += '<td class=rank>'+(sb.is_capped?PlayerRoundCappedRank:PlayerRoundRank)(p,r0)+'</td>';
      }
    row += '</tr>';
    rows.unshift(row);
    }
  html += rows.join('');
  html += '</tbody></table>';
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
    var classn = PlayerClass(p);
    var classn_class = ' class_' + classn.replace(/[^a-z0-9]/gi, '');
//  console.log(classn_class);
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
    if (withcontainer) html += '<div id="'+this.id+'" class="sbp compact'+is_in_money+is_out_of_money+classn_class+'" style="position:absolute;left:0;top:0;display:none">';
    html += "<div class=rank>"
      + ConfigOrdinalTerm(config,crank)
      + "</div>";
    if (sb.thai_points) html += "<div class=\"handicap\"><span class=label>HP</span><span class=value>" + (2*wins+((p.etc.handicap && p.etc.handicap[0])||0)) + "</span></div>\n";
    var currency_symbol = config.currency_symbol || '$';
    if (config.rating_system.match(/^(snic|sudoku)/)) {
      html += '<div class=wl>' + spread + '</div>';
      }
    else html += sb.RenderPlayerWinLossSpread(p, r0); 
  }
//if (!config.rating_system.match(/^(none|glixo|sudoku)/)) { 
  if (!config.rating_system.match(/^(none|snic|sudoku)/)) { 
    var oldr = (p.rating+"").replace(/\+.*/,'');
    var newr = (PlayerNewRating(p, r0)+"").replace(/\+.*/,'');
    html += "<div class=rating>";
    if (oldr) {
      html += oldr+"&rarr;";
      }
    html += newr+"</div>\n";
  }
  {
    /*
    var optionsp = {'id':this.id+'_mi','show_id':'at-end','container':'div'};
    html += this.HeadShot(optionsp);
    html += sb.TagName(p, optionsp);
    */
    var optionsp = {'id':this.id+'_mi','show_id':'at-end','container':'none'};
    if (config.rating_system.match(/^(snic)/)) {
      html += this.RenderLastOpponents();
      html += '<div class=class>' + PlayerClass(p) + '</div>';
      }
    html += '<div class=name>';
    html += sb.HeadShot(p, optionsp);
    optionsp.container = 'none';
    optionsp.subcontainer = 'div';
    html += sb.TagName(p, optionsp);
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
//    var opp = sb.pmap[op.id];
      var first = PlayerFirst(p,r0+1);
      var repeats = PlayerCountRoundRepeats(p,op, r0+1);
      var board = sb.RenderBoard(p,r0+1);
      first = first == 1 ? gTerms['1st'] : first == 2 ? gTerms['2nd'] : '';
      next += "<div class=where>"+first+board+"</div>\n";
/*
      var optionsp = {'id':this.id+'_ni','show_id':'at-end','container':'div'};
      next += opp.HeadShot(optionsp);
      next += opp.sb.TagName(opp.data, optionsp);
*/
      var optionsp = {'id':this.id+'_ni','show_id':'at-end','container':'none'};
      next += '<div class=name>';
      next += sb.HeadShot(op,optionsp);
      optionsp.container = 'none';
      optionsp.subcontainer = 'div';
      next += sb.TagName(op, optionsp);
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
  if (config.rating_system.match(/^(snic|sudoku)/)) return this.RenderLastOpponents();
  var dp = sb.dp;
  var r0 = sb.r0;
  var ms, os;
  var last = '';
  var oppid = PlayerOpponentID(p, r0);
  if (oppid) {
    var op = PlayerOpponent(p, r0, dp);
    var opp = sb.pmap[op.id];
//    if (!opp) { console.log('cannot find '+op.id+' in pmap'); }
    // not if (opp), which results in inactive players showing up scoreless
    if (op) { os = PlayerScore(op, r0); }
    else { } // corrupt data, or inactive opponent
    if (defined(os)) {
      ms = PlayerScore(p, r0);
      if (config.no_scores) {
	last += ms > os ? gTerms.W : ms == os ? gTerms.T : gTerms.L;
	}
      else {
	var spread = UtilityFormatHTMLSignedInteger(ms - os);
	last += "<div class=gs>"+ms+"&ndash;"+os+"="+spread+"</div>";
	}
      }
    else { last += "<div class=gsn>no score yet</div>"; }
    var first = PlayerFirst(p, r0);
    first = first == 1 ? gTerms['1st'] : first == 2 ? gTerms['2nd'] : '';
    var board = sb.RenderBoard(p, r0);
    if (! this.sb.tourney.config.esb_lite) {
      last += "<div class=where>"+first+board+" "+gTerms.vs+"</div>\n";
      last += "<div class=hs>" 
        + sb.FormatPlayerPhotoName(op,{'id':this.id+'_li'}) 
        + "</div>";
    }
    else {
      last += "<div class=where>"+board+" "+gTerms.vs+"</div>\n";
      last +="<div class=hs>" + sb.TagName(op,{'id':this.id+'_li'}) + "</div>";
      }
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
  if (!config.rating_system.match(/^(snic|sudoku)/))  return undefined;
  var dp = sb.dp;
  var r0 = sb.r0;
  var ms;
  var last = '';
  var ri0;
  for (ri0=0; ri0<=r0; ri0++) {
    ms = PlayerScore(p, ri0);
    if (config.rating_system.match(/^(snic)$/)) {
      if (0) { ms *= 100; ms = (ms+"").replace(/..$/, '.$&'); }
      else { ms = Math.round(ms*1); }
      }
    if (defined(ms)) last += ' <div class=score>' + ms + '</div>';
    else last += ' <div class=noscore>-</div>';
    }
  return last;
  }

ScoreBoardPlayer.prototype.RenderNextOpponent = function () {
  var p = this.data;
  var sb = this.sb;
  var config = sb.tourney.config;
  if (config.rating_system.match(/^(snic|sudoku)/)) { return undefined; }
  var dp = sb.dp;
  var r0 = sb.r0;
  var next = '';
  var oppid = PlayerOpponentID(p,r0+1);
  if (oppid) {
    var op = PlayerOpponent(p,r0+1, dp);
//  var opp = sb.pmap[op.id];
    var first = PlayerFirst(this.data,r0+1);
    var repeats = PlayerCountRoundRepeats(p,op,r0+1);
    var board = sb.RenderBoard(p,r0+1);
    first = first == 1 ? gTerms['1st'] : first == 2 ? gTerms['2nd'] : '';
    if (repeats > 1) {
      next += "<div class=repeats>"+ConfigRepeatTerm(config, repeats)+"</div>";
      }
    next += "<div class=where>"+first+board+" "+gTerms.vs+"</div>\n";
    next += "<div class=hs>" 
      + sb.FormatPlayerPhotoName(op,{'id':this.id+'_ni','show_id':'at-end'})
      + "</div>";
    }
  else if (defined(oppid)) {
    next += "<div class=bye>"+gTerms.bye+"</div>";
    }
  return next;
  }

ScoreBoardPlayer.prototype.RenderNonCompact = function(lastp, outofthemoney, withcontainer) {
  var crank, lastw, lrank, spread, wins;
  var p = this.data;
  var sb = this.sb;
  if (withcontainer) this.visible = false;
  var dp = sb.dp;
  var r0 = sb.r0;
  var r1 = sb.r1;
  var seed = dp.seeds[p.id-1];
  var html = '';
  var config = sb.tourney.config;
  var is_block_leader = '';
  var is_in_money = '';
  var is_out_of_money = '';
  var team_class = '';
  var wins = PlayerRoundWins(p, r0);

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

  if (config.scoreboard_team_colours || config.scoreboard_team_colors) 
    { team_class = ' team_' + (PlayerTeam(p)||'none'); }
  else {
    is_in_money = InTheMoney(sb, p) ? ' money' : '';
//  is_out_of_money = outofthemoney ? ' nomoney' : ''; // temporarily disabled 2012-12-28
    if (sb.first_rank == 1 && !defined(lastp)) {
//    html += '<div class="wlb'+is_in_money+is_out_of_money+'"><div class=w>P<br>R<br>I<br>Z<br>E</div></div>';
//    is_block_leader = " leader";
      }
    else if (!is_in_money) {
      lastw = defined(lastp) ? PlayerRoundWins(lastp, r0) : -1;
      if (lastw != wins || InTheMoney(sb, lastp)) {
//	html += '<div class="wlb'+is_in_money+is_out_of_money+'"><div class=w>' + UtilityFormatHTMLHalfInteger(wins).replace(/(\d|&frac12;)/g, '$&<br>').replace(/<br>$/,'') + '</div></div>';
//	is_block_leader = " leader";
	}
      }
    }

  if (withcontainer) html += '<div id="'+this.id+'" class="sbp'+is_in_money+is_out_of_money+is_block_leader+team_class+'" style="position:absolute;left:0;top:0;display:none" ondragover="return '+this.JSName()+'.DragOver(event)" ondrop="return '+this.JSName()+'.Drop(event)">';
  html += '<table class=metable cellspacing=0 cellpadding=0 style="font-size:inherit"><tr><td><div class=me>';
  html += "<div class=rank>" + ConfigOrdinalTerm(config,crank) + "</div>";
  if (defined(PlayerScore(p, r0))) html += "<div class=old>"+gTerms.was+"<br>" + ConfigOrdinalTerm(config,lrank) + "</div>\n";
  if (sb.thai_points) html += "<div class=\"handicap\"><span class=label>HP</span><br><span class=value>" + (2*wins+((p.etc.handicap && p.etc.handicap[0])||0)) + "</span></div>\n";
  var currency_symbol = config.currency_symbol || '$';
  if (is_in_money) html += "<div class=money>"+currency_symbol+"</div>";
  if (config.rating_system.match(/^(snic|sudoku)/)) 
    { html += '<div class=wl>' + spread + '</div>'; }
  else html += sb.RenderPlayerWinLossSpread(p,r0);

  html += sb.FormatPlayerPhotoName(p,{'id':this.id+'_mi','show_id':1});
//if (!config.rating_system.match(/^(none|glixo|sudoku)/)) { 
  if (!config.rating_system.match(/^(none|snic|sudoku)/)) { 
    var oldr = (p.rating+"").replace(/\+.*/,'');
    var newr = (PlayerNewRating(p, r0)+"").replace(/\+.*/,'');
    var delta = newr-oldr;
    if (config.rating_system.match(/(glixo|nor)/)) 
      { delta = Math.round(delta*100)/100; }
    delta = UtilityFormatHTMLSignedInteger(delta);
    html += "<div class=newr>"+newr+"</div>\n";
    if (oldr) { html += "<div class=oldr>="+oldr+"<br>"+delta+"</div>\n"; }
    else      { html += "<div class=oldr>"+gTerms.was+"<br>unrated</div>\n"; }
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
  if (!config.rating_system.match(/^(snic|sudoku)/)) { // record
    var record = '';
    var nrounds = PlayerCountScores(p);
    if (! this.sb.tourney.config.esb_lite) {
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

ScoreBoardPlayer.prototype.RenderPair = function(lastp, outofthemoney, withcontainer) {
  var html = '';
  var p = this.data;
  var sb = this.sb;
  var dp = sb.dp;
  var r0 = sb.r0;
  var r1 = sb.r1;
  var config = sb.tourney.config;
  var opp;

  if (withcontainer) this.visible = false;

  // If the round has no data, display using normal non-compact style
  if (r1 == 0) 
    { return this.RenderNonCompact(lastp, outofthemoney, withcontainer); }

  if (withcontainer) html += '<div id="'+this.id+'" class="sbp pair" style="position:absolute;left:0;top:0;display:none" ondragover="return '+this.JSName()+'.DragOver(event)" ondrop="return '+this.JSName()+'.Drop(event)">';
  html += '<table class=pairing>';
  opp = PlayerOpponent(p, r0, dp);
  if (opp) { 
    html += '<tr><td colspan=2 class=heading>' + gTerms.Round + ' ' + r1 + ' ' +  sb.RenderBoard(p,r0,{'style':'verbose'}) + '</td></tr>';
    html += '<tr>'+this.RenderPairPlayer(p,this.id+'_p1') + this.RenderPairPlayer(opp,this.id+'_p2') + '</tr>';
    }
  else {
    html += '<tr><td class=heading>' + gTerms.Round + ' ' + r1 + '</td></tr>';
    html += '<tr>'+this.RenderPairPlayer(p,this.id+'_p1','bye') +'</tr>';
    }
  html += '</table>';
  if (withcontainer) html += '</div>'; // sbp
  return html;
  }

ScoreBoardPlayer.prototype.RenderPairPlayer = function(p,id,bye) {
  var html = '<td class=player>';
  var sb = this.sb;
  var r0 = sb.r0;
  var first = PlayerFirst(p,r0);
  if (bye) {
    html += '<div class=bye>' + gTerms.bye + '</div>';
    }
  else if (this.sb.tourney.config.track_firsts) {
    html += '<div class=first>' + 
      (first == 1 ? gTerms['1st'] : first = 2 ? gTerms['2nd'] : gTerms.draw) +
      '</div>';
    }
  if (! this.sb.tourney.config.suppress_results_in_pairings) {
    html += sb.RenderPlayerWinLossSpread(p, r0);
  }
  html += sb.FormatPlayerPhotoName(p,{'id':id,'show_id':1});
  if (! this.sb.tourney.config.suppress_results_in_pairings && r0 > 0) {
    html += '<div class=last><span class=label>'+
      gTerms.Last_Game_sb + '</span><span class=board>' +
      sb.RenderBoard(p, r0-1, {'style':'at'}) +
      '</span></div>';
    }
  html += '</td>';
  return html;
  }

ScoreBoardPlayer.prototype.RenderRoundRecord = function (r0) {
  var record = ''; 
  var dp = this.sb.dp;
  var config = this.sb.tourney.config;
  var ms, os;

  ms = this.data.scores[r0];
  record += "<div class=rd>";
  if (this.data.pairings[r0]) {
    var os = dp.players[this.data.pairings[r0]].scores[r0];
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
    else { record += "<div class=p0>&ndash;</div>"; }
    }
  record += "</div>";
  return record;
  }

ScoreBoard.prototype.RenderPlayerWinLossSpread = function (p, r0) {
  var spread;
  var config = this.tourney.config;
  if (this.is_capped) { spread = PlayerRoundCappedSpread(p, r0); }
  else { spread = PlayerRoundSpread(p, r0); }
  return "<div class=wl>" +
    UtilityFormatHTMLHalfInteger(PlayerRoundWins(p, r0)) +
    "&ndash;" +
    UtilityFormatHTMLHalfInteger(PlayerRoundLosses(p, r0)) +
    (config.no_scores ?  '' : ' ' + UtilityFormatHTMLSignedInteger(spread)) +
    "</div>";
  };

ScoreBoardPlayer.prototype.Rerender = function (lastp, outofthemoney, quiet) {
//console.log('SBP.Rerender('+lastp+','+outofthemoney+','+quiet+')');
  var ref = document.getElementById(this.id);
  var sb = this.sb;
  var style = sb.SettingsGet('style');
  if (!ref) { 
    if (!quiet) console.log("SBP.Rerender(): Can't get DOM object for "+this.id);
    return; 
    }
  ref.innerHTML = this.Render(lastp, outofthemoney, false);
  if (InTheMoney(sb, this.data)) ref.className = 'sbp money';
  else if (outofthemoney) ref.className = 'sbp nomoney';
  else ref.className = 'sbp';
  var p = this.data;
  var classn = PlayerClass(p);
  var classn_class = ' class_' + classn.replace(/[^a-z0-9]/gi, '');
  ref.className += ' ' + style + classn_class;
//if (this.sb.tourney.config.player_moods) { this.RerenderMood(); }
  this.Resize();
  };

// ScoreBoardPlayer.prototype.RerenderMood = function () {
//   if (!this.data.etc.photomood) return;
//   var photoURL = ScoreBoardPlayer.MoodPhotoURL(this.data, this.sb.r1-1);
//   console.log(photoURL);
//   };

ScoreBoardPlayer.prototype.Resize = function () {
  var aspect = this.sb.tourney.config.player_photo_aspect_ratio || 1;
  var ref = document.getElementById(this.id);
  if (!ref) {
    return;
    }
  ref.style.height = this.sb.cell_height + 'px';
  ref.style.width = this.sb.cell_width + 'px';
  switch(this.sb.SettingsGet('style')) {
    case 'compact':
      this.SetPhotoSize('_mi',   this.sb.photo_size, aspect * this.sb.photo_size  );
      this.SetPhotoSize('_mi_f', this.sb.photo_size, this.sb.photo_size);
      this.SetPhotoSize('_li',   this.sb.photo_size, aspect * this.sb.photo_size);
      this.SetPhotoSize('_li_f', this.sb.photo_size, undefined);
      this.SetPhotoSize('_ni',   this.sb.photo_size, aspect * this.sb.photo_size);
      this.SetPhotoSize('_ni_f', this.sb.photo_size, this.sb.photo_size);
      break;
    case 'pair':
      this.SetPhotoSize('_p1',   this.sb.photo_size  , aspect * this.sb.photo_size  );
      this.SetPhotoSize('_p1_f', this.sb.photo_size/3, undefined);
      this.SetPhotoSize('_p2',   this.sb.photo_size  , aspect * this.sb.photo_size  );
      this.SetPhotoSize('_p2_f', this.sb.photo_size/3, undefined);
      break;
    default:
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
  var pi = po - sb.SettingsGet('offset');
  var columns = sb.SettingsGet('style') === 'compact' ? 1 : sb.SettingsGet('columns');
  if (
    pi < 0 || 
    pi >= sb.SettingsGet('rows') * columns ||
    (sb.SettingsGet('order') == 'board' && sb.IsSecondaryPlayer(this.data))) {
    this.SetVisible(false);
    return;
    }
  var i = pi % columns;
  var j = Math.floor(pi/columns);
  var ref = document.getElementById(this.id);
  if (animated) {
    this.target_x = i * sb.cell_hspacing;
    this.target_y = j * sb.cell_vspacing + gcControlHeight;
//  if (sb.banner_height) this.target_y += sb.banner_height+5;
//  console.log(po,pi,this.target_x,this.target_y,this.visible);
    }
  else {
    this.current_x = i * sb.cell_hspacing;
    this.current_y = j * sb.cell_vspacing + gcControlHeight;
    this.delta_x = 0;
    this.delta_y = 0;
    }
  if (ref) {
    ref.style.left = this.current_x + 'px';
    ref.style.top = this.current_y + 'px';
//console.log('SBP.SetPosition', this.id, ref.style.left, ref.style.top);
    this.SetVisible(true);
    }
  }

ScoreBoardPlayer.prototype.SetTarget = function (x, y) {
  this.target_x = x;
  this.target_y = y;
  }

ScoreBoardPlayer.prototype.SetVisible = function (bool) {
//if (bool == this.visible) return; // you'd think, but no - sometimes out of synch
  var ref = document.getElementById(this.id);
  if (!ref) return;
  if (this.visible && bool && ref.style.display == 'block') return;
  if ((!this.visible) && (!bool) && ref.style.display == 'none') return;
  this.visible = bool;
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

// Class ScoreBoardSetting - a user-configurable setting value for a ScoreBoard

function ScoreBoardSetting (argh) {
  if (!argh) { return; }
  this.initialise(argh);
  };

// should be overridden to provide a default value for setting
ScoreBoardSetting.prototype.DefaultValue = function () {
  return undefined; };

ScoreBoardSetting.prototype.initialise = function (argh) {
  var newValue, value;
  if (!defined(argh.key)) { debugger; return; } else this.key = argh.key;
  if (!defined(argh.sb))  { debugger; return; } else this.sb  = argh.sb;
  // Initialisation values in decreasing priority:
  initialise: {
    // 1. called argument value
    if (defined(argh.value)&&argh.value!==null) 
      { newValue = argh.value; break initialise; }
    // 2. parent pane value
    if (this.sb.Parent()) {
      value = this.sb.Parent().SettingsGet(this.key);
      if (defined(value)) { newValue = value; break initialise; }
      }
    // 3. default value for this setting
    newValue = this.DefaultValue();
    }
  this.Set(newValue);
  };

ScoreBoardSetting.prototype.Adjust = function (adjustor) {
  return this.Set(adjustor(this.Get())); };

ScoreBoardSetting.prototype.Get = function () {
  return this.value; };

ScoreBoardSetting.prototype.Increment = function (delta) {
  return this.Adjust(function(x){return x+delta}); };

ScoreBoardSetting.prototype.Normalise = function (value) { return value; };

ScoreBoardSetting.prototype.RenderControl = function (value) { return ''; };

ScoreBoardSetting.prototype.Set = function (newValue) {
  var oldValue = this.value;
  this.SetNoUpdateScoreBoard(newValue);
  if (this.sb.tourney && oldValue != this.value) {
    this.UpdateScoreBoard(oldValue, this.value);
    }
  return this.value;
  };

ScoreBoardSetting.prototype.SetNoUpdateScoreBoard = function (newValue) {
  this.value = this.Normalise(newValue);
  this.UpdateControl();
  return this.value;
  };

ScoreBoardSetting.prototype.UpdateControl = function () { };

ScoreBoardSetting.prototype.UpdateScoreBoard = function (oldValue, newValue) { };

// Class ScoreBoardSettingPersistent - persistent setting value using localStorage

function ScoreBoardSettingPersistent (argh) {
  if (!argh) { return; }
  this.initialise(argh);
  }

ScoreBoardSettingPersistent.prototype = new ScoreBoardSetting();

// if no called value or parent pane value available, try localStorage
ScoreBoardSettingPersistent.prototype.DefaultValue = function () {
  var value;
  if (window.localStorage) {
    value = JSON.parse(
      localStorage.getItem('tsh_esb_settings_'+this.sb.id+'_'+this.key));
    if (defined(value) && value !== null && value !== NaN) { return value; }
    }
  return this.DefaultStaticValue();
  }

ScoreBoardSettingPersistent.prototype.DefaultStaticValue = function () {
  console.log(this,'has no default value!');
  return undefined;
  }

ScoreBoardSettingPersistent.prototype.Set = function (newValue) {
  ScoreBoardSetting.prototype.Set.call(this,newValue); // class inheritance
  if (window.localStorage) {
    localStorage.setItem('tsh_esb_settings_'+this.sb.id+'_'+this.key,
      JSON.stringify(newValue));
    }
  }

// Class ScoreBoardSettingColumns - setting for # of columns in grid

function ScoreBoardSettingColumns (argh) {
  if (!argh) { return; }
  argh.key = 'columns';
  this.initialise(argh);
  }

ScoreBoardSettingColumns.prototype = new ScoreBoardSettingPersistent();

ScoreBoardSettingColumns.prototype.DefaultStaticValue = function () { 
  return 5; };

ScoreBoardSettingColumns.prototype.Normalise = function (value) { 
  return ClipToRange(value, 1, undefined, this.DefaultStaticValue()); };

ScoreBoardSettingColumns.prototype.RenderControl = function() {
  var sb = this.sb;
  var myname = sb.JSName();
  return '<tr><th>'+gTerms.columns+'</th><td><button onclick="'+myname+'.SettingsIncrement(\'columns\',-1);return false" id='+sb.id+'_sbctl_minus_columns'+(this.value<=1?' disabled':'')+'>&ndash;</button><button class=output id='+sb.id+'_sbctl_columns>'+this.value+'</button><button onclick="'+myname+'.SettingsIncrement(\'columns\',1);return false" id='+sb.id+'_sbctl_plus_columns>+</button></td></tr>';
  };

ScoreBoardSettingColumns.prototype.RenderOrder = 1;

ScoreBoardSettingColumns.prototype.UpdateControl = function () {
  var sb = this.sb;
  var ref = document.getElementById(sb.id+'_sbctl_columns');
  if (!ref) return;
  ref.innerHTML = this.value;
  ref = document.getElementById(sb.id+'_sbctl_minus_columns');
  if (ref) ref.disabled = this.value > 1 ? false : true;
  };

ScoreBoardSettingColumns.prototype.UpdateScoreBoard = function (oldValue,newValue) {
  this.sb.Resize();
  this.sb.UpdatePositions(true);
  };

// Class ScoreBoardSettingDispatcher - dispatcher URL

function ScoreBoardSettingDispatcher (argh) {
  if (!argh) { return; }
  argh.key = 'dispatcher';
  this.initialise(argh);
  }

// not persistent for now
ScoreBoardSettingDispatcher.prototype = new ScoreBoardSetting();

ScoreBoardSettingDispatcher.prototype.DefaultValue = function () { return null; };

ScoreBoardSettingDispatcher.prototype.RenderOrder = 999;

// Class ScoreBoardSettingDivision - setting for which division to display

function ScoreBoardSettingDivision (argh) {
  if (!argh) { return; }
  argh.key = 'division';
  this.initialise(argh);
  }

ScoreBoardSettingDivision.prototype = new ScoreBoardSettingPersistent();

ScoreBoardSettingDivision.prototype.DefaultStaticValue = function () { 
  return 'A'; };

ScoreBoardSettingDivision.prototype.Normalise = function (value) { 
  if (!defined(this.sb.tourney)) { // too early to tell
    return (value === 'undefined'||(!defined(value))||!value) ? 'A' : value;
    }
  if (TournamentGetDivisionByName(this.sb.tourney, value)) return value;
  return DivisionName(TournamentDivisions(this.sb.tourney)[0]);
  },

ScoreBoardSettingDivision.prototype.RenderControl = function() {
  var dname, html;
  var sb = this.sb;
  var myname = sb.JSName();

  if ((!sb.tourney) || TournamentCountDivisions(sb.tourney) <= 1) return '';
//this.sb.dp = undefined; // 2015-05-07
  html = '<tr><th>' + gTerms.division + '</th><td>';
  for (var di=1; di<=TournamentCountDivisions(sb.tourney); di++) { 
    dname = DivisionName(TournamentDivisions(sb.tourney)[di-1]);
    html += '<button onclick="' + myname + '.SettingsSet(\'division\',\''+dname+'\');return false" class=division id="'+sb.id+'_sbctl_'+dname+'_div"' + (dname == this.value ? ' disabled' : '') + '>' + dname + '</button>';
    }
  html += '</td></tr>';
  return html;
  };

ScoreBoardSettingDivision.prototype.RenderOrder = 3;

ScoreBoardSettingDivision.prototype.UpdateControl = function () {
  var di, dname, dname2, ref;
  var sb = this.sb;
  if (!sb.tourney) return;

  for (var di=1; di<=TournamentCountDivisions(sb.tourney); di++) { 
    dname2 = DivisionName(TournamentDivisions(sb.tourney)[di-1]);
    ref = document.getElementById(sb.id+'_sbctl_'+dname2+'_div');
    if (ref) ref.disabled = dname2 == this.value ? true : false;
    }
  };

ScoreBoardSettingDivision.prototype.UpdateScoreBoard = function (oldValue,newValue) {
  this.sb.Synch(false, false); // build player data structures
  this.sb.Render(); // build player DOM objects
  this.sb.Resize(); // size objects correctly
  this.sb.UpdateControls();
  this.sb.UpdatePositions(true); // position objects correctly
  };

// Class ScoreBoardSettingFont - percentage font size used in scoreboard

function ScoreBoardSettingFont (argh) {
  if (!argh) return;
  argh.key = 'font';
  this.initialise(argh);
  }

ScoreBoardSettingFont.prototype = new ScoreBoardSettingPersistent();

ScoreBoardSettingFont.prototype.DefaultStaticValue = function () { 
  return 100; };

ScoreBoardSettingFont.prototype.Normalise = function (value) { 
  return ClipToRange(value, 10, undefined, this.DefaultStaticValue()); };

ScoreBoardSettingFont.prototype.RenderControl = function() {
  var sb = this.sb;
  var myname = sb.JSName();
  return '<tr><th>'+gTerms.font_size+'</th><td><button onclick="'+myname+'.SettingsIncrement(\'font\',-10);return false" id='+sb.id+'_sbctl_minus10_font'+(this.value>=20?'':' disabled')+'>-10</button><button onclick="'+myname+'.SettingsIncrement(\'font\',-1);return false" id='+sb.id+'_sbctl_minus1_font>-1</button><button class=output id='+sb.id+'_sbctl_font'+(this.value>=11?'':' disabled')+'>'+this.value+'%</button><button onclick="'+myname+'.SettingsIncrement(\'font\',1);return false" id='+sb.id+'_sbctl_plus1_font>+1</button><button onclick="'+myname+'.SettingsIncrement(\'font\',10);return false" id='+sb.id+'_sbctl_plus10_font>+10</button></td></tr>';
  };

ScoreBoardSettingFont.prototype.RenderOrder = 20;

ScoreBoardSettingFont.prototype.UpdateControl = function () {
  var sb = this.sb;
  if (!sb.tourney) return;

  var ref = document.getElementById(sb.id+'_sbctl_font');
  if (!ref) return;
  ref.innerHTML = this.value + '%';
  ref = document.getElementById(sb.id+'_sbctl_minus10_font');
  if (ref) ref.disabled = this.value >= 20 ? false : true;
  ref = document.getElementById(sb.id+'_sbctl_minus1_font');
  if (ref) ref.disabled = this.value >= 11 ? false : true;
  };

ScoreBoardSettingFont.prototype.UpdateScoreBoard = function (oldValue,newValue) {
  this.sb.Resize();
  };

// Class ScoreBoardSettingOffset - setting for starting rank in player list

function ScoreBoardSettingOffset (argh) {
  if (!argh) { return; }
  argh.key = 'offset';
  this.initialise(argh);
  }

ScoreBoardSettingOffset.prototype = new ScoreBoardSettingPersistent();

ScoreBoardSettingOffset.prototype.DefaultStaticValue = function () { 
  return 0; };

ScoreBoardSettingOffset.prototype.Normalise = function (value) { 
  var columns, maxOffset;
  var sb = this.sb;
  if (!sb.ps) return value;
  if (sb.SettingsGet('style') == 'compact') { columns = 1; }
  else { columns = sb.SettingsGet('columns'); }
  maxOffset = sb.ps.length - columns - 1;
  return ClipToRange(value, 0, maxOffset, 0);
  },

ScoreBoardSettingOffset.prototype.RenderControl = function() {
  var sb = this.sb;
  var myname = sb.JSName();

  return '<tr><th>'+gTerms.ranks+'</th><td><button onclick="'+myname+'.SettingsIncrement(\'offset\',-5);return false" id='+sb.id+'_sbctl_minus5_rank>-5</button><button onclick="'+myname+'.SettingsIncrement(\'offset\',-1);return false" id='+sb.id+'_sbctl_minus1_rank>-1</button><button class=output id='+sb.id+'_sbctl_rank disabled>'+(this.value+1)+'</button><button onclick="'+myname+'.SettingsIncrement(\'offset\',1);return false" id='+sb.id+'_sbctl_plus1_rank>+1</button><button onclick="'+myname+'.SettingsIncrement(\'offset\',5);return false" id='+sb.id+'_sbctl_plus5_rank>+5</button></td></tr>';
  };

ScoreBoardSettingOffset.prototype.RenderOrder = 7;

ScoreBoardSettingOffset.prototype.UpdateControl = function () {
  var sb = this.sb;
  if (!sb.tourney) return;
  var ref = document.getElementById(sb.id+'_sbctl_rank');
  if (!ref) return;
  var columns = sb.SettingsGet('style') == 'compact' ? 1 : sb.SettingsGet('columns'); 
  var maxOffset = (sb.SettingsGet('order') == 'board' ? Math.floor(sb.ps.length/2) : sb.ps.length) - columns - 1;
  ref.innerHTML = (this.value + 1) + '&ndash;' + Math.min(sb.ps.length, this.value + columns * sb.SettingsGet('rows'));
  ref = document.getElementById(sb.id+'_sbctl_minus5_rank');
  if (ref) ref.disabled = this.value > 4 ? false : true;
  ref = document.getElementById(sb.id+'_sbctl_minus1_rank');
  if (ref) ref.disabled = this.value > 0 ? false : true;
  ref = document.getElementById(sb.id+'_sbctl_plus1_rank');
  if (ref) ref.disabled = this.value <= maxOffset ? false : true;
  ref = document.getElementById(sb.id+'_sbctl_plus5_rank');
  if (ref) ref.disabled = this.value <= maxOffset - 5 ? false : true;
  };

ScoreBoardSettingOffset.prototype.UpdateScoreBoard = function (oldValue,newValue) {
  this.sb.UpdatePositions(true);
  };

// Class ScoreBoardSettingOrder - setting for player display order

function ScoreBoardSettingOrder (argh) {
  if (!argh) { return; }
  argh.key = 'order';
  this.initialise(argh);
  }

ScoreBoardSettingOrder.prototype = new ScoreBoardSettingPersistent();

ScoreBoardSettingOrder.prototype.DefaultStaticValue = function () { 
  return 'ranked'; };

ScoreBoardSettingOrder.prototype.Normalise = function (value) { 
  return ScoreBoard.cOrderInfo.hasOwnProperty(value) ? value : 'ranked'; },

ScoreBoardSettingOrder.prototype.RenderControl = function() {
  var order, oi;
  var sb = this.sb;
  var myname = sb.JSName();

  var html = '<tr><th>' + gTerms.order + '</th><td>';

  for (oi=0; oi<ScoreBoard.cOrders.length; oi++) {
    order = ScoreBoard.cOrders[oi];
    html += '<button onclick="'+myname+'.SettingsSet(\'order\',\''+order+'\');return false" id='+sb.id+'_sbctl_'+order+'_order'+(this.value===order?' disabled':'')+'>'+ gTerms['order_'+order]+'</button>';
    }

  html += '</td></tr>';
  return html;
  };

ScoreBoardSettingOrder.prototype.RenderOrder = 6;

ScoreBoardSettingOrder.prototype.UpdateControl = function () {
  var oi, order, order_ref;
  var sb = this.sb;
  if (!sb.tourney) return;

  for (oi=0; oi<ScoreBoard.cOrders.length; oi++) {
    order = ScoreBoard.cOrders[oi];
    order_ref = document.getElementById(sb.id+'_sbctl_'+order+'_order');
    if (!order_ref) return;
    order_ref.disabled = order == this.value ? true : false;
    }
  };

ScoreBoardSettingOrder.prototype.UpdateScoreBoard = function (oldValue,newValue) {
  this.sb.Synch(true, true); // 20150421
  this.sb.Resize(); 
  this.sb.UpdatePositions(true);
  };

// Class ScoreBoardSettingPane - setting for player display style

function ScoreBoardSettingPane (argh) {
  if (!argh) { return; }
  argh.key = 'pane';
  this.initialise(argh);
  }

// for now, not persistent
ScoreBoardSettingPane.prototype = new ScoreBoardSetting();

ScoreBoardSettingPane.prototype.DefaultStaticValue = function () { 
  return 0.5; };

ScoreBoardSettingPane.prototype.Normalise = function (value) { 
  return ClipToRange(value, 0.1, 0.9, 0.5); },

ScoreBoardSettingPane.prototype.RenderControl = function() {
  var sb = this.sb;
  if (!sb.Parent()) return '';
  var myname = sb.JSName();
  return '<tr><th>'+gTerms.pane_size+'</th><td><button onclick="'+myname+'.SettingsIncrement(\'pane\',-.05);return false" id='+sb.id+'_sbctl_minus5_split>-5</button><button onclick="'+myname+'.SettingsIncrement(\'pane\',-.01);return false" id='+sb.id+'_sbctl_minus1_split>-1</button><button class=output id='+sb.id+'_sbctl_split disabled>'+sb.RenderMySize()+'</button><button onclick="'+myname+'.SettingsIncrement(\'pane\',.01);return false" id='+sb.id+'_sbctl_plus1_split>+1</button><button onclick="'+myname+'.SettingsIncrement(\'pane\',.05);return false" id='+sb.id+'_sbctl_plus5_split>+5</button></td></tr>';
  };

ScoreBoardSettingPane.prototype.RenderOrder = 15;

ScoreBoardSettingPane.prototype.UpdateControl = function () {
  var sb = this.sb;
  var ref = document.getElementById(sb.id+'_sbctl_split');
  if (!ref) return;
  ref.innerHTML = sb.RenderMySize();
  ref = document.getElementById(sb.id+'_sbctl_minus5_split');
  if (sb.Parent()) {
    if (ref) ref.disabled = this.value >= 0.1099 ? false : true;
    ref = document.getElementById(sb.id+'_sbctl_minus1_split');
    if (ref) ref.disabled = this.value >= 0.1499 ? false : true;
    ref = document.getElementById(sb.id+'_sbctl_plus1_split');
    if (ref) ref.disabled = this.value <= 0.8901 ? false : true;
    ref = document.getElementById(sb.id+'_sbctl_plus5_split');
    if (ref) ref.disabled = this.value <= 0.8501 ? false : true;
    }
  else {
    ref.disabled = true;
    ref = document.getElementById(sb.id+'_sbctl_minus1_split');
    ref.disabled = true;
    ref = document.getElementById(sb.id+'_sbctl_plus1_split');
    ref.disabled = true;
    ref = document.getElementById(sb.id+'_sbctl_plus5_split');
    ref.disabled = true;
    }
  };

ScoreBoardSettingPane.prototype.UpdateScoreBoard = function (oldValue,newValue) {
  var sb = this.sb;
  var par = sb.Parent();
  if (!par) return;
  var birthOrder = sb.BirthOrder();
  var split = birthOrder ? 1 - this.value : this.value;
  par.child_share = par.child_share > 0 ? split : -split;
  par.children[1 - birthOrder].GetSettings('pane').SetNoUpdateScoreBoard(1 - this.value);
  par.Resize();
  par.UpdatePositions(true);
  };

// Class ScoreBoardSettingPhoto - setting for player photo display 

function ScoreBoardSettingPhoto (argh) {
  if (!argh) { return; }
  argh.key = 'photo';
  this.initialise(argh);
  }

ScoreBoardSettingPhoto.prototype = new ScoreBoardSettingPersistent();

ScoreBoardSettingPhoto.prototype.DefaultStaticValue = function () { 
  return true; };

ScoreBoardSettingPhoto.prototype.Normalise = function (value) { 
  return value==='false'?false:!!value; };

ScoreBoardSettingPhoto.prototype.RenderControl = function() {
  var sb = this.sb;
  var myname = sb.JSName();
  return '<tr><th>'+gTerms.photos+'</th><td>' +
    '<button onclick="'+myname+'.SettingsSet(\'photo\',true);return false" '+
      'id='+sb.id+'_sbctl_on_photo'+(this.value?' disabled':'')+'>'+
      gTerms.photos_on+'</button>'+
    '<button onclick="'+myname+'.SettingsSet(\'photo\',false);return false" '+
      'id='+sb.id+'_sbctl_off_photo'+(this.value?'':' disabled')+'>'+
      gTerms.photos_off+'</button></td></tr>';
  };

ScoreBoardSettingPhoto.prototype.RenderOrder = 4;

ScoreBoardSettingPhoto.prototype.UpdateControl = function () {
  var sb = this.sb;
  var ref = document.getElementById(sb.id+'_sbctl_on_photo');
  if (!ref) return;
  ref.disabled = !!this.value;
  ref = document.getElementById(sb.id+'_sbctl_off_photo');
  ref.disabled = !this.value;
  };

ScoreBoardSettingPhoto.prototype.UpdateScoreBoard = function (oldValue,newValue) {
  this.sb.Synch(true, true);
  };

// Class ScoreBoardSettingReload - setting for data reload interval

function ScoreBoardSettingReload (argh) {
  if (!argh) { return; }
  argh.key = 'reload_power';
  this.initialise(argh);
  }

ScoreBoardSettingReload.prototype = new ScoreBoardSettingPersistent();

ScoreBoardSettingReload.prototype.DefaultStaticValue = function () { 
  return 3; };

ScoreBoardSettingReload.prototype.Normalise = function (value) { 
  return ClipToRange(value, 0, 8, 3); };

ScoreBoardSettingReload.prototype.RenderControl = function() {
  var sb = this.sb;
  var myname = sb.JSName();
  return '<tr><th>'+gTerms.reload+'</th><td><button onclick="'+myname+'.SettingsIncrement(\'reload_power\',-1);return false" id='+sb.id+'_sbctl_slower_reload' + (sb.SettingsGet('reload_power') > 0 ? '' : ' disabled')+'>'+gTerms.slower+'</button><button class=output id='+sb.id+'_sbctl_reload>'+sb.RenderReloadRate()+'</button><button onclick="'+myname+'.SettingsIncrement(\'reload_power\',1);return false" id='+sb.id+'_sbctl_faster_reload>'+gTerms.faster+'</button></td></tr>';
  };

ScoreBoardSettingReload.prototype.RenderOrder = 9;

ScoreBoardSettingReload.prototype.Set = function (newValue) {
  this.sb.reload_rate = newValue >= 0 ? 20*Math.floor((25 * (1<<newValue))/20) : 0;
//console.log('set',newValue,this.sb.reload_rate);
  if (!this.sb.reload_rate) error('reload paused');
  ScoreBoardSettingPersistent.prototype.Set.call(this,newValue); // class inheritance
  };

ScoreBoardSettingReload.prototype.UpdateControl = function () {
  var sb = this.sb;
  var ref = document.getElementById(sb.id+'_sbctl_reload');
  if (!ref) return;
  ref.innerHTML = sb.RenderReloadRate();
  ref = document.getElementById(sb.id+'_sbctl_slower_reload');
  if (ref) ref.disabled = this.value > -1 ? false : true;
  ref = document.getElementById(sb.id+'_sbctl_faster_reload');
  if (ref) ref.disabled = this.value < 8 ? false : true;
  };

ScoreBoardSettingReload.prototype.UpdateScoreBoard = function (oldValue,newValue) {
  this.sb.reload_count = newValue; };

// Class ScoreBoardSettingRoot - setting for base URL for event

function ScoreBoardSettingRoot (argh) {
  if (!argh) { return; }
  argh.key = 'root';
  this.initialise(argh);
  }

// doesn't make sense to make this persistent
ScoreBoardSettingRoot.prototype = new ScoreBoardSetting();

ScoreBoardSettingRoot.prototype.DefaultStaticValue = function () { 
  return 'URL required'; };

ScoreBoardSettingRoot.prototype.RenderControl = function() {
  var sb = this.sb;
  if (sb.Parent()) return '';
  return '<tr><th>'+gTerms.url+'</th><td><input type="text" value="'+this.value+'" size=30 id='+sb.id+'_sbctl_url /> <button onclick="'+sb.JSName()+'.SettingsSet(\'root\',document.getElementById(\''+sb.id+'_sbctl_url\').value)">'+gTerms.Load+'</button></td></tr>';
  };

ScoreBoardSettingRoot.prototype.RenderOrder = 12;

ScoreBoardSettingRoot.prototype.UpdateScoreBoard = function (oldValue,newValue) {
  var sb = this.sb;
  if (sb.Parent()) {
    // For now, we only allow changing the URL in the root scoreboard, because
    // allowing different URLs in different parts of the tree would require a
    // little graphic redesign to make the event titles clearer, and some
    // recoding to minimize the number of fetches taking place in a
    // heterogeneous environment.
    console.log('Changing URL not currently supported for nonroot nodes.');
    return;
    }
  sb.SettingsSet('root', newValue);
  sb.pfu = new PoslFetchURL(newValue + '/tourney.js');
  sb.reload_count = sb.reload_rate =
    sb.reload_power > 0 ? 20*Math.floor((25 * (1<<sb.reload_power))/20) : 0;
  sb.Synch(false, false); 
  sb.Render();
  sb.Resize(); 
  sb.UpdatePositions(true);
  };

// Class ScoreBoardSettingRows - setting for # of rows in grid

function ScoreBoardSettingRows (argh) {
  if (!argh) { return; }
  argh.key = 'rows';
  this.initialise(argh);
  }

ScoreBoardSettingRows.prototype = new ScoreBoardSettingPersistent();

ScoreBoardSettingRows.prototype.DefaultStaticValue = function () { 
  return 4; };

ScoreBoardSettingRows.prototype.Normalise = function (value) { 
  return ClipToRange(value, 1, undefined, this.DefaultStaticValue()); };

ScoreBoardSettingRows.prototype.RenderControl = function() {
  var sb = this.sb;
  var myname = sb.JSName();
  return '<tr><th>'+gTerms.rows+'</th><td><button onclick="'+myname+'.SettingsIncrement(\'rows\',-1);return false" id='+sb.id+'_sbctl_minus_rows'+(this.value<=1?' disabled':'')+'>&ndash;</button><button class=output id='+sb.id+'_sbctl_rows>'+this.value+'</button><button onclick="'+myname+'.SettingsIncrement(\'rows\',1);return false" id='+sb.id+'_sbctl_plus_rows>+</button></td></tr>';
  };

ScoreBoardSettingRows.prototype.RenderOrder = 2;

ScoreBoardSettingRows.prototype.UpdateControl = function () {
  var sb = this.sb;
  var ref = document.getElementById(sb.id+'_sbctl_rows');
  if (!ref) return;
  ref.innerHTML = this.value;
  ref = document.getElementById(sb.id+'_sbctl_minus_rows');
  if (ref) ref.disabled = this.value > 1 ? false : true;
  };

ScoreBoardSettingRows.prototype.UpdateScoreBoard = function (oldValue,newValue) {
  this.sb.Resize(); 
  this.sb.UpdatePositions(true);
  };

// Class ScoreBoardSettingScroll - setting for scroll rate

function ScoreBoardSettingScroll (argh) {
  if (!argh) { return; }
  argh.key = 'scroll_rate';
  this.initialise(argh);
  }

ScoreBoardSettingScroll.prototype = new ScoreBoardSettingPersistent();

ScoreBoardSettingScroll.prototype.DefaultStaticValue = function () { 
  return 0; };

ScoreBoardSettingScroll.prototype.Normalise = function (value) { 
  return ClipToRange(value, 0, 15, 0); };

ScoreBoardSettingScroll.prototype.RenderControl = function() {
  var sb = this.sb;
  var myname = sb.JSName();
  return '<tr><th>'+gTerms.scroll+'</th><td><button onclick="'+myname+'.SettingsIncrement(\'scroll_rate\',-1);return false" id='+sb.id+'_sbctl_slower_scroll' + (sb.SettingsGet('scroll_rate') > 0 ? '' : ' disabled')+'>'+gTerms.slower+'</button><button class=output id='+sb.id+'_sbctl_scroll>'+sb.RenderScrollRate()+'</button><button onclick="'+myname+'.SettingsIncrement(\'scroll_rate\',1);return false" id='+sb.id+'_sbctl_faster_scroll>'+gTerms.faster+'</button></td></tr>';
  };

ScoreBoardSettingScroll.prototype.RenderOrder = 8;

ScoreBoardSettingScroll.prototype.UpdateControl = function () {
  var sb = this.sb;
  var ref = document.getElementById(sb.id+'_sbctl_scroll');
  if (!ref) return;
  ref.innerHTML = sb.RenderScrollRate();
  ref = document.getElementById(sb.id+'_sbctl_slower_scroll');
  if (ref) ref.disabled = this.value > 0 ? false : true;
  ref = document.getElementById(sb.id+'_sbctl_faster_scroll');
  if (ref) ref.disabled = this.value <= 14 ? false : true;
  };

ScoreBoardSettingScroll.prototype.UpdateScoreBoard = function (oldValue,newValue) {
  this.sb.scroll_count = newValue; };

// Class ScoreBoardSettingSelfLink - if true, enable links using own URL

function ScoreBoardSettingSelfLink (argh) {
  if (!argh) { return; }
  argh.key = 'selflink';
  this.initialise(argh);
  }

// not persistent for now
ScoreBoardSettingSelfLink.prototype = new ScoreBoardSetting();

ScoreBoardSettingSelfLink.prototype.DefaultValue = function () { return true; }

ScoreBoardSettingSelfLink.prototype.RenderOrder = 998;

// Class ScoreBoardSettingStyle - setting for player display style

function ScoreBoardSettingStyle (argh) {
  if (!argh) { return; }
  argh.key = 'style';
  this.initialise(argh);
  }

ScoreBoardSettingStyle.prototype = new ScoreBoardSettingPersistent();

ScoreBoardSettingStyle.prototype.DefaultStaticValue = function () { 
  return 'normal'; };

ScoreBoardSettingStyle.prototype.Normalise = function (value) { 
  return ScoreBoard.cStyleInfo.hasOwnProperty(value) ? value : 'normal'; },

ScoreBoardSettingStyle.prototype.RenderControl = function() {
  var si, style;

  var sb = this.sb;
  var html = '<tr><th>' + gTerms.style + '</th><td>';
  var myname = sb.JSName();
  for (var si=0; si<ScoreBoard.cStyles.length; si++) {
    style = ScoreBoard.cStyles[si];
    html += '<button onclick="'+myname+'.SettingsSet(\'style\',\''+style+'\');return false" id='+sb.id+'_sbctl_'+style+'_style'+(style===this.value?' disabled':'')+'>'+ gTerms['style_'+style]+'</button>';
    }
  html += '</td></tr>';
  return html;
  };

ScoreBoardSettingStyle.prototype.RenderOrder = 5;

ScoreBoardSettingStyle.prototype.UpdateControl = function () {
  var si, style, style_ref;
  var sb = this.sb;

  for (si=0; si<ScoreBoard.cStyles.length; si++) {
    style = ScoreBoard.cStyles[si];
    style_ref = document.getElementById(sb.id+'_sbctl_'+style+'_style');
    if (!style_ref) return;
    style_ref.disabled = style == this.value ? true : false;
    }
  };

ScoreBoardSettingStyle.prototype.UpdateScoreBoard = function (oldValue,newValue) {
  var sb = this.sb;
  var this_ref = document.getElementById(sb.id);
  switch(newValue) {
    case 'compact':
      if (sb.SettingsGet('rows') < 20) sb.SettingsSet('rows', 20);
      sb.SettingsSet('order', 'ranking');
      break;
    case 'card':
      if (sb.SettingsGet('rows') > 2) sb.SettingsSet('rows', 2);
      sb.SettingsSet('order', 'id');
      break;
    case 'pair':
      if (sb.SettingsGet('rows') > 5) sb.SettingsSet('rows', 5);
      sb.SettingsSet('order', 'board');
      break;
    default:
      if (sb.SettingsGet('rows') > 10) sb.SettingsSet('rows', 10);
      sb.SettingsSet('order', 'ranking');
    }

  if (newValue === 'blink') {
    sb.blink_rate = 60;
    sb.blink_count = 0;
    sb.blink_state = 0;
    this_ref.className = 'alt' + (sb.child_share ? 'p' : '0');
    }
  else {
    sb.blink_rate = 0;
    this_ref.className = newValue;
    }
  sb.Synch(true, true);
  sb.Resize(); 
  sb.UpdatePositions(true);
  };

// Class ScoreBoard - a node in the tree of ScoreBoard panes

var root_sb_id;
var the_sbs = {};
var thai_name_cache = {};

// constructor
function ScoreBoard(argh) {
  var i, key, ref, sinfo, url, value;
  if (defined(the_sbs[argh.id])) {
    alert("Internal error: duplicate ScoreBoard ID: "+argh.id);
    return;
    }
  the_sbs[argh.id] = this;
  this.settings = {};
  this.settingObjects = {};
  this.id = argh.id; // render the scoreboard in the object with this CSS ID

  // we used to require argh.url; this is now deprecated in favour of argh.root
  if (defined(argh.root)) {
    if (defined(argh.url)) delete argh.url;
    url = argh.root + '/tourney.js';
    }
  else {
    if (defined(argh.url)) { 
      argh.root = argh.url.replace(/[^\/]+$/, '');
      url = argh.url;
      delete argh.url;
      }
    else {
      console.log('missing required argument: root');
      // TODO: does not work if URL looks like http://localhost/cgi-bin/tshesb.pl?root=http://localhost/malta-me
      argh.root = window.location.href.replace(/[^\/]+$/,'');
      url = argh.root + '/tourney.js';
      }
    }

  this.pfu = new PoslFetchURL(url);

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

  // links to TSH structures
  this.dp = undefined;

  if (!argh.nomsg) {
    ref = argh.message_object;
    if (!ref) ref = document.getElementById(argh.message_object_id);
    if (ref) this.message = new ScoreBoardMessage({
      'object':ref,
      'scoreboard':this
      });
    }
  // round number being displayed
  this.r1 = 0;
  this.real_r1 = 0;
  // refresh rate parameters
  this.reload_power = 3; // TODO: calculate based on argh.refresh
  this.reload_rate = 20 * (argh.refresh || 10);
  this.reload_count = 0;
  // scroll parameters
  this.scroll_count = 0;
  // true if watching the current round, that should autoincrement
  this.viewing_live = true;

  // creation configuration setting objects
  for (key in ScoreBoard.cSettingsInfo) { 
    if (!ScoreBoard.cSettingsInfo.hasOwnProperty(key)) continue;
    sinfo = ScoreBoard.cSettingsInfo[key];
    this.settingObjects[key] = new sinfo.classObject({'sb':this,'value':argh[key]});
    }

  // must set tourney after configuration parameters
  // else much confusion ensues in partially configured sb
  if (this.Parent()) this.tourney = this.Parent().tourney;

  this.Synch(false, false);
  };

ScoreBoard.cOrderInfo = {
  'board': {},
  'ranked': {},
  'id': {}
  };
ScoreBoard.cOrders = ['board', 'ranked', 'id'];
ScoreBoard.cStyleInfo = {
  'blink': { 'renderer': 'RenderNonCompact' },
  'card': { 'renderer': 'RenderCard' },
  'compact': { 'renderer': 'RenderCompact' },
  'normal': { 'renderer': 'RenderNonCompact' },
  'pair': { 'renderer': 'RenderPair' }
  };
ScoreBoard.cStyles = ['normal', 'blink', 'compact', 'card', 'pair'];

ScoreBoard.cSettingsInfo = {
  // TODO: classes should register themselves 
  // number of columns in grid
  'columns' : {  'classObject': ScoreBoardSettingColumns },
  // dispatcher URL
  'dispatcher': { 'classObject': ScoreBoardSettingDispatcher },
  // tournament division to display
  'division': { 'classObject': ScoreBoardSettingDivision },
  // percentage font size of scoreboard text
  'font' : { 'classObject': ScoreBoardSettingFont },
  // offset of first displayed rank from top actual rank
  'offset': { 'classObject': ScoreBoardSettingOffset },
  // order in which to list players
  'order': { 'classObject': ScoreBoardSettingOrder },
  // proportionate size of split panes
  'pane': { 'classObject': ScoreBoardSettingPane },
  // whether or not player photos should be displayed
  'photo': { 'classObject': ScoreBoardSettingPhoto },
  // interval (in seconds) at which data is reloaded
  'reload_power': { 'classObject': ScoreBoardSettingReload },
  // base URL for scoreboard
  'root': { 'classObject': ScoreBoardSettingRoot },
  // number of rows in grid
  'rows': { 'classObject': ScoreBoardSettingRows },
  // use own address for links
  'selflink': { 'classObject': ScoreBoardSettingSelfLink },
  // rate at which players scroll by
  'scroll_rate': { 'classObject': ScoreBoardSettingScroll },
  // style in which to display players
  'style': { 'classObject': ScoreBoardSettingStyle },
  };

ScoreBoard.prototype.AdjustRound = function(delta) {
  var curr_ref = document.getElementById(this.id+'_sbctl_round');
  var prev_ref = document.getElementById(this.id+'_sbctl_previous_round');
  var next_ref = document.getElementById(this.id+'_sbctl_next_round');
  if (this.viewing_live) {
    if (delta < 0) {
      this.viewing_live = false;
      this.real_r1--;
      if (next_ref) next_ref.style.display = 'inline';
      }
    this.r1 = this.real_r1; // last scored round
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
  if (this.SettingsGet('order') == 'board' && this.viewing_live) {
    // NO, don't do this - players want to see the next round, not the partial one.
//  // If the last scored round has partial results, look at that one. 
//  if (this.r1 > DivisionLeastScores(this.dp)) this.r1--;
//  else
    // If the last scored rd is full and the next rd is paired, look at the next.
    if (this.r1 < DivisionLastPairedRound0(this.dp)+1) this.r1++;
    this.r0 = this.r1 - 1;
    }
//console.log(this,'AdjustRound',delta);
  if (prev_ref) prev_ref.style.display = this.r1 > 0 ? 'inline' : 'none';
  if (curr_ref) { curr_ref.innerHTML = this.RenderRound(); }
  if (delta) { this.Synch(true, true); this.UpdatePositions(true); } // 20150421
  }

ScoreBoard.prototype.BirthOrder = function () {
  return this.id.replace(/^.*[^0-9]/,'')*1;
  }

function ClipToRange(value, minimum, maximum, defaultValue) {
  value *= 1;
  if (isNaN(value)) {
    if (defined(minimum)) return minimum;
    if (defined(maximum)) return maximum;
    if (defined(defaultValue)) return defaultValue;
    return 1;
    }
  if (defined(minimum)) { if (value < minimum) return minimum; }
  if (defined(maximum)) { if (value > maximum) return maximum; }
  return value;
  }

ScoreBoard.prototype.Close = function () {
  this.Parent().CloseChild(this.BirthOrder());
  }

ScoreBoard.prototype.CloseChild = function (birth_order) {
  var i, key;
  for (i=0; i<this.children.length; i++) {
    delete the_sbs[this.id+'_c'+i]; // they'll get recreated
    }
  this.children.splice(birth_order, 1);
  if (this.children.length == 1) {
    for (key in this.settingObjects) { 
      if (!this.settingObjects.hasOwnProperty(key)) continue;
      this.settingObjects[key].SetNoUpdateScoreBoard(this.children[0].SettingsGet(key));
      }
    this.child_share = null;
    this.children = null;
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

// Render a head shot and name given a player's data object and some options
ScoreBoard.prototype.FormatPlayerPhotoName = function(p, optionsp) {
  if (defined(p)) {
    return this.HeadShot(p, optionsp) + this.TagName(p, optionsp);
    }
  else {
    return '<div class=nohead>?</div>';
    }
  }

ScoreBoard.prototype.GearClick = function () {
  var ref = document.getElementById(this.id+'_ctlbox');
  if (!ref) { error("no control box", this.id); return; }
//console.log('GearClick',ref.style.display);
  if (this.settingsVisible) this.HideSettings();
  else this.ShowSettings();
  }

ScoreBoard.prototype.GetSettings = function (key) { 
  return this.settingObjects[key];
  };

ScoreBoard.prototype.Height = function () { 
  if (this.Parent()) return this.DOMReference().offsetHeight;
  else return getWindowHeight() - (this.banner_height ? this.banner_height + 5 : 0);
  };

ScoreBoard.prototype.Hide = function () { 
  this.DOMReference().style.display = 'none'; }

ScoreBoard.prototype.HideAllSettings = function () { 
  var i;
  this.HideSettings();
  if (this.children) {
    for (i=0; i<this.children.length; i++) {
      this.children[i].HideAllSettings();
      }
    }
  }

ScoreBoard.prototype.HideSettings = function () { 
//console.log('HideSettings');
  var ref = document.getElementById(this.id+'_ctlbox');
  if (!ref) { error(this, 'HideSettings', 'no control box', this.id); return; }
  if (!ref.className.match(/ hidden/)) ref.className += ' hidden';
  this.settingsVisible = false;
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

// return true if in the current r0, a player either went second in the
// current round or, or did not go first against a lower-numbered opponent,
// and should therefore not head an entry in the 'board' style pairing
// display
ScoreBoard.prototype.IsSecondaryPlayer = function (p) {
  var oid;
//console.log(p.id, this.r0, PlayerFirst(p,this.r0));
  switch(PlayerFirst(p, this.r0)) {
    case 1: return false;
    case 2: return true;
    default:
      oid = PlayerOpponentID(p, this.r0);
      if (oid && p.id > oid) { return true; }
      return false;
    }
  }

ScoreBoard.prototype.JSName = function () { return "the_sbs['"+this.id+"']"; }

// used by external routines to initialize a root scoreboard
function KeepLoadingScoreBoard(argh) {
  console.log("TSH ESB Version "+TSH_ESB_Version);
  var i, the_sb;
  var argh2 = getSearchVariables();

  for (i in argh) {
    if (!argh.hasOwnProperty(i)) continue;
    argh2[i] = argh[i];
    }
  the_sb = new ScoreBoard(argh2);
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
  the_sb.UpdateControls();
  the_sb.UpdatePositions(true); 
  window.onresize = function () { the_sb.Resize(); the_sb.UpdatePositions(true); }
  window.onkeyup = function (e) { the_sb.KeyUp(e); }
  var ticker = function () {
    if (!document.getElementById(the_sb.id)) return;
    window.setTimeout(ticker, 50);
    if (the_sb) the_sb.Tick();
    }
  ticker();
  }

ScoreBoard.prototype.KeyUp = function (e) {
  var targ;
  e = e || window.event;
  if (e.target) targ = e.target;
  else if (e.srcElement) targ = e.srcElement;
  if (targ.nodeType == 3) targ = targ.parentNode; // Safari bug
  if (e.keyCode == 27) {
    this.HideAllSettings();
    }
  };

ScoreBoard.prototype.Parent = function () { return this['parent']; }

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
    if (config.rating_system.match(/^(spread)/)) html += ' spread';
    if (config.rating_system.match(/^(sudoku)/)) html += ' sudoku';
  html += '" style="font-size:inherit"><tr><td>';
  html += this.RenderTable();
  html += '</td></tr></table>';
  html += '</div>';

  html += '<div class=splitter id="'+this.id+'_split" style="position:absolute;background-color:white;opacity:0.25" draggable="true" ondragstart="'+this.JSName()+'.DragStart(event)"></div>';
  html += this.RenderControls();
//console.log(this.id+'_split');
  html += '<div class=sib1 id="'+this.id+'_c1" style="position:absolute"></div>';
  if (this.banner_height && this.banner_url) {
    html += '<iframe class=sbban src="'+this.banner_url+'" height='+this.banner_height+' width="100%" scrolling=no seamless style="position:absolute;top:0px;left:0px;">Please upgrade to a browser that supports iframes.</iframe>';
    }
  ref.innerHTML = html;
  }

ScoreBoard.prototype.RenderBoard = function (p, r0, optionsp) {
  var board = '';
  var b = PlayerBoard(p, r0);
  var style = (optionsp||{}).style || 'at';
  if (b) {
    if (this.c_has_tables) {
      board = DivisionBoardTable(this.dp, b, this.tourney.config);
      if (style == 'verbose') board = gTerms.Table + ' ' + board;
      }
    else if (!this.c_no_boards) {
      board = b;
      if (style == 'verbose') board = gTerms.Board + ' ' + board;
      }
    if (style == 'at' && (board+"").length) board = " @"+board;
    }
  return board;
  }

ScoreBoard.prototype.RenderControls = function () {
  var i, key, rows, s, value;
  var html = '';
  var myname = this.JSName();
  var config = this.tourney.config;
  var dp = TournamentGetDivisionByName(this.tourney, this.SettingsGet('division'));
//console.log(dp);
  var title =
    (this.tourney.config.event_name ?
      '<span class=event>' + this.tourney.config.event_name + '</span> ' : '') +
    (TournamentCountDivisions(this.tourney) > 1 ?
     DivisionLabel(dp, config, {'format':'html'}) : '');
//html += '<style type="text/css">'+
    // insert experimental CSS here
//  '</style>';
  var banner_height = (this.banner_height && this.banner_url) ? this.banner_height + 5: 0;
  html += '<div class="sbctl title" style="top:'+banner_height+'" id="'+this.id+'_title">'+title+'</div>';
  html += '<div class="sbctl tools" style="top:'+banner_height+'" id="'+this.id+'_sbctl_tools">';
  html += '<span id=error></span> ';
  html += '<span class=note id=sbctl_note>&nbsp;</span> ';
  html += '<a href="#" title="'+gTerms['Reload_Now']+'" onclick="'+myname+'.reload_count = 0;'+myname+'.Synch(true, false);return false">\u21bb</a> ';
  html += this.Parent() ? '<a href="#" title="'+gTerms['Close_Pane']+'" onclick="'+myname+'.Close();return false">x</a> ': ''; // close button if we have a parent to close to
//html += '<span id="'+this.id+'_sbctl_split">';
  html += '<a href="#" title="'+gTerms['Split_Top_and_Bottom']+'" onclick="'+myname+'.Split(0);return false">\u00f7</a> ';
  html += '<a href="#" title="'+gTerms['Split_Left_and_Right']+'" onclick="'+myname+'.Split(1);return false">\u00b7|\u00b7</a> ';
//html += '</span>'; // buttons to split horizontally or vertically
  html += '<a href="#" title="'+gTerms['View_Previous_Round']+'" onclick="'+myname+'.AdjustRound(-1);return false" id='+this.id+'_sbctl_previous_round>\u226a</a> '; // 20150421
  html += '<span id='+this.id+'_sbctl_round>' + this.RenderRound() + '</span> ';
  html += '<a href="#" title="'+gTerms['View_Next_Round']+'" onclick="'+myname+'.AdjustRound(1);return false" id='+this.id+'_sbctl_next_round style="display:none">\u226b</a> '; // 20150421
  html += '<span class=progress>' + this.RenderProgress() + '</span> ';
  html += '<a class=gear href="#" title="'+gTerms['Scoreboard_Settings']+'" onclick="'+myname+'.GearClick();return false">\u2699</a> ';
  html += '</div>'; // sbctl tools
  html += '<div class="ctlbox '+(this.settingsVisible ? '' : ' hidden')+'" id="'+this.id+'_ctlbox"><table class=ctls>';
    html += '<tr><td class=close colspan=2>'+gTerms['Scoreboard_Settings']+'<button onclick="'+myname+'.GearClick()">X</button></td></tr>';
    rows = [];
    for (key in this.settingObjects) { 
      if (!this.settingObjects.hasOwnProperty(key)) continue;
      s = this.settingObjects[key];
      rows.push([s.RenderOrder, s.RenderControl()]);
      }
    rows.sort(function(a,b){return compare(a[0],b[0])});
    for (i=0; i<rows.length; i++) { html += rows[i][1]; }
  html += '</table></div>';
  html += '</div>';
  return html;
  };

ScoreBoard.prototype.RenderMySize = function () {
  var size = this.SettingsGet('pane');
  if (defined(size)) { return Math.round(size*100) + '%'; }
  else { return '100%'; }
  };

ScoreBoard.prototype.RenderProgress = function () {
  var dp = TournamentGetDivisionByName(this.tourney, this.SettingsGet('division'));
  var ps = DivisionPlayers(dp);
  var nactive = 0;
  var nscored = 0;
  var r0 = this.r0;
  var p, pi;
  for (pi=0; pi<ps.length; pi++) {
    p = ps[pi];
    if (PlayerActive(p)) {
      nactive++;
      if (defined(PlayerScore(p, r0))) nscored++;
      }
    }
  return nscored + '/' + nactive;
  };

ScoreBoard.prototype.RenderReloadRate = function () {
  if (this.SettingsGet('reload_power') > 0) {
// number of ticks that elapse between data fetches
    return Math.floor((1 << this.SettingsGet('reload_power')) * 1.25) + 's'; 
    }
  else return gTerms['reload_stopped'];
  };

ScoreBoard.prototype.RenderRound = function () {
  if (this.viewing_live) {
    return '';
    }
  else {
    return gTerms.Round + ' ' + this.r1;
    }
  };

ScoreBoard.prototype.RenderScrollRate = function () {
  if (this.SettingsGet('scroll_rate')) {
// number of seconds that scoreboard stands still between scrolls
    return Math.floor(200/this.SettingsGet('scroll_rate'))/20 + 's'; 
    }
  else return gTerms['scroll_stopped'];
  };

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

// should be called whenever our display or font size changes,
// typically followed by a call to UpdatePositions()
ScoreBoard.prototype.Resize = function () {
  var child0_dom, child1_dom, parent_banner_height, splitter_dom, winHeight, winWidth;
  var splitterWidth = 5;
  var winHeight = this.Height();
  var winWidth = this.Width();
  var myref = this.DOMReference();
  var tourney = this.tourney;
  var style = this.SettingsGet('style');
  var banner_height = (this.banner_height && this.banner_url) ? this.banner_height + 5: 0;

  myref.style.fontSize = this.SettingsGet('font') + '%';

  if (!tourney) return;
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
      child1_dom.style.top = (winHeight + splitterWidth + banner_height) + 'px'; // the modified winHeight
      child0_dom.style.height = winHeight + 'px';
      child0_dom.style.width = winWidth + 'px';
      child0_dom.style.left = "0px";
      child0_dom.style.top = banner_height + 'px'; 
      splitter_dom.style.left = "0px";
      splitter_dom.style.top = (winHeight + banner_height) + 'px';
      splitter_dom.style.height = splitterWidth + 'px';
      splitter_dom.style.width = winWidth + 'px';
      }
    else { // split left and right
      child1_dom.style.height = winHeight + 'px';
      child1_dom.style.width = ((winWidth-splitterWidth) * (1+this.child_share)) + 'px';
      winWidth = (winWidth-splitterWidth) * (-this.child_share);
      child1_dom.style.left = (winWidth + splitterWidth) + 'px'; // the modified winWidth
      child1_dom.style.top = banner_height + 'px';
      child0_dom.style.height = winHeight + 'px';
      child0_dom.style.width = winWidth + 'px';
      child0_dom.style.left = "0px"; 
      child0_dom.style.top = banner_height + 'px';
      splitter_dom.style.left = winWidth + 'px';
      splitter_dom.style.top = banner_height + 'px';
      splitter_dom.style.height = winHeight + 'px';
      splitter_dom.style.width = splitterWidth + 'px';
      }
    if (this.children) { // child_share gets set before children
      this.children[0].Resize();
      this.children[1].Resize();
      }
    return; // rest is for leaf nodes
    }

  child0_dom = document.getElementById(this.id+'_c0');
  child0_dom.style.top = banner_height + 'px';

//console.log('resize-squeezed', this.id, winHeight, winWidth);
  if (style == 'compact') {
    var aspect = tourney.config.player_photo_aspect_ratio || 1;
    this.cell_vspacing = Math.floor((winHeight-gcControlHeight) / this.SettingsGet('rows'));
    this.cell_height = this.cell_vspacing - 1;
    this.cell_hspacing = winWidth;
    this.cell_width = winWidth;
    this.photo_size = Math.floor(0.9 * this.cell_height/aspect);
    }
  else {
    this.cell_vspacing = Math.floor((winHeight-gcControlHeight) / this.SettingsGet('rows'));
//  console.log(this.id,this.cell_vspacing,winHeight,this.SettingsGet('rows'),gcControlHeight);
    this.cell_height = this.cell_vspacing - 5;
    this.cell_hspacing = Math.floor(winWidth / this.SettingsGet('columns'));
    this.cell_width = this.cell_hspacing - 9; // 5 seems tight on TVs
    switch(style) {
      case 'pair':
	this.photo_size = Math.max(24, Math.min(Math.round(this.cell_width/2)-12, this.cell_height-112));
	break;
      default:
      this.photo_size = Math.max(24, Math.min(Math.round(this.cell_width-112), this.cell_height-112));
      }
    }
//console.log('cell size',this.id,'c,r',this.SettingsGet('columns'),this.SettingsGet('rows'),'w,h',this.cell_width,this.cell_height,'hsp,vsp',this.cell_hspacing,this.cell_vspacing);
  if (this.ps) {
    for (var i=0; i<this.ps.length;i++) {
      this.ps[i].Resize();
      }
    }
  }

// Return the root of this ScoreBoard's tree
ScoreBoard.prototype.Root = function () {
  var par = this.Parent();
  return par ? par.Root() : this;
  };

ScoreBoard.prototype.SettingsAdjust = function(key, adjustor) {
  return this.settingObjects[key].Adjust(adjustor);
  };

ScoreBoard.prototype.SettingsGet = function(key) {
  return this.settingObjects[key].Get(); };

ScoreBoard.prototype.SettingsIncrement = function(key, delta) {
  this.SettingsAdjust(key,function(x){return x+delta});
  }

ScoreBoard.prototype.SettingsSet = function(key, newValue) {
  return this.settingObjects[key].Set(newValue); };

ScoreBoard.prototype.SetTourney = function (tourney) {
  this.tourney = tourney;
  if (this.children) {
    this.children[0].SetTourney(tourney);
    this.children[1].SetTourney(tourney);
    }
  }

function SetupTerminology(cfg) {
  // TODO: support language detection
  return ConfigTerminology(cfg, { 
    '1st':[],
    '2nd':[],
    'B':[],
    'Board':[],
    'bye':[],
    'Close_Pane': [],
    'columns':[],
    'data_loaded':[],
    'Division':[],
    'division':[],
    'draw':[],
    'F':[],
    'faster':[],
    'font_size':[],
    'L':[],
    'Last_Game_sb':[],
    'Load':[],
    'Next_Game_sb':[],
    'Opponent':[],
    'order':[],
    'order_board':[],
    'order_id':[],
    'order_ranked':[],
    'p12':[],
    'pane_size':[],
    'photos':[],
    'photos_off':[],
    'photos_on':[],
    'Rank':[],
    'ranks':[],
    'Rec-ord':[],
    'reload':[],
    'reload_stopped':[],
    'Reload_Now': [],
    'Rnd':[],
    'Round':[],
    'rows':[],
    'Score':[],
    'Scoreboard_Settings': [],
    'scroll':[],
    'scroll_stopped':[],
    'slower':[],
    'Split_Left_and_Right': [],
    'Split_Top_and_Bottom': [],
    'Spread':[],
    'style':[],
    'style_blink':[],
    'style_card':[],
    'style_compact':[],
    'style_normal':[],
    'style_pair':[],
    'T':[],
    'Table':[],
    'url':[],
    'vs':[],
    'View_Next_Round': [],
    'View_Previous_Round': [],
    'W':[],
    'W_L':[],
    'was':[]
    });
  }

ScoreBoard.prototype.Show = function () { 
  this.DOMReference().style.display = 'block';
  }

ScoreBoard.prototype.ShowSettings = function () { 
//console.log(this,'ShowSettings');
  var ref = document.getElementById(this.id+'_ctlbox');
  if (!ref) { console.log(this, 'ShowSettings', 'no control box', this.id); return; }
  ref.className = ref.className.replace(/ hidden/,'');
  ref = document.getElementById(this.id+'_sbctl_url');
  if (ref) {
    ref.selectionStart = ref.selectionEnd = ref.value.length;
    ref.focus();
    }
  this.settingsVisible = true;
  }

ScoreBoard.prototype.Split = function (dir) {
  var child_id, child_js, ref;

//console.log(this.id,'Split',this.children);
  if (this.children) { alert('cannot currently have more than two children'); return; }
  if (dir == 0) { // split top and bottom
    this.child_share = 0.5; // change this later when pane split is to persist
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
    this.children[i] = child_js = new ScoreBoard({ id: child_id, 'parent': this, 'root': this.SettingsGet('root'),
      'pane':0.5}); // change this later when pane split is to persist
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
  var child, y1, y2, newShare;
  if (this.child_share > 0) {
    y1 = event.clientY || event.y;
    y2 = this.Height();
//  if (this.banner_height) {
//    y1 -= this.banner_height + 5;
//    y2 -= this.banner_height + 5;
//    }
    newShare = y2 ? 1 - y1 / y2 : 0.5
    }
  else if (this.child_share < 0) {
//  console.log('x', this, event, event.x, this.Width());
    newShare = (event.clientX || event.x)/this.Width();
    }
  else {
    console.log(this.id, 'SplitDrop', event, this.child_share, 'no children');
    return;
    }
  this.children[0].SettingsSet('pane', newShare);
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
//console.log(this.id,'Synch',is_update?'update':'no-update',no_fetch?'no-fetch':'fetch');
  var content, newt, tourney;
  if (this.children) {
    this.children[0].Synch(is_update, no_fetch);
    this.children[1].Synch(is_update, no_fetch);
    }
  error('checking for updates');
  if (no_fetch || this.Parent()) {
    tourney = this.tourney;
    }
  else {
    content = this.tourney ? this.pfu.FetchCached() : this.pfu.FetchDirect();
    if (content) eval(content); else {
      error('server sent null response');
      return false;
      }
    if (newt) this.SetTourney(tourney = newt); else {
      error('server reply did not contain tournament data');
      this.tourney = undefined;
      return false;
      }
    if (this.message && (tourney.esb.message.text != gCachedESBMsgText || tourney.esb.message.mode != gCachedESBMsgMode)) {
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

ScoreBoard.prototype.TagName = function(p, optionsp) {
  if (!optionsp) optionsp = {};
  var sbStyle = this.SettingsGet('style');
  var name = PlayerScoreboardName(p);
  var is_chinese = PlayerTeam(p).match(/^(?:HKG|MYS|SGP|TWN)$/) && name.match(/ .* /);
  var is_thai = p.xthai;
  var container = optionsp.container || 'div';
  var subcontainer = optionsp.subcontainer || 'span';
  var rv;
  var anchorClose = '';
  var anchorOpen = '';
  var linkUrl = '';
  if (optionsp.linked) {
    if (this.SettingsGet('dispatcher')) {
      anchorOpen = '<a href="' + this.SettingsGet('dispatcher') + 
	'?root=' + this.SettingsGet('root') +
	'&dispatcher=' + this.SettingsGet('dispatcher') +
	'&division=' + this.SettingsGet('division') +
	'&offset=' + (p.id-1) +
	'&columns=1&rows=1&style=card&order=id' +
	'">';
      anchorClose = '</a>';
      }
    else if (this.SettingsGet('selflink')) {
      anchorOpen = '<a href="' + window.location.pathname + 
	'?selflink=' + this.SettingsGet('selflink') +
	'&division=' + this.SettingsGet('division') +
	'&offset=' + (p.id-1) +
	'&columns=1&rows=1&style=card&order=id' +
	'">';
      anchorClose = '</a>';
      }
    }
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

  rv = name.match(/^(.*?), (.*?)(?:, (.*))?$/); if (rv && rv.length > 2 && rv[3]) { rv[1] += ', ' + rv[3]; }
  var after_id = '';
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
    if ((sbStyle != 'compact') && rv) {
      var surname1 = rv[1];
      var surname2 = rv[2];
      if (surname2.length < surname1.length + given.length) {
	given = given+' '+surname1 + "-";
	surname = surname2;
	}
      }

    given = given.replace(/:[ACLS][AM]\d\d\d\d\d\d$/, '<span class=naspaid>$&</span>');

    if (optionsp.show_id) {
      var classn = this.has_classes ? '<' + subcontainer + ' class=class_sep>/</' + subcontainer + '>' +
	'<' + subcontainer + ' class=class_name>' + PlayerClass(p) + '</' + subcontainer + '>' : '';
      var idclass = '<' + subcontainer + ' class=id>' + p.id + '</' + subcontainer + '>' + classn;
      var dname = TournamentCountDivisions(this.tourney) > 1 ? this.SettingsGet('division') : '#';
      dname = '<' + subcontainer + ' class=dname>' + dname + '</' + subcontainer + '>';
      if (optionsp.show_id == 'at-end' || sbStyle == 'compact') {
	after_id = '<' + subcontainer + ' class=end_id>(#' + idclass     + ')</' + subcontainer + '>';
	}
      else if (surname.length > given.length) {
	given   += '<' + subcontainer + ' class=dp> (' + dname + idclass + ')</' + subcontainer + '>';
	}
      else {
	surname += '<' + subcontainer + ' class=dp> (' + dname + idclass + ')</' + subcontainer + '>';
	}
      }
    name = '';
    if (container != 'none') name += "<" + container + " class=name>";
    name += anchorOpen;
    name += "<" + subcontainer + " class=given>" + given + "</" + subcontainer + ">"
      + "<" + subcontainer + " class=surname>" + surname + "</" + subcontainer + ">"
      + after_id;
    name += anchorClose;
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
      var classn = this.has_classes ? '<' + subcontainer + ' class=class_sep>/</' + subcontainer + '>' +
	'<' + subcontainer + ' class=class_name>' + PlayerClass(p) + '</' + subcontainer + '>' : '';
      var idclass = '<' + subcontainer + ' class=id>' + p.id + '</' + subcontainer + '>' + classn;
      var dname = TournamentCountDivisions(this.tourney) > 1 ? this.SettingsGet('division') : '#';
      dname = '<' + subcontainer + ' class=dname>' + dname + '</' + subcontainer + '>';
      if (optionsp.show_id == 'at-end' || sbStyle == 'compact') {
	after_id = '<' + subcontainer + ' class=end_id>(#' + idclass + ')</' + subcontainer + '>';
	}
      else {
	names.push('<' + subcontainer + ' class=dp> (' + dname + idclass + ')</' + subcontainer+ '>');
        }
      }
    if (names.length> 1 && split == 0) { split = 1; }
    if (name.length <= 12) { split = 0; }
    name = '';
    if (container != 'none') name += "<" + container + " class=name>";
    name += anchorOpen + 
      "<span class=given>" +
      names.slice(0,split).join(' ') +
      "</span><span class=surname>" +
      names.slice(split).join(' ') +
      "</span>" +
      after_id +
      anchorClose;
      "</" + container + ">";
    if (container != 'none') name += "</" + container + ">";
    }
  return name;
  }

// to be called every 0.05 s
ScoreBoard.prototype.Tick = function () {
//console.log(this.id,"Tick()", (new Date()).getTime()/1000);
  // if we are the root node and our timer has expired, reload data from the server
  if (this.reload_rate && !this.Parent()) {
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
  if ((!active) && this.SettingsGet('scroll_rate')) {
    if (this.scroll_count++ >= 200 / this.SettingsGet('scroll_rate')) {
      this.scroll_count = 0;
      var columns;
      if (this.SettingsGet('style') === 'compact') { columns = 1; }
      else { columns = this.SettingsGet('columns'); }
      // if we have reached the end of bottom of the list, start over at top
      if (this.SettingsGet('offset') + this.SettingsGet('rows') * columns >= this.ps.length) {
	this.SettingsSet('offset',0);
        }
      // else scroll down one rank
      else {
	this.SettingsIncrement('offset', 1);
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
    var ref = this.DOMReference();
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
//console.log('UpdateContent('+is_update+')');
  var i, j, op, out_of_the_money, p, po, ps, ref, r0;
  var closureThis = this;
  var tourney = this.tourney;
  if (!tourney) { return; } // not ready yet
  var dp = TournamentGetDivisionByName(tourney, this.SettingsGet('division'));

  this.dp = dp;
  if (!dp) { 
    // try renormalising in case we have a saved division from an earlier event
    this.SettingsSet('division', this.SettingsGet('division'));
    dp = TournamentGetDivisionByName(tourney, this.SettingsGet('division'));
    this.dp = dp;
    if (!dp) {
      alert('Cannot find division "'+this.SettingsGet('division')+'".');
      return; 
      }
    }
  DivisionSynch(dp, tourney);
  this.real_r1 = DivisionMaxRoundPlayed(dp);
  this.AdjustRound(0);
  r0 = this.r0;
  this.has_classes = DivisionClasses(dp);
  this.c_no_boards = (tourney.config.no_boards || '');
  this.is_capped = tourney.config.standings_spread_cap || tourney.config.spread_cap;
  this.thai_points = tourney.config.thai_points;
  this.c_has_tables = DivisionHasTables(dp, tourney.config);
  // ComputeRanks, ComputeRatings, ComputeSeeds are done in saveJSON.pm

  // ps will contain the player data in rank order
  // this.ps contains the player objects in display order
  ps = DivisionPlayers(dp);
  PlayerSpliceInactive(ps, 0, 0);
  switch(this.SettingsGet('order')) {
    case 'ranked':
      ps = this.is_capped ? PlayerSortByCappedStanding(r0, ps, tourney.config)
	: PlayerSortByStanding(r0, ps, tourney.config);
      break;
    case 'id':
      break;
    case 'board':
      ps.sort(function(a,b){
	return compare(closureThis.IsSecondaryPlayer(a) ? 1 : 0, closureThis.IsSecondaryPlayer(b) ? 1 : 0) ||
	compare(PlayerBoard(a,r0),PlayerBoard(b,r0)) ||
	compare(a.id,b.id);
      });
      break;
    }
  if (this.SettingsGet('order') == 'board') {
    this.StorePlayers(ps);
    for (i=0; i<this.ps.length; i++) {
      this.ps[i].Rerender(undefined, false, true);
      }
    this.UpdatePositions(true);
    }
  else if (is_update) {
    for (po=0; po<ps.length; po++) {
      p = ps[po];
      if (this.ps[po].data.id != p.id) {
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
      out_of_the_money = po + 1 >= dp.first_out_of_the_money[this.r0];
      out_of_the_money = ''; // temporarily disabled 2012-12-28
      this.ps[po].Rerender(po ? ps[po-1] : undefined, out_of_the_money);
      }
    this.UpdatePositions(true);
    }
  else {
    // rebuild all the player objects and store them in this.ps
    this.StorePlayers(ps);
    }
  this.RerenderNote();
  this.pmap = []; // maps player id to SBP structure
  for (i=0; i<this.ps.length; i++) {
    this.pmap[this.ps[i].data.id] = this.ps[i];
    }
  error(gTerms.data_loaded);
  }

ScoreBoard.prototype.UpdateControl = function(key) {
  var f = this.settingObjects[key];
  if (f) f.UpdateControl();
  }

ScoreBoard.prototype.UpdateControls = function(list) {
  var i;
  if (list) { for (i=0; i<list.length; i++) { this.UpdateControl(list[i]); } }
  else {
    for (i in this.settingObjects) {
      if (this.settingObjects.hasOwnProperty(i)) { this.UpdateControl(i); }
      }
    }
  }

// called to move all objects to their correct locations
ScoreBoard.prototype.UpdatePositions = function(animated) {
  this.UpdateProgress();
  // console.log(this.id, 'UpdatePositions', animated);
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

ScoreBoard.prototype.UpdateProgress = function() {
  var ref = document.getElementById(this.id + '_progress');
  if (ref) ref.innerHTML = this.RenderProgress();
  };

ScoreBoard.prototype.Width = function () { 
  if (this.Parent()) return this.DOMReference().offsetWidth;
  else return getWindowWidth();
  };

// TODO
//
// TIME PERMITTING
// In pairings mode, the two player boxes sometimes differ in width
// Font size adjustment should arguably not change title or control bar size?
// There is currently no way to select the current partial round in board view
// Should maybe have different geometries saved per style?
// team flag not positioned correctly in scorecard
// Splits should be persistent
// Store all the settings in one hierarchical localStorage item for easy manipulation/deletion
// Add a reset button
// Add a button to copy all the state into an URL
// URGENT
// need a dispatch URL setting, so that we can start linking players to it
// pairing tables look bad when too wide
// CRITICAL
