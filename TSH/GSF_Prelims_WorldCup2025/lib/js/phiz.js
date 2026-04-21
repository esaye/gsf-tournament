// poslfit's social commenting system
// requires JQuery 1.5

var undefined;
if (!window.console) window.console = {};
if (!window.console.log) window.console.log = function () { };

function defined (x) { var y; return x !== y; }
function Log (s) { if (defined(console) && console.log) console.log('Phiz: '+s); }
function LogObject (o) { if (console && console.log) console.log(o); }
function HTMLEncode (s) { return s.replace(/&/,'&amp;').replace(/</,'&lt;').replace(/>/,'&gt;').replace(/"/,'&quot;'); }

// varname: name of phiz variable, for ease of DOM callbacks
// - TODO: it would probably be prettier to assign closures as event handlers after storing the HTML
// object_class: DOM class of phiz objects to use
function Phiz (varname,object_class) {
  this.logged_in = 0;
  // TODO: think about whether we ought to track all object modtimes and not just newest
  this.modtime = undefined;
  this.object_ids = []; // list of DOM/Phiz IDs of phiz objects
  this.permissions = '';
  this.realname = undefined;
  this.timeout = undefined;
  this.username = undefined;
  this.url = '/cgi-bin/phiz.pl';
  this.varname = varname;
  this.FindObjects(object_class);
  }

Phiz.prototype.AddComment = function (id) {
  var ta = $('#ta'+id);
  Log('AddComment('+id+')');
  if (!ta.val().match(/\S/)) {
    alert("Please enter a comment first in the text box below the Save button.");
    return;
    }
//alert(ta.val());
  this.Fetch({'post':id});
// Log(ta.val());
// alert('add '+id+' '+ta.serialize());
  };

Phiz.prototype.ChangePassword = function (id) {
  var oldp = $('#cpfo'+id).val();
  var newp = $('#cpfn'+id).val();
  var newa = $('#cpfna'+id).val();
  if (newp == '') {
    alert('Please enter a nonempty username and password.');
    return;
    }
  if (newp != newa) {
    alert('Please enter exactly the same new password twice.');
    return;
    }
  this.Fetch({'newpw':newp, 'oldpw':oldp, 'active':id});
  };

Phiz.prototype.ChangePasswordCancel = function (id) {
  $('#cpf'+id).hide();
  $('#cpb'+id).show();
  };

Phiz.prototype.ChangePasswordShow = function (id) {
  $('#cpb'+id).hide();
  $('#cpf'+id).show();
  };

Phiz.prototype.DeleteComment = function (tid,cid) {
  Log('DeleteComment('+tid+','+cid+')');
  this.Fetch({'delete':tid,'comment':cid});
  };

Phiz.prototype.Fetch = function (phiz_argh) {
  var thisphiz = this;
  if (this.timeout) { 
    clearTimeout(this.timeout);
    this.timeout = undefined;
    }
  var ajax_argh = {};
  ajax_argh.t = this.object_ids.join(',');
  // log on if requested
  if (defined(phiz_argh.username)) {
    ajax_argh.u = phiz_argh.username;
    ajax_argh.p = phiz_argh.password;
    ajax_argh.at = phiz_argh.active;
    }
  if (defined(phiz_argh.post)) {
    ajax_argh.at = phiz_argh.post;
    ajax_argh.nc = $('#ta'+phiz_argh.post).val();
    }
  if (defined(phiz_argh['delete'])) {
    ajax_argh.at = phiz_argh['delete'];
    ajax_argh.di = phiz_argh.comment;
    }
  if (defined(phiz_argh.newpw)) {
    ajax_argh.np = phiz_argh.newpw;
    ajax_argh.op = phiz_argh.oldpw;
    ajax_argh.at = phiz_argh.active;
    }
  // ask for changes since modtime if known
  if (defined(this.modtime)) ajax_argh.s = this.modtime;
  $.ajax(this.url,
    {
    'data': ajax_argh,
    'dataType': 'json',
    'success': function (data, textStatus, jqXHR) { 
      Log('ajax('+this.url+'): ' + textStatus);
      LogObject(data);
      thisphiz.Fetched(data); 
      },
    'error': function (jqXHR, textStatus, error) {
      Log('ajax('+thisphiz.url+'): ' + textStatus);
      alert('error loading '+thisphiz.url+': '+textStatus);
      },
    'type':'POST'
    });
  };

Phiz.prototype.Fetched = function (data) {
  this.username = data.u;
  this.realname = data.r;
//Log('username: '+this.username);
  if (data.l) {
    this.logged_in = 1;
    this.permissions = data.p;
    }
  else {
    this.logged_in = 0;
    this.permissions = undefined;
    }
  if (defined(data.t)) {
    var thisphiz = this;
    $.each(this.object_ids, function () {
      thisphiz.ReceiveObject(this, data.t[this]);
      });
    }
//  if (defined(data.m)) { // new data has arrived
//    var thisphiz = this;
//    $.each(this.object_ids, function () {
//      thisphiz.ReceiveObject(this, data.e, data.t[this]);
//      });
//    }
//  else { Log('No new data since: '+this.modtime); }
  if (!this.timeout) this.timeout = setTimeout(function () { thisphiz.Fetch({}); }, 5*60*1000);
  };

// stores a list of IDs of objects of the given class,
// makes all the objects display a 'loading...' message
Phiz.prototype.FindObjects = function (object_class) {
  var thisphiz = this;
  thisphiz.object_ids = [];
  // make a list of phiz object ids
  $('.' + object_class).each(function(index) {
    thisphiz.object_ids.push($(this).attr("id"));
    $(this).html('<div class=loading>Comment system loading...</div>');
    });
  };

Phiz.prototype.Login = function (id) {
  var username = $('#lifu'+id).val();
  var password = $('#lifp'+id).val();
  if (username == '' || password == '') {
    alert('Please enter a nonempty username and password.');
    return;
    }
  this.Fetch({'username':username, 'password':password, 'active':id});
  };

Phiz.prototype.LoginCancel = function (id) {
  $('#lif'+id).hide();
  $('#lib'+id).show();
  };

Phiz.prototype.LoginShow = function (id) {
  $('#lib'+id).hide();
  $('#lif'+id).show();
  };

Phiz.prototype.LogOut = function (id) {
  this.Fetch({'username':'', 'password':'', 'active':id});
  };

Phiz.prototype.ReceiveObject = function (id, item_data) {
  if (!item_data) {
    Log('ReceiveObject('+id+'): empty item data');
    }
  this.ChangePasswordCancel(id);
  if (item_data.e) {
    var errp = $('#err'+id);
    LogObject(errp);
    if (errp.length) {
      errp.html(item_data.e);
      errp.show();
      if (!item_data.c) {
	Log('updated error object to show: '+item_data.e);
	return;
        }
      }
    }
  if (item_data.m) {
    if (item_data.m == 'nc') {
      Log('ReceiveObject('+id+'): no change');
      return;
      }
    else {
      if (item_data.m > this.modtime) {
	this.modtime = item_data.m;
        Log('ReceiveObject('+id+'): changed at '+item_data.m);
        }
      }
    }
  var s = '';
  s += '<form>';
  var thisphiz = this;
//Log('ReceiveObject('+id+')');
  if (item_data.c && item_data.c.length) $.each(item_data.c, function () {
    s += '<div class=comment><span class=head>' +
      '<span class=author>' + this.au + '</span>' +
      '<span class=created>' + new Date(this.ct) + '</span>';
    if (thisphiz.logged_in && thisphiz.realname == this.au) {
      s += thisphiz.RenderControls('span', [{ 'label':'Delete',
	'click_function':'DeleteComment', 'click_args':id+"','"+this.ci }])
      }
    s += '</span>';
    s += '<span class=text>' + this.tx + '</span>';
    s += '</div>';
    });
  s += '<div class=error id="err'+id+'"'+
    (item_data.e ? '' : ' style="display:none"')+
    '>'+(item_data.e||'')+'</div>';
  s += '<span class=foot>';
  if (thisphiz.logged_in) {
    s += '<div class=comment><span class=head>';
    s += '<span class=author>' + thisphiz.realname + '</span>';
    s += '<span class=created>now</span>';
    s += thisphiz.RenderControls('span', [{
      'a_class':'add', 'span_class':'add',
      'click_function':'AddComment', 'click_args':id,
      'label':'Save'
      }])
    s += '</span>';
    var old_text = $('#ta'+id).val();
    if (!defined(old_text)) old_text = '';
    s += '<textarea name="ta'+id+'" id="ta'+id+'" rows="4" cols="80">'+HTMLEncode(old_text)+'</textarea>';
    s += '<div class=controls>';
    s += this.RenderButton({'label':'Log out', 'click_function':'LogOut', 'click_args': id});
    s += '<span id="cpb'+id+'">';
    s += this.RenderButton({ 'label':'Change Password',
      'click_function':'ChangePasswordShow', 'click_args':id });
    s += '</span>';
    s += '<span id="cpf'+id+'" style="display:none">';
    s += '<span class=labtxt><label for="cpfo'+id+
      '">Old Password</label><input type="password" id="cpfo'+id+'" /></span>';
    s += '<span class=labtxt><label for="cpfn'+id+
      '">New Password</label><input type="password" id="cpfn'+id+'" /></span>';
    s += '<span class=labtxt><label for="cpfna'+id+
      '">New Password Again</label><input type="password" id="cpfna'+id+'" /></span>';
    s += this.RenderButton({ 'label':'Change Password',
      'click_function':'ChangePassword', 'click_args':id });
    s += this.RenderButton({ 'label':'Cancel',
      'click_function':'ChangePasswordCancel', 'click_args':id });
    s += '</span>';
    s += '</div>';
    }
  else {
    var hide_button = '';
    var hide_form = '';
    if (thisphiz.username == '') {
      hide_form = ' style="display:none"';
      }
    else {
      hide_button = ' style="display:none"';
      }
    s += '<div class=controls>';
    s += '<span id="lib'+id+'"' + hide_button + '>';
    s += this.RenderButton({ 'label':'Log in to comment',
      'click_function':'LoginShow', 'click_args':id });
    s += '</span>';
    s += '<span id="lif'+id+'"' + hide_form + '>';
    s += '<span class=labtxt><label for="lifu'+id+'">Username</label><input type="text" value="'+HTMLEncode(thisphiz.username)+'" id="lifu'+id+'" /></span>';
    s += '<span class=labtxt><label for="lifp'+id+'">Password</label><input type="password" id="lifp'+id+'" /></span>';
    s += this.RenderButton({ 'label':'Log in to comment',
      'click_function':'Login', 'click_args':id });
    s += this.RenderButton({ 'label':'Cancel',
      'click_function':'LoginCancel', 'click_args':id });
    s += '</span>';
    s += '</div>';
    }
//if (error != '')  s += '<div class=error>' + error + '</div>';
  s += '</span>'; // foot
  s += '</form>';
//Log('ReceiveObject('+id+'): '+s);
//Log($('#'+id));
  $('#'+id).html(s);
  };

Phiz.prototype.RenderButton = function (argh) {
  var a_class = defined(argh.a_class) ? ' class="'+argh.a_class+'"' : '';
  var a_onclick = defined(argh.click_function) ?
    ' onclick="' + this.varname + '.' + argh.click_function + '(\'' + argh.click_args + '\')"' : '';
  var span_class = defined(argh.span_class) ? ' class="button '+argh.span_class+'"' : ' class=button';
  var label = defined(argh.label) ? argh.label : 'Unlabelled Button';
  return '<a' + a_class + a_onclick +  '>' + 
    '<span' + span_class + '>' + label + '</span>' +
    '</a>';
  };

Phiz.prototype.RenderControls = function (container, argv) {
  var thisphiz = this;
  return '<' + container + ' class=controls>' +
    $.map(argv, function (elt,ind) { return thisphiz.RenderButton(elt); }).join('') +
    '</' + container + '>';
  };

