var Application;

Application = function(_super) {
  $.inherit(Application, _super);
  Application.name = "Application";
  Application.prototype._initAutoloadObjects = function(classList) {
    var _this = this;
    return $(".autoload").each(function(i, _el) {
      var el, _ref, _ref1;
      try {
        el = $(_el);
        el.removeClass("autoload");
        new (getClassByName(el.data("class")))({
          el: _el
        });
      } catch (exc) {
        console.error("Could not initialize a view with class: " + ((_ref = _el.id) != null ? _ref : "undefined") + " and id: " + ((_ref1 = _el["data-class"]) != null ? _ref1 : "undefined") + ". " + exc.toString());
      }
    });
  };
  function Application(options) {
    var _this = this;
    if (options == null) {
      options = {};
    }
    Application.__super__.constructor.apply(this, arguments);
    $.on("load", function() {
      return _this._initAutoloadObjects();
    });
  }
  return Application;
}(Controller);