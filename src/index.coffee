{ BinaryLogicalOp } = require "./node"

# 由于采用 JSON 对象表示法, 可以省略 tokenize 过程, 直接得到词法分析结果.
class Parser
  constructor: (token, @ffi) ->
    @root = new BinaryLogicalOp "$and", token, null, null

  # 构造语法树 (句法分析 & 语法语义检查)
  parse: -> @root.parse()

  # 语义分析 & 中间代码生成
  gen_code: (tree) -> (tree ? @parse()).gen @ffi

module.exports = Parser