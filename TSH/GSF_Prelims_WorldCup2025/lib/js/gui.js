var t;
var gAJAXError;
var gDname;
var gMode;
var gPid;
var gRound;
var gTerms;

function CancelEdit(e) {
  var edite = e.parentNode;
  var dispe = edite.previousSibling;
  if (dispe) {
    dispe.style.display = 'block';
    edite.style.display = 'none';
    }
  }

function ClickToEdit (e) {
  if (e.nextSibling) {
    e.style.display = 'none';
    e.nextSibling.style.display = 'block';
    e.nextSibling.firstChild.focus();
    }
  }

function FindFirstPending (dname, round) {
  var dp = TournamentGetDivisionByName(t, dname);
  var ps = DivisionPlayers(dp);
  for (var pi=0; pi<ps.length; pi++) {
    var p = ps[pi];
    if (!defined(PlayerScore(p, round-1))) {
      gDname = dname;
      gPid = PlayerID(p);
      return 1;
      }
    }
  return 0;
  }

function Initialise (newt) {
  t = newt;
  TournamentSynch(t);
  gTerms = ConfigTerminology(t.config, { 
    '1st':[],
    '2nd':[],
    'Board':[],
    'EditScorecardTopNote':[],
    'Lost':[],
    'Opp_No':[],
    'OpponentName':[],
    'Opp_Rating':[],
    'Opp_Score':[],
    'Player_Score':[],
    'Round':[],
    'RoundP12':[],
    'Spread':[],
    'Table':[],
    'vs':[],
    'Won':[] 
    });
  if (navigator.userAgent.match(/iPhone|iPod/i)) {
    window.addEventListener('load', function () {
      setTimeout(scrollTo, 0, 0, 1);
      }, false);
    }
  }

function KeydownAny(argh) {
  if (!argh.ev) argh.ev = window.event;
  var code;
  if (argh.ev.keyCode) code = argh.ev.keyCode;
  else if (argh.ev.which) code = argh.ev.which;
  if (!code) return [argh.ev, code, true];
  if (code == 27) CancelEdit(argh.el);
  else if (code == 13) { 
    argh.saver(argh.el, argh.dname, argh.editpid, (argh.round||0));
    ViewPlayer(argh.dname, argh.viewpid);
    return [argh.ev, code, false];
    }
//else alert(code);
  return [argh.ev, code, undefined];
  }

function KeydownName(ev, el, dname, editpid, viewpid) {
  var rv = KeydownAny({'ev':ev, 'el':el, 'dname':dname, 'editpid':editpid, 'viewpid':viewpid,'saver':SavePlayerNameChange});
  ev = rv[0];
  var code = rv[1];
  if (defined(rv[2])) return rv[2];
  return true;
  }

function KeydownP12(ev, el, dname, editpid, viewpid, round) {
  var rv = KeydownAny({'ev':ev, 'el':el, 'dname':dname, 'editpid':editpid, 'round': round, 'viewpid':viewpid,'saver':SavePlayerP12Change});
  ev = rv[0];
  var code = rv[1];
  if (defined(rv[2])) return rv[2];
  return true;
  }

function KeydownRating(ev, el, dname, editpid, viewpid) {
  var rv = KeydownAny({'ev':ev, 'el':el, 'dname':dname, 'editpid':editpid, 'viewpid':viewpid,'saver':SavePlayerRatingChange});
  ev = rv[0];
  var code = rv[1];
  if (defined(rv[2])) return rv[2];
  return true;
  }

function KeydownScores(ev, el, dname, editpid, viewpid, round) {
  var rv = KeydownAny({'ev':ev, 'el':el, 'dname':dname, 'editpid':editpid, 'round': round, 'viewpid':viewpid,'saver':SavePlayerScoresChange});
  ev = rv[0];
  var code = rv[1];
  if (defined(rv[2])) return rv[2];
  return true;
  }

function NextPlayer () {
  var dps = TournamentDivisions(t);
  var dOffset;
  // find division number from name
  for (var di=0; di<dps.length; di++) {
    var dp = dps[di];
    if (DivisionName(dp) == gDname) {
      dOffset = di;
      break;
      }
    }
  // unknown division defaults to first
  if (!defined(dOffset)) {
    alert('assertion failed (1)');
    dOffset = 0;
    }
  for (var di=0; di<dps.length; di++) {
    var dp = dps[(di+dOffset)%dps.length];
    if (DivisionLeastScores(dp) >= gRound) continue;
    if (FindFirstPending(DivisionName(dp), gRound)) return;
    }
  if (gRound < DivisionMaxRound0(dp)+1) {
    gRound++;
    NextPlayer();
    }
  else {
    alert('All scores have been entered.');
    var dp = TournamentGetDivisionByName(t, gDname);
    if (gPid == DivisionCountPlayers(dp)) gPid = 1;
    else gPid++;
    }
  }

function PlayerLink (p, dname, config, extra) {
  var anchor = '<a href="#" onclick="ViewPlayer(\''+dname+"',"+PlayerID(p)+');return false">';
  return (config.player_photos ? Div('photo',anchor+RenderPlayerPhoto(p)+'</a>') : '')
    + Div('name','&nbsp;'+anchor+PlayerPrettyName(p, config)+'</a>')
    + extra;
  }

function ReloadData() {
  var pfu = new PoslFetchURL(TrimURL(window.location.href) + '?a=json');
  newt = undefined;
  var rv = pfu.FetchDirect();
  try { eval(rv); }
  catch(err) { alert("Unexpected AJAX error ("+err+"): "+rv); return err; }
  if (newt) { 
    Initialise(newt);
    return '';
    }
  else { 
    var error = "Could not reload data, please try again.";
    alert(error);
    return error;
    }
  }

function RenderAttributeFunction (fname, usethis, argv) {
/* if ((!defined(argv)) || !argv.map) console.log(RenderAttributeFunction.caller); */
  var args = argv.map(function (el) { return "'"+escape(el)+"'" } )
  if (usethis) {
    if (typeof(usethis) == 'object') {
      args = [].concat(usethis, args);
      }
    else args.unshift('this');
    }
  return fname+'('+args.join(',')+')';
  }

function RenderCancelButton () {
  return RenderTextButton('&#8856;', 'cancelbutton', 'CancelEdit(this)');
  }

function RenderEditableCell (classname, value) {
  return Div(classname, value, 'onclick="ClickToEdit(this);return false"') 
  }

function RenderEditCell (argh) {
  var ClassName = ucfirst(argh.classname);
  var KeydownName = ucfirst(argh.keydown||argh.classname);
  return Div(argh.classname + ' edit',
    HTMLInputText({
      'name': argh.classname,
      'value': argh.value,
      'size': argh.size,
      'maxlength': argh.maxlength,
      'onkeydown': 'return '
        + RenderAttributeFunction('Keydown' + KeydownName, ['event','this'],
	  [argh.dname, argh.oid, argh.pid, (argh.round||0)])})
    + RenderSaveButton(RenderAttributeFunction('SavePlayer'+ClassName+'Change',
      true, [argh.dname, argh.oid, (argh.round||0)])
      + '||' 
      + RenderAttributeFunction('ViewPlayer', false, [argh.dname, argh.pid]))
    + RenderCancelButton(),
    'style="display:none"'
    );
  }

function RenderP12 (p, r0) {
  var p12 = PlayerFirst(p, r0);
  if (p12 == 1) return gTerms['1st'];
  if (p12 == 2) return gTerms['2nd'];
  return '?';
  }

function RenderPlayer (dname, pid, config) {
  gMode = 'player'; gDname = dname; gPid = pid;
  var dp = TournamentGetDivisionByName(t, dname);
  var p = DivisionPlayer(dp, pid);
  var config = t.config;
  var has_photos = config.player_photos;
  var has_ratings = DivisionRatingSystem(dp) != 'none'; 
  var no_boards = config.no_boards;
  var show_teams = config.show_teams;
  var has_tables = DivisionHasTables(dp, config);
  var spread_entry = config.entry == 'spread';
  var track_firsts = config.track_firsts;

  var html = '';

  var classes = ['scorecard'];
  if (has_photos) classes.push('has_photos');
  if (has_ratings) classes.push('has_ratings');
  if (has_tables) classes.push('has_tables');
  else if (!no_boards) classes.push('has_boards');
  if (!spread_entry) classes.push('has_scores');
  if (show_teams) classes.push('has_teams');
  if (track_firsts) classes.push('track_firsts');
  var max_round0 = DivisionMaxRound0(dp);
  var max_round1 = defined(max_round0) ? max_round0 + 1
    : Math.max(PlayerCountOpponents(p), PlayerCountScores(p));
  var rounds = '';
  for (var r1=1; r1<=max_round1; r1++) {
    var r0 = r1-1;
    var opp = PlayerOpponent(p, r0, dp); // could be undefined if oid is bad
    var score = PlayerScore(p, r0);
    var p12 = PlayerFirst(p, r0);
    if (!defined(p12)) p12 = 4;
    var oid = PlayerOpponentID(p, r0);
    var bort = '';
    if (has_tables || !no_boards) {
      bort = PlayerBoard(p, r0) || '';
      if (bort && has_tables) bort = DivisionBoardTable(dp, bort, config);
      }
    var onum = '&nbsp;';
    var orat = '&nbsp;';
    var onam = '&nbsp;';
    var won = '&nbsp;';
    var lost = '&nbsp;';
    var oscore = '&nbsp;';
    var spread = '&nbsp;';
    var cume = '&nbsp;';
    if (opp) {
      var repeats = PlayerCountRoundRepeats(p, opp, r0);
      repeats = repeats > 1 ? '*' + repeats : '';
      onum = PlayerID(opp);
      orat = PlayerRating(opp);
      onam = PlayerLink(opp, dname, config, repeats);
      }
    else if (defined(oid)) {
      onam = 'bye';
      }
    if (defined(score)) {
      spread = score;
      oscore = PlayerScore(opp, r0);
      if (defined(oscore)) spread -= oscore; else oscore = '&nbsp;';
      spread = UtilityFormatHTMLSignedInteger(spread);
      cume = UtilityFormatHTMLSignedInteger(PlayerRoundSpread(p, r0));
      won = UtilityFormatHTMLHalfInteger(PlayerRoundWins(p, r0));
      lost = UtilityFormatHTMLHalfInteger(PlayerRoundLosses(p, r0));
      }
    else score = '&nbsp;';
    rounds += Div('rdata',
      Div('round', r1) 
      + (track_firsts ? RenderEditableCell('p12', 
	'<span class='+['m','y','n','m','m'][p12]+'>1st</span>' 
	+ ' <span class='+['m','n','y','m','m'][p12]+'>2nd</span>' 
	) + RenderEditCell({
	  'classname':'p12', 'keydown':'p12', 'round': r1,
	  'value': p12, 'dname': dname, 'oid': pid, 'pid': pid, 
	  'size':1, 'maxlength':1
        }): '')
      + (defined(oid)
	? (has_tables ? Div('table', bort) : !no_boards ? Div('board', bort) : '')
	: (has_tables ? Div('table', '&nbsp;') : !no_boards ? Div('board', '&nbsp;') : '')
	)
      + Div('onum', onum)
      + (has_ratings 
	? RenderEditableCell('orat', orat)
	  + RenderEditCell({'classname':'orat', 'keydown':'rating', 'value':orat,
	    'dname':dname, 'oid':oid, 'pid': pid, 'size':4, 'maxlength':4})
	: '')
      + Div('onam', onam)
      + Div('won', won)
      + Div('lost', lost)
      + (spread_entry ? '' 
	: RenderEditableCell('scores',
	    Div('for', score) + Div('against', oscore))
	  + RenderEditCell({'classname':'scores','keydown':'scores',
	    'value':score+'-'+oscore, 'oid':pid, 'pid':pid, 'round':r1,
	    'dname':dname, 'size':9, 'maxlength':9})
	)
      + Div('spread', spread)
      + Div('cume', cume)
      );
    }

  var pname = PlayerPrettyName(p, config);
  var prat = PlayerRating(p);
  html += 
    Div('topnote noprint', gTerms.EditScorecardTopNote)
    + Div(classes.join(' '),
      Div('header',
	Div('id', '<a href="#" onclick="ViewRosters();return false">'+PlayerFullID(p, dp, t)+'</a>')
	+ (has_photos ? Div('photo', RenderPlayerPhoto(p)) : '')
	+ RenderEditableCell('name', pname)
	  + RenderEditCell({'classname':'name', 'value':pname,
	    'dname':dname, 'oid':pid, 'pid': pid, 'size':24, 'maxlength':80})
	+ (show_teams ? Div('team', PlayerTeam(p)) : '')
	+ (has_ratings 
	  ? RenderEditableCell('rating', prat)
	    + RenderEditCell({'classname':'rating', 'value':prat,
	      'dname':dname, 'oid':pid, 'pid': pid, 'size':4, 'maxlength':4})
	  : '')
	)
      + Div('titles',
	Div('round',track_firsts ? gTerms.RoundP12 : gTerms.Round)
	+ (has_tables ? Div('table', gTerms.Table) : !no_boards ? Div('board', gTerms.Board) : '')
	+ Div('onum',gTerms.Opp_No)
	+ (has_ratings ? Div('orat', gTerms.Opp_Rating) : '')
	+ Div('onam',gTerms.OpponentName)
	+ Div('won',gTerms.Won)
	+ Div('lost',gTerms.Lost)
	+ (spread_entry ? '' : Div('scores',Div('for', gTerms.Player_Score) + Div('against', gTerms.Opp_Score)))
	+ Div('spread',gTerms.Spread)
	)
      + Div('rounds', rounds)
      );

  return html;
  }

function RenderPlayerPhoto (p, attrs) {
  if (defined(attrs) && attrs.length) attrs = ' ' + attrs; else attrs = '';
  return '<img class=head src="/' 
    + p.photo
    + '" alt="[head shot]"' + attrs + '>';
  }

function RenderPopupMenu (argh) {
  return '<select name="'+argh.name+'" '
    + (argh.values.length > 1 ? 'onchange' : 'onclick')
    + '="'+argh.onchange+'">'+
    argh.values.map(function (el) { 
      return '<option'+
        (el==argh['default'] ? ' selected="selected"' : '')+
	' value="'+el+'">'+
        (argh.labels ? argh.labels[el] : el) +
        "</option>\n";
      }).join('')
    +'</select>';
  }

function RenderRoster () {
  return TournamentCountDivisions(t) > 1
    ? RenderRosterMultiDivision()
    : RenderRosterMultiDivision();
//  : RenderRosterSingleDivision();
  }

function RenderRosterMultiDivision () {
  var colps = [];
  var dps = TournamentDivisions(t);
  var html = '<table class=roster>';
  for (var di=0; di<dps.length; di++) {
    var dp = dps[di];
    var dname = DivisionName(dp);
    var colp = [];
    var ps = DivisionPlayers(dp);
    for (var pi=0; pi<ps.length; pi++) {
      var p = ps[pi];
      var pname = PlayerName(p);
      var pid = PlayerID(p);
      colp.push(['<td>'
	+ ' <a href="#" onclick="console.log(this.href);return false" class=noprint>&#9998;</a>'
	+ ' ' + dname
	+ ' ' + pid
	+ ' <a href="#" onclick="ViewPlayer(\''+dname+'\','+pid+');return false">' + pname +'</a>'
	+ '</td>', pname, dname, pid
	]);
      }
    colps.push(colp);
    }
  for (var row = 0; ; row++) {
    var found = 0;
    var rowhtml = '';
    for (var col = 0; col < colps.length; col++) {
      var cell = colps[col][row];
      if (cell) { found++; rowhtml += cell[0]; }
      else rowhtml += '<td>&nbsp;</td>';
      }
    if (found) html += '<tr>' + rowhtml + '</tr>';
    else break;
    }
  html += '</table>';
  return html;
  }

function RenderRosterSingleDivision () {
  return 'not yet';
  }

function RenderSaveButton (onclick, style) {
  return style == 'gui' ?
    '<input type=submit value="&#10003;" onclick="'+onclick+';return false" />'
    : RenderTextButton('&#10003;', 'savebutton', onclick);
  }

function RenderTextButton (label, classname, onclick) {
/*return html = '<input type=button value="'+escape(label)
    + '" onclick="'+onclick+';return false" />'; */
  return '<span class="'+classname+'" onclick="'+onclick+';return false"/>'+label+'</span>';
  }

function RenderValet (argh) {
//console.log('dname: '+argh.dname); console.log('pid: '+argh.pid); console.log('round: '+argh.round);
  var dp = TournamentGetDivisionByName(t, argh.dname);
  var p = DivisionPlayer(dp, argh.pid);
  var track_firsts = t.config.track_firsts;
  var pid = PlayerID(p);
  var ps = DivisionPlayers(dp);
  if (!argh.round) argh.round = 1;
  var r0 = argh.round - 1;
  var o = PlayerOpponent(p, r0, dp);
  var entered = [];
  var pending = [];
  var found = 0;
  for (var pi=0; pi<ps.length; pi++) {
    var ap = ps[pi];
    var apid = PlayerID(ap);
    var oid = PlayerOpponentID(ap, r0);
    if (!defined(oid)) continue;
    if (track_firsts) { if (PlayerFirst(ap, r0) == 2) continue; }
    else { if (apid < oid) continue; }
    if (pid == apid) found = 1;
    if (defined(PlayerScore(ap, r0))) entered.push(ap);
    else pending.push(ap);
    }
  if ((!found) && o) { var tmp = o; o = p; p = tmp; pid = PlayerID(p); }
  entered.sort(function (a,b) { return compare(PlayerBoard(a,r0),PlayerBoard(b,r0)) });
  pending.sort(function (a,b) { return compare(PlayerBoard(a,r0),PlayerBoard(b,r0)) });
  return '<form onsubmit="ValetSubmit(this);return false;">'+Div('valet',
    Div('round', Div('label', 'Round') +Div('menu',
      RenderPopupMenu({
	'name':'round',
	'default':argh.round,
	'values':Range(1,(t.config.max_rounds||1)),
	'onchange':'ViewValet(undefined,undefined,this.value);return false'
	})))
    +Div('division', Div('label', 'Division') +Div('menu',
      RenderPopupMenu({
	'name':'division',
	'default':argh.dname,
	'values':TournamentDivisions(t).map(function(d){return DivisionName(d)}),
	'onchange':'gPid=undefined;ViewValet(this.value,undefined,undefined);return false'
	})))
    +RenderValetPopup(entered, 'entered', r0, dp, entered.length && PlayerID(p))
    +RenderValetPopup(pending, 'pending', r0, dp, pending.length && PlayerID(p))
    +Div('scores',
      RenderValetScore(p, r0, 'player p1', dp)
      +(o ? RenderValetScore(o, r0, 'player p2', dp) : ''))
    +RenderValetButtons(DivisionName(dp), pid, argh.round)
    )+'</form>';
  }

function RenderValetButtons (dname, pid, round) {
  return Div('buttons',RenderSaveButton(
//  'alert(1);'+
    RenderAttributeFunction('SavePlayerScores2Change', true, [dname, pid, round])
      +'||(ReloadData(),NextPlayer(),ViewValet())',
    'gui'
    ));
  }

function RenderValetPopup(data, label,r0, dp, defaultValue) {
  var dname = DivisionName(dp);
  return Div(label,
    Div('label',ucfirst(label))
    +(data.length
      ? Div('menu', RenderPopupMenu({
	'name':label,
	'default':defaultValue,
	'values':data.map(function(el){return PlayerID(el)}),
	'labels':ValetLabels(data, r0, dp),
	'onchange':'ViewValet(undefined,this.value);return false'
	}))
      :Div('none', '&nbsp;(none)')
	));
  }

function RenderValetScore(p, r0, className, dp) {
  var config = t.config;
  var extra = '';
  if (config.track_firsts) extra += Div('p12', RenderP12(p, r0));
  var dname = DivisionName(dp);
  extra += ' ' + Div('record', '&nbsp;'+UtilityFormatHTMLHalfInteger(PlayerWins(p, r0)) 
    + '&ndash;' 
    + UtilityFormatHTMLHalfInteger(PlayerLosses(p, r0))
    + '&nbsp;'
    + UtilityFormatHTMLSignedInteger(PlayerSpread(p, r0)));
  var next_oid = PlayerOpponentID(p, r0+1);
  if (defined(next_oid)) {
    extra += Div('next', Div('label','&#x2192; ') + (next_oid 
	  ? Div('where', RenderP12(p, r0+1) + '@'
	    + PlayerBort(p, r0, dp, config) + ' '
	    + gTerms.vs) + ' ' +
  	    PlayerLink(DivisionPlayer(dp, next_oid), dname, config, '') : 'bye'));
    }
  var label = PlayerLink(p, dname, config, extra);
  return Div(className,
    Div('label', label)
    +Div('input', HTMLInputText({'name':'score', 'pattern':'[0-9]*', 'value':PlayerScore(p, r0), 'size':4, 'maxlength':4 }))
    );
  }

function SaveChange(url) {
  var pfu = new PoslFetchURL(url);
  var rv = pfu.FetchDirect();
  gAJAXError = undefined;
  try { eval(rv); }
  catch(err) { alert("Unexpected AJAX error ("+err+"): "+rv); if (!gAJAXError) gAJAXError = err; }
  if (!defined(gAJAXError) || gAJAXError != '') { alert(gAJAXError); return gAJAXError; }
  return ReloadData();
  }

function SavePlayerP12Change(el, dname, pid, round) {
  return SaveChange(TrimURL(window.location.href) + '?a=set12&v='+escape(el.parentNode.firstChild.value)+'&d='+escape(dname)+'&p='+escape(pid)+'&r='+escape(round));
  }

function SavePlayerNameChange(el, dname, pid, round) {
  return SaveChange(TrimURL(window.location.href) + '?a=setname&v='+escape(el.parentNode.firstChild.value)+'&d='+escape(dname)+'&p='+escape(pid));
  }

function SavePlayerRatingChange(el, dname, pid, round) {
  return SaveChange(TrimURL(window.location.href) + '?a=setrating&v='+escape(el.parentNode.firstChild.value)+'&d='+escape(dname)+'&p='+escape(pid));
  }

function SavePlayerScoresChange(el, dname, pid, round) {
  return SaveChange(TrimURL(window.location.href) + '?a=setscores&v='+escape(el.parentNode.firstChild.value)+'&d='+escape(dname)+'&p='+escape(pid)+'&r='+escape(round));
  }

function SavePlayerScores2Change(el, dname, pid, round) {
  var scoresNode = el.parentNode.previousSibling;
  return SaveChange(TrimURL(window.location.href) 
    + '?a=setscores&v='
    + escape(scoresNode.firstChild.lastChild.lastChild.value
      + '-'
      + scoresNode.lastChild.lastChild.lastChild.value)
    +'&d='+escape(dname)+'&p='+escape(pid)+'&r='+escape(round));
  }

function TrimURL(url) {
  return url.replace(/[#?].*/, '');
  }

function ValetLabels (ps, r0, dp) {
  var labels = {};
  var has_tables = DivisionHasTables(dp, t.config);
  for (var pi=0; pi<ps.length; pi++) {
    var p = ps[pi];
    var bort = PlayerBort(p, r0, dp, t.config);
    var o = PlayerOpponent(p, r0, dp);
    labels[PlayerID(p)] = o 
      ? bort + '. ' + PlayerTaggedName(p, '', dp, t) + "&ndash;" + PlayerTaggedName(o, '', dp, t)
      : PlayerTaggedName(p, '', dp, t) + " (bye)";
    }
  return labels;
  }

function ValetSubmit () {
  alert(2);
  alert(el);
  asfaskfasf();
  SavePlayerScores2Change(el, gDname, gPid, gRound);
  NextPlayer();
  ViewValet();
  }

function ViewPlayer (dname, pid) {
  var ref = document.getElementById('gui_content');
  if (ref) ref.innerHTML = RenderPlayer(dname, pid, t.config);
  }

function ViewRosters () {
  var ref = document.getElementById('gui_content');
  if (ref) ref.innerHTML = RenderRoster();
  }

function ViewValet (dname, pid, round) {
  var ref = document.getElementById('gui_content');
  if (dname) gDname = dname; else if (gDname) dname = gDname; else dname = gDname = TournamentDivisions(t)[0].name;
  if (round) gRound = round; else if (gRound) round = gRound; else round = gRound = DivisionLeastScores(dp) + 1;
  if (pid) gPid = pid; else if (gPid) pid = gPid; else pid = gPid = FindFirstPending(dname, round);
  var dp = TournamentGetDivisionByName(t, dname);
  var p = DivisionPlayer(dp, pid);
  console.log('VV:'+dname+pid+'/'+round);
  if (ref) ref.innerHTML = RenderValet({'dname':dname, 'pid':pid, 'round':round});
  }
