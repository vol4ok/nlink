var ClassA, Module1, data, f;

callable1(123);

call.able2();

callable3();

data = __TEMPLATE("index.html");

Module1 = sm.module;

f = function() {
  return console.log("ololo");
};

ClassA = function() {
  ClassA.name = "ClassA";
  ClassA.prototype.A = __PRECOMPILE(function() {
    return {
      test: 123,
      test2: "24234",
      test3: [ 1, 2, 3 ]
    };
  });
  function ClassA() {
    this.method2 = $.bind(this.method2, this);
    this.method1 = $.bind(this.method1, this);
    this.temp = sm.module;
  }
  ClassA.prototype.method1 = function() {
    return this.Tmpl = __TEMPLATE("index.mu");
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