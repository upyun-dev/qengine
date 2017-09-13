# an example about ffi
module.exports =
  and: (args) -> """
    AND(
      #{args})
  """
  or: (args) -> """
    OR(
      #{args})
  """
  not: (arg) -> """
    NOT(
      #{arg})
  """
  xor: (args) -> """
    XOR(
      #{args})
  """

  eq: (column, value) -> "eq(#{column}, #{value})"
  neq: (column, value) -> "neq(#{column}, #{value})"
  gt: (column, value) -> "gt(#{column}, #{value})"
  lt: (column, value) -> "lt(#{column}, #{value})"
  gte: (column, value) -> "gte(#{column}, #{value})"
  lte: (column, value) -> "lte(#{column}, #{value})"
  like: (column, value) -> "like(#{column}, #{value})"
  null: (column) -> "null(#{column})"
