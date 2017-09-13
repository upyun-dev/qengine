ffi = require "./ffi"
{ BinaryLogicalOp } = require "./node"
util = require "./util"

# 由于采用 JSON 对象表示法, 可以省略 tokenize 过程, 直接得到词法分析结果.
# 构造语法树 (句法分析 & 语法语义检查)
class Parser
  TAB_STR: ' '.repeat 4

  constructor: (token, ffi = global.ffi) ->
    @ffi = ffi
    @root = new BinaryLogicalOp "$and", token, null, null
  
  parse: -> @root.parse()
  gen_code: -> @root.parse().gen @ffi

# 语义分析 & 中间代码生成
# class SemanticAnalysis

#   constructor: (@tree) ->
#     @ffi = global.ffi
#     @query_code = @analyze @tree
#   output: ->
#     _tmp_ffi = @ffi
#     @ffi = internal_ffi
#     o = @analyze @tree
#     @ffi = _tmp_ffi
#     o

# setup_ffi = (ffi) => global.ffi = ffi

module.exports = Parser