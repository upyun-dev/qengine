// Generated by CoffeeScript 2.0.0-beta2
(function() {
  module.exports = {
    and: function(...args) {
      return `AND(\n  ${args}\n)`;
    },
    or: function(...args) {
      return `OR(\n  ${args}\n)`;
    },
    not: function(arg) {
      return `NOT(\n  ${arg}\n)`;
    },
    xor: function(...args) {
      return `XOR(\n  ${args}\n)`;
    },
    eq: function(column, value) {
      return `eq(${column}, ${value})`;
    },
    neq: function(column, value) {
      return `neq(${column}, ${value})`;
    },
    gt: function(column, value) {
      return `gt(${column}, ${value})`;
    },
    lt: function(column, value) {
      return `lt(${column}, ${value})`;
    },
    gte: function(column, value) {
      return `gte(${column}, ${value})`;
    },
    lte: function(column, value) {
      return `lte(${column}, ${value})`;
    },
    like: function(column, value) {
      return `like(${column}, ${value})`;
    },
    null: function(column) {
      return `null(${column})`;
    }
  };

}).call(this);