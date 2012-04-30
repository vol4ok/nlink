$.ns([ "test", "some-module", "SomeModule" ], function(exports) {
  var ClassA, Module1, data, f;
  callable1(123);
  call.able2();
  callable3();
  var a, b;
  a = 1;
  b = a + 2;
  console.log("__DEBUG__", a, b);
  data = '<div class="megadata">\n  <div class="test-1"></div>\n  <div class="test2"></div>\n</div>';
  Module1 = sm.module;
  var magavar = olololo;
  f = function() {
    console.log("ololo");
    setTimeout(function(a) {
      return console.log("olololololo");
    }, 1e3);
    return send({
      test1: "test_define",
      test2: 123,
      f: function(a) {
        return console.log("olololololo");
      }
    });
  };
  console.log("This is embedded code!");
  console.log("This is embedded code!");
  console.log("This is embedded code!");
  ClassA = function() {
    ClassA.name = "ClassA";
    ClassA.prototype.A = {
      test: 123,
      test2: "24234",
      test3: [ 1, 2, 3 ]
    };
    function ClassA() {
      this.method2 = $.bind(this.method2, this);
      this.method1 = $.bind(this.method1, this);
      var s, ss;
      ss = "test_define";
      s = ss + "test_define";
      f("test_define");
      this.temp = sm.module;
    }
    ClassA.prototype.method1 = function() {
      return this.Tmpl = function(c, p, i) {
        var _ = this;
        _.b(i = i || "");
        _.b("<!DOCTYPE html>");
        _.b("\n" + i);
        _.b("<html>");
        _.b("\n" + i);
        _.b("<head>");
        _.b("\n" + i);
        _.b('  <meta charset="utf-8">');
        _.b("\n" + i);
        _.b("  <title>sl2-amd</title>");
        _.b("\n" + i);
        _.b('  <script src="sm/main.js"></script>');
        _.b("\n" + i);
        _.b("</head>");
        _.b("\n" + i);
        _.b("<body>");
        _.b("\n" + i);
        _.b("  <h1>AUTHOR ");
        _.b(_.v(_.f("NAME", c, p, 0)));
        _.b("</h1>");
        _.b("\n" + i);
        _.b("  <h1>VERSION ");
        _.b(_.v(_.f("VERSION", c, p, 0)));
        _.b("</h1>");
        _.b("\n" + i);
        _.b("</body>");
        _.b("\n" + i);
        _.b("</html>");
        _.b("\n");
        return _.fl();
      };
    };
    ClassA.prototype.method2 = function() {
      this.a = [ 1, 2, 3, "a" ];
      if ($.indexOf.call(a, "a") >= 0) {
        return this.method1();
      }
    };
    return ClassA;
  }();
  $.inherit(exports, {
    ClassA: ClassA
  });
});