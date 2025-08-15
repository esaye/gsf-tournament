// Copyright © 2012 John J. Chew, III <poslfit@gmail.com>
// All Rights Reserved.

// class TSHWidgetRegistry

function TSHWidgetRegistry (argh) { "use strict";
  this.widgets = {};
  if (!argh) { return; }
  }

TSHWidgetRegistry.prototype.GetWidgetByName = function (name) { "use strict";
  return this.widgets[name]; 
  };

TSHWidgetRegistry.prototype.LoadWidgetsByClass = function (className) { "use strict";
  var i, l, list = getElementsByClass(className), widget, widgets = [];
  for (i=0, l=list.length; i<l; i++) {
    widget = new TSHWidget({'container':list[i], 'registry':this});
    widget.RenderInContainer(list[i]);
    widgets.push(widget);
    }
  };

TSHWidgetRegistry.prototype.ReadInputString = function () { "use strict";
  var inputs = [], name;
  for (name in this.widgets) {
    if (this.widgets.hasOwnProperty(name)) {
      inputs.push("'" + name + "':" + this.widgets[name].ReadInputString());
      }
    }
  return '{' + inputs.join(',') + '}';
  };

TSHWidgetRegistry.prototype.RegisterWidget = function (widget) { "use strict";
  var name = widget.Name();
  if (!name) { throw new Error('Cannot register unnamed widget.'); }
  this.widgets[name] = widget;
  };

TSHWidgetRegistry.prototype.Validate = function (checked) {
  var messages = [], name;
  for (name in this.widgets) {
    if (this.widgets.hasOwnProperty(name)) 
      { messages = messages.concat(this.widgets[name].Validate(checked)); }
    }
  return messages;
  }

// class TSHWidget

function TSHWidget (argh) { "use strict";
  if (!argh) { return; } // was called to create child prototype
  var arghName, arghReadInputString, arghRelated, arghType, arghValue, realThis = this;
  if (argh.container) {
    arghName = argh.container.getAttribute('tsh_widget_name');
    arghRelated = argh.container.getAttribute('tsh_widget_related');
    if (arghRelated) {
      if (arghRelated.substr(0,1) === '[') {
	try { arghRelated = eval(arghRelated); }
	catch (e) { throw new Error("Error evaluating arghRelated ('"+arghRelated+"'): "+e); }
	}
      else {
	arghRelated = [arghRelated];
	}
      }
    arghReadInputString = argh.container.getAttribute('tsh_widget_read_input_string');
    if (defined(arghReadInputString)) {
      try { arghReadInputString = eval(arghReadInputString) }
      catch (e) { throw new Error("Error evaluating arghReadInputString ('"+arghReadInputString+"'): "+e); }
      }
    arghType = argh.container.getAttribute('tsh_widget_type');
    if (arghType.substr(0,1) === '[') {
      try { arghType = eval(arghType); }
      catch (e) { throw new Error("Error evaluating arghType ('"+arghType+"'): "+e); }
      }
    else {
      arghType = [arghType,{}];
      }
    arghValue = argh.container.getAttribute('tsh_widget_value');
    if (arghValue.match(/^[-0-9\[\{']/)) {
      try { arghValue = eval('('+arghValue+')'); }
      catch (e) { throw new Error("Error evaluating arghValue ('"+arghValue+"'): "+e); }
      }
    }
  else {
    arghName = argh.name;
    arghReadInputString = argh.readInputString;
    arghRelated = argh.related;
    arghType = argh.type;
    arghValue = argh.value;
    }
  if (typeof(arghType) === 'string') { arghType = [arghType,{}]; }
  switch(arghType[0]) {
    case 'boolean': realThis = new TSHWidgetBoolean(argh); break; 
    case 'enum': realThis = new TSHWidgetEnum(argh); break;
    case 'hash': realThis = new TSHWidgetHash(argh); break; // not yet
    case 'hashpair': realThis = new TSHWidgetHashPair(argh); break; // not yet
    case 'float': realThis = new TSHWidgetFloat(argh); break;
    case 'integer': realThis = new TSHWidgetInteger(argh); break;
    case 'integerlist': realThis = new TSHWidgetIntegerList(argh); break;
    case 'list': realThis = new TSHWidgetList(argh); break;
    case 'localdirectory': realThis = new TSHWidgetFilePath(argh); break; 
    case 'string': realThis = new TSHWidgetString(argh); break; 
    default: throw new Error('Unknown widget type: '+arghType[0]);
    }
  if (argh.registry) { realThis.registry = argh.registry; }
  if (argh.parent) { realThis.parent = argh.parent; }
  if (defined(arghName)) { realThis.name = arghName; }
  if (arghReadInputString) { realThis.readInputString = arghReadInputString; }
  if (arghRelated) { realThis.related = arghRelated; }
  realThis.type = arghType[0];
  realThis.type_options = arghType[1] || {};
  if (defined(arghValue)) { realThis.value = arghValue; }
  if (argh.registry) {
    argh.registry.RegisterWidget(realThis);
    }
  return realThis;
  }

TSHWidget.AppendSubwidget = function(caller) { "use strict";
  var parentElement;
  for (parentElement = caller.parentNode;
    parentElement && !parentElement.tshWidget;
    parentElement = parentElement.parentNode) { }
  if (!parentElement) { throw new Error('cannot find widget to append to'); }
  parentElement.tshWidget.AppendChild();
  };

TSHWidget.prototype.Delete = function () { "use strict"; this.parent.DeleteChild(this); };

TSHWidget.DeleteSubwidget = function(caller) { "use strict";
  var elementToDelete;
  for (elementToDelete = caller.parentNode.firstChild;
    elementToDelete && !elementToDelete.tshWidget;
    elementToDelete = elementToDelete.nextSibling) { }
  if (!elementToDelete) { throw new Error('cannot find widget to delete'); }
  elementToDelete.tshWidget.Delete();
  caller.parentNode.parentNode.removeChild(caller.parentNode);
  };

TSHWidget.prototype.GetErrorElement = function () { "use strict"; return this.element.lastChild; };

TSHWidget.prototype.GetTypeOptionValue = function (key) { "use strict";
  var found;
  var value = this.type_options[key];
  if (this.registry) {
    if (defined(value)) {
      found = (''+value).match(/^\$([_0-9a-z]*)$/);
      if (found) {
	value = this.registry.GetWidgetByName(found[1]);
	if (value) { value = value.ReadInput(); }
	}
      }
    }
  return value;
  };

TSHWidget.prototype.Insert = function (referenceElement) { "use strict";
  this.parent.InsertChild(this, referenceElement);
  };

TSHWidget.InsertSubwidget = function(caller) { "use strict";
  var elementToInsertBefore;
  for (elementToInsertBefore = caller.parentNode.firstChild;
    elementToInsertBefore && !elementToInsertBefore.tshWidget;
    elementToInsertBefore = elementToInsertBefore.nextSibling) { }
  if (!elementToInsertBefore) { throw new Error('cannot find widget before which to insert'); }
  elementToInsertBefore.tshWidget.Insert(caller);
  };

TSHWidget.prototype.Name = function () { "use strict"; return this.name; };

TSHWidget.prototype.SetValue = function (value) { "use strict"; this.value = value; };

TSHWidget.prototype.StoreError = function (message) { "use strict";
  var errorElement = this.GetErrorElement();
  if (!errorElement.className.match(/error$/)) 
    { throw new Error(this.name+'('+this.type+') returned bad error element'); }
  if (message) {
    setText(errorElement, message);
    errorElement.className = 'error';
    }
  else {
    errorElement.className = 'hidden-error';
    setText(errorElement, '');
    }
  };

TSHWidget.prototype.StoreRenderedElement = function (element, container) { "use strict";
//error('storing '+this); error(element); error(container);
  this.element = element;
  element.tshWidget = this;
  if (this.name) { element.setAttribute('id', this.name); }
  container.innerHTML = '';
  container.appendChild(element);
  };

TSHWidget.prototype.toString = function () { "use strict";
  var s = [];
  if (defined(this.name)) { s.push('name:'+this.name); }
  if (defined(this.type)) { s.push('type:'+this.type); }
  return '[TSHWidget('+s.join(',')+')]';
  };

TSHWidget.prototype.Validate = function (checked) { "use strict";
  if (this.WasSeen(checked)) { return []; }
  var message;
  var messages = this.ValidateExtra(checked);
  var validator = this.type_options.validate;

  if (validator) {
    message = validator(this.ReadInput(), this, checked);
    if (defined(message) && message) { messages.push(message); }
    }
  this.StoreError(messages.join(' '));
  messages = messages.concat(this.ValidateRelated(checked));
  return messages;
  };

TSHWidget.prototype.ValidateExtra = function(checked) { "use strict"; return []; };

TSHWidget.prototype.ValidateRelated = function (checked) { "use strict";
  var i, messages = [], peer;
  if (!this.related) { return messages; }
  for (i = this.related.length-1; i>=0; i--) {
    peer = this.related[i];
    if (typeof(peer) === 'string') { peer = this.registry.GetWidgetByName(peer); }
    messages = messages.concat(peer.Validate(checked));
    }
  return messages;
  };

TSHWidget.prototype.WasSeen = function (hash) { "use strict";
  if (!hash) { throw new Error('WasSeen: needs a hash, not '+hash); }
  if (hash[getUniqueID(this)]) { return 1; }
  hash[getUniqueID(this)]=1;
  return 0;
  };

// class TSHWidgetCompound (parent for Hash and List)

function TSHWidgetCompound (argh) { "use strict"; if (!argh) { return; } }

TSHWidgetCompound.prototype = new TSHWidget();

TSHWidgetCompound.prototype.AppendChild = function () { "use strict";
  var esw = this.RenderSubwidget(), newElement, newSubwidget;
  if (!defined(esw)) { return; }
  newElement = esw[0];
  newSubwidget = esw[1];
  this.subwidgets.push(newSubwidget);
  this.element.insertBefore(newElement, this.element.lastChild);
  this.Validate({});
  };

TSHWidgetCompound.prototype.DeleteChild = function (child) { "use strict";
  var index = this.FindChild(child);
  this.subwidgets.splice(index, 1);
  this.Validate({});
  };

TSHWidgetCompound.prototype.FindChild = function (child) { "use strict";
  var i;
  for (i=this.subwidgets.length-1; i>=0; i--) {
    if (this.subwidgets[i] === child) { return i; }
    }
  throw new Error('Cannot find subwidget: '+child);
  };

TSHWidgetCompound.prototype.InsertChild = function (childWidget, referenceElement) { "use strict";
  var esw = this.RenderSubwidget();
  if (!defined(esw)) { return; }
  var index = this.FindChild(childWidget);
  var newElement = esw[0];
  var newSubwidget = esw[1];
  this.subwidgets.splice(index, 0, newSubwidget);
  this.element.insertBefore(newElement, referenceElement.parentNode);
  this.Validate({});
  };

TSHWidgetCompound.prototype.Validate = function (checked) { "use strict";
  var i, messages;
  if (this.WasSeen(checked)) { return []; }
  messages = this.ValidateExtra(checked);
  this.StoreError(messages.join(' '));
  messages = messages.concat(this.ValidateRelated(checked));
  for (i=this.subwidgets.length-1; i>=0; i--) 
    { messages = messages.concat(this.subwidgets[i].Validate(checked)); }
  return messages;
  };

// class TSHWidgetBoolean

function TSHWidgetBoolean (argh) { "use strict"; if (!argh) { return; } }

TSHWidgetBoolean.prototype = new TSHWidget();

TSHWidgetBoolean.prototype.ReadInput = function () { "use strict"; return this.element.firstChild.checked; };

TSHWidgetBoolean.prototype.ReadInputString = function () { "use strict";
  return this.readInputString ? this.readInputString(this.element.firstChild)
    : this.element.firstChild.checked ? 1 : 0;
  };

TSHWidgetBoolean.prototype.RenderInContainer = function (container) { "use strict";
  var checkboxElement;
  var divElement;
  var errorElement;
  var value;
  divElement = document.createElement('div');
  divElement.className = 'tshWidgetBoolean';
  checkboxElement = document.createElement('input');
  checkboxElement.type = 'checkbox';
  if (this.name) { checkboxElement.setAttribute('name', this.name); }
  value = this.value;
  if (!defined(value)) {
    if (defined(this.type_options.default_value)) { value = this.type_options.default_value; }
    }
  if (!defined(value)) { value = this.type_options.values[0]; }
  if (value) { checkboxElement.setAttribute('checked', 'checked'); }
  checkboxElement.setAttribute('onchange', 'this.parentNode.tshWidget.Validate({})');
  divElement.appendChild(checkboxElement);
  errorElement = document.createElement('span');
  errorElement.className = 'hidden-error';
  divElement.appendChild(errorElement);
  this.StoreRenderedElement(divElement, container);
  };

// class TSHWidgetEnum

TSHWidgetEnum.prototype = new TSHWidget();

function TSHWidgetEnum (argh) { "use strict"; if (!argh) { return; } }

TSHWidgetEnum.prototype.GetPossibleValues = function () { "use strict"; return this.type_options.values; };

TSHWidgetEnum.prototype.ReadInput = function () { "use strict"; return this.element.firstChild.value; };

TSHWidgetEnum.prototype.ReadInputString = function () {  "use strict";
  return this.readInputString ? this.readInputString(this.element.firstChild)
    : "'" + escapeSingleQuotes(this.element.firstChild.value) + "'"; 
  };

TSHWidgetEnum.prototype.RenderInContainer = function (container) { "use strict";
  var divElement;
  var errorElement;
  var i;
  var l;
  var optionElement;
  var optionValue;
  var selectElement;
  var value;
  divElement = document.createElement('div');
  divElement.className = 'tshWidgetEnum';
  selectElement = document.createElement('select');
  if (this.name) { selectElement.setAttribute('name', this.name); }
  value = this.value;
  if (!defined(value)) {
    if (defined(this.type_options.default_value)) { value = this.type_options.default_value; }
    }
  if (!defined(value)) { value = this.type_options.values[0]; }
  for (i = 0, l = this.type_options.values.length; i<l; i++) {
    optionElement = document.createElement('option');
    optionValue = this.type_options.values[i];
    optionElement.setAttribute('value', optionValue);
    if (optionValue == value) { optionElement.setAttribute('selected', 'selected'); }
    setText(optionElement, optionValue);
    selectElement.appendChild(optionElement);
    }
  selectElement.setAttribute('onchange', 'this.parentNode.tshWidget.Validate({})');
  divElement.appendChild(selectElement);
  errorElement = document.createElement('span');
  errorElement.className = 'hidden-error';
  divElement.appendChild(errorElement);
  this.StoreRenderedElement(divElement, container);
  };

// class TSHWidgetHashPair - one key-value pair from a hash

TSHWidgetHashPair.prototype = new TSHWidgetCompound();

function TSHWidgetHashPair (argh) { "use strict"; this.subwidgets = []; if (!argh) { return; } }

TSHWidgetHashPair.prototype.ReadInput = function () { "use strict";
  return [this.subwidgets.map(function (arg) { return arg.ReadInput(); })];
  };

TSHWidgetHashPair.prototype.ReadInputString = function () { "use strict";
  return this.readInputString ? this.readInputString()
    : this.subwidgets.map(function (arg) { return arg.ReadInputString(); }).join(':');
  };

TSHWidgetHashPair.prototype.RenderInContainer = function (container) { "use strict";
  this.subwidgets = [];
  var element, subwidget;
  var pairElement = document.createElement('div');
  pairElement.className = 'tshWidgetHashPair';
  element = document.createElement('div');
  element.className = 'tshWidgetHashPairKey';
  subwidget = new TSHWidget({
    'type':this.type_options.key,
    'parent':this,
    'related':[this],
    'value':this.value[0]
    });
  this.subwidgets.push(subwidget);
  subwidget.RenderInContainer(element);
  pairElement.appendChild(element);
  element = document.createElement('div');
  element.className = 'tshWidgetHashPairValue';
  subwidget = new TSHWidget({
    'type':this.type_options.value,
    'parent':this,
    'related':[this],
    'value':this.value[1]
    });
  this.subwidgets.push(subwidget);
  subwidget.RenderInContainer(element);
  pairElement.appendChild(element);
  element = document.createElement('span');
  element.className = 'hidden-error';
  pairElement.appendChild(element);
  this.StoreRenderedElement(pairElement, container);
  };

// class TSHWidgetHash

TSHWidgetHash.prototype = new TSHWidgetCompound();

function TSHWidgetHash (argh) { "use strict"; this.subwidgets = []; if (!argh) { return; } }

TSHWidgetHash.prototype.ReadInput = function () { "use strict";
  var i, hash, pair;
  for (i=this.subwidgets.length-1; i>=0; i--) {
    pair = this.subwidgets[i].ReadInput();
    hash[pair[0]] = pair[1];
    }
  return hash;
  };

TSHWidgetHash.prototype.ReadInputString = function () { "use strict";
  return this.readInputString ? this.readInputString()
    : '{' + this.subwidgets.map(function (arg) { return arg.ReadInputString(); }).join(',') + '}';
  };

TSHWidgetHash.prototype.RenderInContainer = function (container) { "use strict";
  this.subwidgets = [];
  var button, element, esw, key, subwidget;
  var listElement = document.createElement('div');
  listElement.className = 'tshWidgetHash';
  for (key in this.value) {
    esw = this.RenderSubwidget(key, this.value[key]);
    if (!defined(esw)) { continue; }
    element = esw[0];
    subwidget = esw[1];
    this.subwidgets.push(subwidget);
    listElement.appendChild(element);
    }
  element = document.createElement('div');
  element.className = 'append';
  button = document.createElement('input');
  button.className = 'insert';
  button.setAttribute('type', 'button');
  button.setAttribute('value', '\u2324');
  button.setAttribute('onclick', 'TSHWidget.AppendSubwidget(this)');
  element.appendChild(button);
  listElement.appendChild(element);
  element = document.createElement('span');
  element.className = 'hidden-error';
  listElement.appendChild(element);
  this.StoreRenderedElement(listElement, container);
  };

TSHWidgetHash.prototype.RenderSubwidget = function (key,value) { "use strict";
  var element = document.createElement('div'), i, key, keys = [], values;
  if (!defined(key)) { 
    if (this.type_options.default_value && typeof(this.type_options.default_value) === 'object') key = this.type_options.default_value[0]; 
    else {
      for (i=this.subwidgets.length-1; i>=0; i--) {
	key = this.subwidgets[i].subwidgets[0].ReadInput();
	keys[key] = 1;
	}
      key = undefined;
//    console.log(this.type_options.key[0]);
      if (this.type_options.key[0] === 'integer') {
	key = this.type_options.key[1].low || 0;
	while (keys[key]) { key++; }
        }
      if (this.type_options.key[0] === 'enum') {
	for (i=0, values=this.type_options.key[1].values; i<values.length; i++) {
	  if (!keys[values[i]]) { key = values[i]; break; }
	  }
	if (!defined(key)) { return undefined; } // all enums in use
        }
      }
    }
  if (!defined(value)) { 
    if (this.type_options.default_value && typeof(this.type_options.default_value) === 'object') value = this.type_options.default_value[1]; 
    }
  var subwidget = new TSHWidget({
      'type':['hashpair',{
        'key':this.type_options.key,
        'value':this.type_options.value
        }],
      'parent':this,
      'related':[this],
      'value':[key,value]
      });
  element.className = 'element';
  subwidget.RenderInContainer(element);
  var button = document.createElement('input');
  button.setAttribute('type', 'button');
  button.setAttribute('value', '\u232b');
  button.setAttribute('onclick', 'TSHWidget.DeleteSubwidget(this)');
  element.appendChild(button);
  return [element, subwidget];
  };

TSHWidgetHash.prototype.ValidateExtra = function (checked) { "use strict";
  var i;
  var key;
  var keys = {};
  var messages = [];
  for (i=this.subwidgets.length-1; i>=0; i--) {
    key = this.subwidgets[i].subwidgets[0].ReadInput();
    if (keys[key]) { keys[key]++; } else { keys[key] = 1; }
    }
  for (key in keys) {
    if (keys[key] > 1) { messages.push("'"+key+"' is a duplicate key."); }
    }
  return messages;
  };

// class TSHWidgetList

TSHWidgetList.prototype = new TSHWidgetCompound();

function TSHWidgetList (argh) { "use strict"; if (!argh) { return; } this.subwidgets = []; }

TSHWidgetList.prototype.ReadInput = function () { "use strict";
  return this.subwidgets.map(function (arg) { return arg.ReadInput(); });
  };

TSHWidgetList.prototype.ReadInputString = function () { "use strict";
  return this.readInputString ? this.readInputString()
    : '[' + this.subwidgets.map(function (arg) { return arg.ReadInputString(); }).join(',') + ']';
  };

TSHWidgetList.prototype.RenderInContainer = function (container) { "use strict";
  this.subwidgets = [];
  var button, element, esw, i, l, subwidget;
  var listElement = document.createElement('div');
  listElement.className = 'tshWidgetList';
  switch(typeof(this.value)) {
    case 'string': this.value = [this.value]; break;
    case 'undefined': this.value = []; break;
    }
  for (i=0, l=this.value.length; i<l; i++) {
    esw = this.RenderSubwidget(this.value[i]);
    if (!defined(esw)) { continue; }
    element = esw[0];
    subwidget = esw[1];
    this.subwidgets.push(subwidget);
    listElement.appendChild(element);
    }
  element = document.createElement('div');
  element.className = 'append';
  button = document.createElement('input');
  button.className = 'append';
  button.setAttribute('type', 'button');
  button.setAttribute('value', '\u2324');
  button.setAttribute('onclick', 'TSHWidget.AppendSubwidget(this)');
  element.appendChild(button);
  listElement.appendChild(element);
  element = document.createElement('span');
  element.className = 'hidden-error';
  listElement.appendChild(element);
  this.StoreRenderedElement(listElement, container);
  };

TSHWidgetList.prototype.RenderSubwidget = function (value) { "use strict";
  var element = document.createElement('div');
  var subwidget = new TSHWidget({
//    'registry':this.registry,
//    'name':this.name + '_' + i,
      'value':value,
      'type':this.type_options.value,
      'parent':this,
      'related':[this]
      });
  element.className = 'element';
  subwidget.RenderInContainer(element);
  var button = document.createElement('input');
  button.setAttribute('type', 'button');
  button.setAttribute('value', '\u232b');
  button.setAttribute('onclick', 'TSHWidget.DeleteSubwidget(this)');
  element.appendChild(button);
  button = document.createElement('input');
  button.className = 'insert';
  button.setAttribute('type', 'button');
  button.setAttribute('value', '\u2324');
  button.setAttribute('onclick', 'TSHWidget.InsertSubwidget(this)');
  element.insertBefore(button, element.firstChild);
  return [element, subwidget];
  };

// class TSHWidgetString

TSHWidgetString.prototype = new TSHWidget();
TSHWidgetString.prototype.className = 'TSHWidgetString';
TSHWidgetString.prototype.cssClass = 'tshWidgetString';
TSHWidgetString.prototype.defaultValue = '';

function TSHWidgetString (argh) { "use strict"; if (!argh) { return; } }

TSHWidgetString.Filter = function (el) { "use strict";
  var widget = el.parentNode.tshWidget;
  var userFilter = widget.type_options.filter;
  var value = userFilter ? userFilter(el.value, el) : el.value;
  setTextField(el, value);
  widget.Validate({});
  return false;
  };

TSHWidgetString.prototype.GetMaxLength = function () { "use strict";
  return this.type_options.maxlength || 40;
  };

TSHWidgetString.prototype.GetSize = function () { "use strict";
  return this.type_options.size || 40;
  };

TSHWidgetString.prototype.ReadInput = function () { "use strict"; return this.element.firstChild.value; };

TSHWidgetString.prototype.ReadInputString = function () {  "use strict";
  return this.readInputString ? this.readInputString(this.element.firstChild)
    : "'" + escapeSingleQuotes(this.element.firstChild.value) + "'"; 
  };

TSHWidgetString.prototype.RenderInContainer = function (container) { "use strict";
  var divElement = document.createElement('div');
  var element = document.createElement('input');
  var value = this.value;
  divElement.className = this.cssClass;
  if (this.name) { element.setAttribute('name', this.name); }
  if (!defined(value)) 
    { if (defined(this.type_options.default_value)) { value = this.type_options.default_value; } }
  if (!defined(value)) { value = this.defaultValue; }
  element.setAttribute('value', value);
  element.setAttribute('maxlength', this.GetMaxLength());
  element.setAttribute('size', this.GetSize());
  element.setAttribute('type', 'text');
  element.setAttribute('onkeyup', this.className + '.Filter(this)');
  divElement.appendChild(element);
  element = document.createElement('span');
  element.className = 'hidden-error';
  divElement.appendChild(element);
  this.StoreRenderedElement(divElement, container);
  };

// class TSHWidgetFilePath

TSHWidgetFilePath.prototype = new TSHWidgetString();
TSHWidgetFilePath.prototype.className = 'TSHWidgetFilePath';
TSHWidgetFilePath.prototype.cssClass = 'tshWidgetFilePath';
TSHWidgetFilePath.prototype.defaultValue = '';

function TSHWidgetFilePath (argh) { "use strict"; if (!argh) { return; }}

// overrides string filter 
TSHWidgetFilePath.Filter = function (el) { "use strict";
  var sign = '';
  var widget = el.parentNode.tshWidget;
  var userFilter = widget.type_options.filter;
  var value = userFilter ? userFilter(el.value, el) : el.value;
  value = value.replace(/[^-_0-9a-zA-Z\/]/g, '');
  setTextField(el, value);
  widget.Validate({});
  return false;
  };

// class TSHWidgetFloat

TSHWidgetFloat.prototype = new TSHWidgetString();
TSHWidgetFloat.prototype.className = 'TSHWidgetFloat';
TSHWidgetFloat.prototype.cssClass = 'tshWidgetFloat';
TSHWidgetFloat.prototype.defaultValue = '0';

function TSHWidgetFloat (argh) { "use strict"; if (!argh) { return; }}

// overrides string filter 
TSHWidgetFloat.Filter = function (el) { "use strict";
  var sign = '';
  var widget = el.parentNode.tshWidget;
  var userFilter = widget.type_options.filter;
  var value = userFilter ? userFilter(el.value, el) : el.value;
  if (value.length === 0) {
    el.value = '0';
    el.select();
    widget.Validate({});
    return false;
    }
  if (value.substring(0,1) === '-') {
    sign = '-';
    value = value.substring(1);
    }
  if (value.length === 0) {
    el.value = '0';
    el.select();
    widget.Validate({});
    return false;
    }
  value = value.replace(/[^.0-9]/g, '');
  while (value.match(/\..*\./)) { value = value.replace(/\./, ''); }
  value = sign + value;
  setTextField(el, value);
  widget.Validate({});
  return false;
  };

// overrides string version
TSHWidgetFloat.prototype.ReadInputString = function () { "use strict";
  return this.readInputString ? this.readInputString(this.element.firstChild)
    : this.element.firstChild.value; 
  };

TSHWidgetFloat.prototype.ValidateExtra = function (checked) { "use strict";
  var high = this.type_options.high;
  var low = this.type_options.low;
  var messages = [];
  var value = this.ReadInput();

  if (defined(value) && value.length) {
    value = +value;
    if (defined(low) && value < +low) { messages.push('Value must be at least '+low+'.'); }
    if (defined(high) && value > +high) { messages.push('Value must be at most '+high+'.'); }
    }
  return messages;
  };

// class TSHWidgetInteger

TSHWidgetInteger.prototype = new TSHWidgetString();
TSHWidgetInteger.prototype.className = 'TSHWidgetInteger';
TSHWidgetInteger.prototype.cssClass = 'tshWidgetInteger';
TSHWidgetInteger.prototype.defaultValue = '0';

function TSHWidgetInteger (argh) { "use strict"; if (!argh) { return; }}

// overrides string filter to accept only characters valid in integers
TSHWidgetInteger.Filter = function (el) { "use strict";
  var sign = '';
  var widget = el.parentNode.tshWidget;
  var userFilter = widget.type_options.filter;
  var value = userFilter ? userFilter(el.value, el) : el.value;
  if (value.length === 0) {
    el.value = '0';
    el.select();
    widget.Validate({});
    return false;
    }
  if (value.substring(0,1) === '-') {
    sign = '-';
    value = value.substring(1);
    }
  if (value.length === 0) {
    el.value = '0';
    el.select();
    widget.Validate({});
    return false;
    }
  value = sign + value.replace(/[^0-9]/g,'');
  setTextField(el, value);
  widget.Validate({});
  return false;
  };

// overrides string version to compute value based on valid range
TSHWidgetInteger.prototype.GetMaxLength = function () { "use strict";
  var high = this.type_options.high, low = this.type_options.low;
  if (defined(low) && defined(high)) 
    { return Math.max((''+low).length, (''+high).length) }
  return 10;
  };

// overrides string version to compute value based on valid range
TSHWidgetInteger.prototype.GetSize = function () {
  return this.GetMaxLength();
  };

// overrides string version to not wrap value in quotes
TSHWidgetInteger.prototype.ReadInputString = function () { "use strict";
  return this.readInputString ? this.readInputString(this.element.firstChild)
    : this.element.firstChild.value; 
  };

TSHWidgetInteger.prototype.ValidateExtra = function (checked) { "use strict";
  var high = this.GetTypeOptionValue('high');
  var low = this.GetTypeOptionValue('low');
  var messages = [];
  var value = this.ReadInput();

  if (defined(value) && value.length) {
    value = +value;
    if (defined(low) && value < +low) { messages.push('Value must be at least '+low+'.'); }
    if (defined(high) && value > +high) { messages.push('Value must be at most '+high+'.'); }
    }
  return messages;
  };

// class TSHWidgetIntegerList

TSHWidgetIntegerList.prototype = new TSHWidgetString();
TSHWidgetIntegerList.prototype.className = 'TSHWidgetIntegerList';
TSHWidgetIntegerList.prototype.cssClass = 'tshWidgetIntegerList';
TSHWidgetIntegerList.prototype.defaultValue = '0';

function TSHWidgetIntegerList (argh) { "use strict"; if (!argh) { return; }}

// overrides string filter 
TSHWidgetIntegerList.Filter = function (el) { "use strict";
  var sign = '';
  var widget = el.parentNode.tshWidget;
  var userFilter = widget.type_options.filter;
  var low = defined(widget.type_options.low) ? 
    widget.type_options.low : -1;
  var value = userFilter ? userFilter(el.value, el) : el.value;
  value = value.replace(low < 0 ? /[^-,0-9]/g : /[^,0-9]/g,'');
  // TODO: could do more here
  value = value.replace(/---*/g, '-');
  if (value.length === 0) {
    el.value = '0';
    el.select();
    widget.Validate({});
    return false;
    }
  setTextField(el, value);
  widget.Validate({});
  return false;
  };

// overrides string version 
TSHWidgetIntegerList.prototype.ReadInput = function () { "use strict";
  return this.element.firstChild.value.split(/,/).map(
    function(x){return +x;}); 
  };

// overrides string version 
TSHWidgetIntegerList.prototype.ReadInputString = function () { "use strict";
  return '[' + (this.readInputString ?
    this.readInputString(this.element.firstChild) :
    this.element.firstChild.value) + ']'; 
  };

TSHWidgetIntegerList.prototype.ValidateExtra = function (checked) { "use strict";
  var high = this.type_options.high,
      i,
      low = this.type_options.low,
      messages = [],
      value,
      values = this.ReadInput();

  if (defined(low)) { low = +low; }
  if (defined(high)) { high = +high; }
  for (i = values.length-1; i>=0; i--) {
    value = values[i];
    if (value < +low) 
      { messages.unshift('Value '+value+' must be at least '+low+'.'); }
    if (value > +high) 
      { messages.unshift('Value '+value+' must be at most '+high+'.'); }
    }
  return messages;
  };

// TODO
//
// - Internationalize all messages
