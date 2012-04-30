var View, viewOptions;

viewOptions = [ "el", "id", "attributes", "className", "tagName", "template" ];

View = function(_super) {
  __extends(View, _super);
  View.name = "View";
  View.prototype.cidPrefix = "view";
  View.prototype.eventSplitter = /^(\S+)\s*(.*)$/;
  View.prototype.tag = "div";
  function View(options) {
    var key, value;
    if (options == null) {
      options = {};
    }
    this.release = __bind(this.release, this);
    for (key in options) {
      value = options[key];
      if (__indexOf.call(viewOptions, key) >= 0) {
        this[key] = value;
      }
    }
    if (!this.el) {
      if (!this.el) {
        this.el = document.createElement(this.tag);
      }
      this.el = $(this.el);
      if (options.id) {
        this.el.attr("id", options.id);
      }
      if (this.className) {
        this.el.addClass(this.className);
      }
      if (this.attributes) {
        this.el.attr(this.attributes);
      }
    } else {
      this.el = $(this.el);
    }
    if (this.cid == null) {
      this.cid = options.id || this.el.attr("id") || $.uniqId(this.cidPrefix);
    }
    registerObject(this.cid, this);
    this.data = this.el.data() || {};
    this._initializeMixins();
    this._setupControllers(this.setup);
    this["import"](this.imports);
    this.delegateEvents(this.events);
    this.refreshElements(this.elements);
  }
  View.prototype.release = function(callback) {
    this.emit("release");
    return this.el.remove();
  };
  View.prototype.$ = function(selector) {
    return $(selector, this.el);
  };
  View.prototype.refreshElements = function(elements) {
    var key, value, _results;
    if (!elements) {
      return;
    }
    _results = [];
    for (key in elements) {
      value = elements[key];
      _results.push(this[key] = this.$(value));
    }
    return _results;
  };
  View.prototype.delegateEvents = function(events) {
    var eventName, key, match, method, selector, _results;
    if (!events) {
      return;
    }
    _results = [];
    for (key in events) {
      method = events[key];
      if (typeof method !== "function") {
        method = this.proxy(this[method]);
      }
      match = key.match(this.eventSplitter);
      eventName = match[1];
      selector = match[2];
      if (selector === "") {
        _results.push(this.el.on(eventName, method));
      } else {
        _results.push(this.el.delegate(selector, eventName, method));
      }
    }
    return _results;
  };
  return View;
}(Controller);