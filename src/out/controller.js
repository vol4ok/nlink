var Controller;

Controller = function(_super) {
  __extends(Controller, _super);
  Controller.name = "Controller";
  Controller.include($.EventEmitter.prototype);
  Controller.prototype.cidPrefix = "ctr";
  function Controller(options) {
    var _ref, _this = this;
    if (this.cid == null) {
      this.cid = (_ref = options != null ? options.cid : void 0) != null ? _ref : $.uniqId(this.cidPrefix);
    }
    registerObject(this.cid, this);
    this._setupControllers(this.setup);
    $.on("loaded", function() {
      _this["import"](_this.imports);
      return _this.delegateEvents(_this.events);
    });
  }
  Controller.prototype.delegateEvents = function(events) {
    var event, method, src, srcObj, t, trg, trgObj, _ref, _ref1, _results;
    if (!events) {
      return;
    }
    _results = [];
    for (src in events) {
      trg = events[src];
      _ref = (t = src.split(" ")).length === 1 ? [ this, t[0] ] : [ $$(t[0]), t[1] ], srcObj = _ref[0], event = _ref[1];
      _ref1 = (t = trg.split(" ")).length === 1 ? [ this, t[0] ] : [ $$(t[0]), t[1] ], trgObj = _ref1[0], method = _ref1[1];
      _results.push(srcObj.on(event, trgObj[method]));
    }
    return _results;
  };
  Controller.prototype._setupControllers = function(controllers) {
    var ctx, id, _results;
    if (!controllers) {
      return;
    }
    _results = [];
    for (id in controllers) {
      ctx = controllers[id];
      ctx[1].cid = id;
      _results.push(new (getClassByName(ctx[0]))(ctx[1]));
    }
    return _results;
  };
  Controller.prototype["import"] = function(imports) {
    var id, name, _i, _len, _results, _results1;
    if (!imports) {
      return;
    }
    if ($.isArray(imports)) {
      _results = [];
      for (_i = 0, _len = imports.length; _i < _len; _i++) {
        id = imports[_i];
        _results.push(this[$.camelize(id)] = $$(id));
      }
      return _results;
    } else {
      _results1 = [];
      for (name in imports) {
        id = imports[name];
        _results1.push(this[name] = $$(id));
      }
      return _results1;
    }
  };
  return Controller;
}(Module);