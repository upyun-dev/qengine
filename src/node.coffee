lo = require 'lodash'
NODE_TYPE = require "./type"
{ UNARY_LOGICAL_OPS, UNARY_RELATION_OPS, BINARY_LOGICAL_OPS, BINARY_RELATION_OPS } = require "./op"

# 语法树节点
# @token - 节点包含的原始值
# @name - 节点标识符
# @value - 节点属性
# @type - 节点类型
# @parent - 父节点
# @children - 子节点数组
# @related_field_name - 关联的域
class AstNode
  constructor: (name, token, parent, related_field_name) ->
    @token = token
    @name = name
    @parent = parent
    @children = []
    @related_field_name = related_field_name

  # 判断子节点类型，递归下降生成子节点
  # 返回当前节点
  parse: ->
    # 叶节点
    if @is_leaf @token
      @next Leaf, null, @token
    # else if @is_leaf_grp @token
    #   @next Leaf, null, token for token in @token
    else if lo.isEmpty @token
    # 空节点
      throw SyntaxError "the #{@type} missing child node"
    else
    # 非叶结点
      for name, token of @token
        N = @detect_node_type name, token
        @next N, name, token
    @

  next: (Node, name, token) ->
    @syntax_check Node, name, token
    @semantic_check Node, name, token
    @children.push new Node(name, token ? null, @, @related_field_name).parse()

  semantic_check: (Node, name, token) ->
  syntax_check: (Node, name, token)->
    # 子类型错误，语法错误
    if Node::type not in @child_type
      throw new SemanticError """
        invalid Node => [name: #{name}, token: #{JSON.stringify token}, type: #{Node::type}],
        the accepted child type of the parent [name: #{@name}, token: #{JSON.stringify @token}, type: #{@type}] must be included in #{@child_type}
      """

  detect_node_type: (name, token) ->
    switch
      when @is_urop name then UnaryRelationOp
      when @is_brop name then BinaryRelationOp
      when @is_ulop name then UnaryLogicalOp
      when @is_blop name then BinaryLogicalOp
      when @is_op name then throw new SyntaxError "the operator `#{name}` doesn't implement in the current FFI"
      else Field

  is_leaf: (token) -> lo.isString(token) or lo.isNumber(token) or lo.isBoolean(token) or not token?
  # is_leaf_grp: (token) ->
  #   isArray token
  is_urop: (name) -> name in UNARY_RELATION_OPS
  is_ulop: (name) -> name in UNARY_LOGICAL_OPS
  is_brop: (name) -> name in BINARY_RELATION_OPS
  is_blop: (name) -> name in BINARY_LOGICAL_OPS
  is_op: (name) -> name.startsWith "$"

# class Root extends AstNode
#   type: NODE_TYPE.BINARY_LOGICAL_OPERATOR
#   child_type: [NODE_TYPE.FIELD, NODE_TYPE.UNARY_LOGICAL_OPERATOR, NODE_TYPE.UNARY_RELATION_OPERATOR, NODE_TYPE.BINARY_RELATION_OPERATOR, NODE_TYPE.BINARY_LOGICAL_OPERATOR]
#   constructor: (token) ->
#     super "$and", token, null, null
#     @value = "and"

class Field extends AstNode
  type: NODE_TYPE.FIELD
  child_type: [NODE_TYPE.LEAF, NODE_TYPE.UNARY_LOGICAL_OPERATOR, NODE_TYPE.BINARY_LOGICAL_OPERATOR, NODE_TYPE.BINARY_RELATION_OPERATOR]
  constructor: (name, token, parent, related_field_name) ->
    super name, token, parent, related_field_name
    @token = $eq: token if @is_leaf token
    @value = name
    @related_field_name = name

  semantic_check: (Node) ->
    super Node
    if @parent.related_field_name?
      # 二义性模糊语义，语义错误
      throw new SemanticError """
        for node [name: #{@name}, token: #{JSON.stringify @token}, type: #{@type}],
        start spreading a new field <#{@name}>, but a previous field [#{@parent.related_field_name}] has been found, can not specify other `Field` type inside one `Field`
      """
    else if @children.length > 0
      throw new SemanticError "the Field node [name: #{@name}, token: #{JSON.stringify @token}, type: #{@type}] can not have multiple child"

  gen: (ffi) ->
    [child] = @children
    child.gen ffi

class UnaryLogicalOp extends AstNode
  type: NODE_TYPE.UNARY_LOGICAL_OPERATOR
  child_type: [
    NODE_TYPE.FIELD
    NODE_TYPE.UNARY_LOGICAL_OPERATOR
    NODE_TYPE.BINARY_LOGICAL_OPERATOR
    NODE_TYPE.UNARY_RELATION_OPERATOR
    NODE_TYPE.BINARY_RELATION_OPERATOR
    NODE_TYPE.LEAF
  ]
  constructor: (name, token, parent, related_field_name) ->
    super name, token, parent, related_field_name
    @value = name[1..]
  semantic_check: (Node) ->
    super Node
    if @children.length > 0
      throw new SemanticError "unary logical operator node [name: #{@name}, token: #{JSON.stringify @token}, type: #{@type}] can't have more than one child"
  
  gen: (ffi) ->
    [child] = @children
    ffi[@value] child.gen ffi

class BinaryLogicalOp extends AstNode
  type: NODE_TYPE.BINARY_LOGICAL_OPERATOR
  child_type: [
    NODE_TYPE.FIELD
    NODE_TYPE.UNARY_LOGICAL_OPERATOR
    NODE_TYPE.BINARY_LOGICAL_OPERATOR
    NODE_TYPE.UNARY_RELATION_OPERATOR
    NODE_TYPE.BINARY_RELATION_OPERATOR
  ]
  constructor: (name, token, parent, related_field_name) ->
    super name, token, parent, related_field_name
    @value = name[1..]
  gen: (ffi) -> ffi[@value] (child.gen ffi for child in @children)...

class UnaryRelationOp extends AstNode
  type: NODE_TYPE.UNARY_RELATION_OPERATOR
  child_type: [NODE_TYPE.LEAF]
  constructor: (name, token, parent, related_field_name) ->
    super name, token, parent, related_field_name
    @value = name[1..]
  semantic_check: (Node) ->
    super Node
    if @parent.related_field_name?
      throw new SemanticError """
        unary relation operator node [name: #{@name}, token: #{JSON.stringify @token}, type: #{@type}] can't be used under a Field node, but previous related field [#{@parent.related_field_name}] has been found
      """
    if @children.length > 0
      throw new SemanticError """
        unary relation operator node [name: #{@name}, token: #{JSON.stringify @token}, type: #{@type}] can't have more than one child
      """
  
  gen: (ffi) ->
    [leaf] = @children
    ffi[@value] leaf.gen()

class BinaryRelationOp extends AstNode
  type: NODE_TYPE.BINARY_RELATION_OPERATOR
  child_type: [NODE_TYPE.LEAF]
  constructor: (name, token, parent, related_field_name) ->
    super name, token, parent, related_field_name
    @value = name[1..]

  gen: (ffi) ->
    [leaf] = @children
    ffi[@value] @related_field_name, leaf.gen()

class Leaf extends AstNode
  type: NODE_TYPE.LEAF
  constructor: (name, token, parent, related_field_name) ->
    super name, token, parent, related_field_name
    @value = token
    @children = null

  parse: -> @
  gen: -> @value

# class LeafGroup extends AstNode
#   type: NODE_TYPE.LEAFGRP
#   child_type: [NODE_TYPE.LEAF]
#   # constructor: (name, token, parent, related_field_name) ->
#   #   super()
#   gen: -> child.gen() for child in @children

class SemanticError extends Error 
  constructor: (@message) ->
    super()
    @name = 'SemanticError'

module.exports = { AstNode, Leaf, Field, UnaryLogicalOp, UnaryRelationOp, BinaryLogicalOp, BinaryRelationOp }