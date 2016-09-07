# 正则文法规则
# ==========

# LOGICAL_OPERATOR ::= \$(not | and | or | xor)
# FIELD_NAME ::= ^[^\$][\w\-]+
# RELATION_NODE ::= \{ op: OP, value: VAL \}
# OP ::= eq | neq | gt | lt | gte | lte
# VAL ::= .|\d*

# RELATION_GROUP -> Array(RELATION_NODE)
# LOGICAL_OPERATOR_NODE -> RELATION_NODE | RELATION_GROUP | LOGICAL_OPERATOR_NODE | FIELD_NAME_NODE
# FIELD_NAME_NODE -> RELATION_NODE | LOGICAL_OPERATOR_NODE

# ooq-lang 应用了上述文法规则

{ isPrimitive, isArray, inspect } = require 'util'

# an example about ffi
global.ffi = global.internal_ffi =
  and: (args) -> "AND(#{inspect args})"
  or: (args) -> "OR(#{inspect args})"
  not: (arg) -> "NOT(#{inspect arg})"
  xor: (args) -> "XOR(#{inspect args})"

  eq: (column, value) -> "eq(#{inspect column}, #{inspect value})"
  neq: (column, value) -> "neq(#{inspect column}, #{inspect value})"
  gt: (column, value) -> "gt(#{inspect column}, #{inspect value})"
  lt: (column, value) -> "lt(#{inspect column}, #{inspect value})"
  gte: (column, value) -> "gte(#{inspect column}, #{inspect value})"
  lte: (column, value) -> "lte(#{inspect column}, #{inspect value})"

NODE_TYPE =
  ROOT: 0
  LOGICAL_OPERATOR: 1
  FIELD_NAME: 2
  RELATION_GROUP: 3
  RELATION_NODE: 4

class SemanticError extends Error 
  constructor: (@message) ->
    super()
    @name = 'SemanticError'

# 语法树节点
class Node
  constructor: (@token) ->
    @name = null
    @type = null
    @value = null
    @parent = null
    @children = []
    @field_name = null

# 由于采用 JSON 对象表示法, 可以省略 tokenize 过程, 直接得到词法分析结果.
# 构造语法树 (句法分析 & 语法语义检查)
class Parser

  LOGICAL_OPS:
    "and": on
    "or": on
    "not": on
    "xor": on
  
  RELATION_OPS:
    "eq": on
    "neq": on
    "gt": on
    "lt": on
    "gte": on
    "lte": on

  TAB_STR: ' '.repeat 4

  ROOT_NAME: 'QUERY_ROOT'

  constructor: (@token) ->
    @parse null

  parse: (parent) =>
    @tree = @make_node parent, @ROOT_NAME, @token

    implict_logic_operator = @tree
    @tree = new Node '$and': implict_logic_operator.token
    implict_logic_operator.name = '$and'
    implict_logic_operator.type = NODE_TYPE.LOGICAL_OPERATOR
    implict_logic_operator.value = 'and'
    implict_logic_operator.parent = @tree

    @tree.type = NODE_TYPE.ROOT
    @tree.name = @ROOT_NAME
    @tree.value = @ROOT_NAME
    @tree.children.push implict_logic_operator
    
    @tree

  make_node: (parent, name, token, type) =>
    node = new Node token
    node.name = name
    node.parent = parent

    @calculate_spec node, token

    node.field_name = if node.type is NODE_TYPE.FIELD_NAME
      node.name
    else
      parent?.field_name
    
    # console.error node
    # check relationship between parent and child
    @semantic_checker parent, node

    # console.log token
    # for the "in logical" leaf node (RELATION_NODE),
    # it has no child left
    # unless node.type is NODE_TYPE.RELATION_NODE or node.type is NODE_TYPE.RELATION_GROUP
      # make child nodes for node
      # console.info "#{parent.name} is making child nodes:" if parent?
    if type = @detect_leaf_type token
      # console.log 'make leaf node'
      child = new Node token
      child.parent = node
      child.type = type
      child.field_name = node.field_name
      node.children.push child
    else
      node.children.push (@make_node node, name, child_token for name, child_token of token)...
      # node.children.type = node.children[0].type
      # console.info node.children

    node
  
  detect_leaf_type: (token) ->
    switch
      when isArray token
        NODE_TYPE.RELATION_GROUP
      when token.op? and token.value? or isPrimitive token
        NODE_TYPE.RELATION_NODE
    
  semantic_checker: (parent, child) =>
    
    # check node type
    # if parent?.children.type?
    #   unless parent.children.type is child.type
    #     throw new SemanticError "the brother nodes must be of the same type to each other"
    # else
    #   parent.children.type ?= child.type

    # check field name
    parent_field_name = parent?.field_name
    child_field_name = child.field_name
    
    if parent_field_name? and parent_field_name isnt child_field_name
      throw new SemanticError "field can not be embed inside a another field => a previous field name has been found: ('#{parent_field_name}')"

    if child.type is NODE_TYPE.LOGICAL_OPERATOR
      unless @check_logical_op_validation child.value
        throw new SyntaxError "invalid LOGICAL_OPERATOR => `#{child.name}`"

    switch parent?.type

      when NODE_TYPE.FIELD_NAME
        switch child.type
        
          when NODE_TYPE.RELATION_NODE, NODE_TYPE.LOGICAL_OPERATOR
          else throw new SemanticError "can not inferer the semantic of the #{child.token} on field name (#{parent.name})"
      
      when NODE_TYPE.LOGICAL_OPERATOR
        if parent.name is '$not' and parent.children.length > 0
          throw new SemanticError "`$not` LOGICAL_OPERATOR node must has only one child"
        
        switch child.type
        
          when NODE_TYPE.RELATION_GROUP, NODE_TYPE.RELATION_NODE, NODE_TYPE.LOGICAL_OPERATOR, NODE_TYPE.FIELD_NAME
          else throw new SemanticError "can not inferer the semantic of the #{child.token} on logical operator (#{parent.name})"
  
  calculate_spec: (node, token) =>
    
    # for ROOT node
    if node.name is @ROOT_NAME
      node.type = NODE_TYPE.ROOT
      node.value = @ROOT_NAME
    
    # for LOGICAL_OPERATOR node
    else if node.name[0] is '$'
      node.type = NODE_TYPE.LOGICAL_OPERATOR
      node.value = node.name[1..]

    # for FIELD_NAME node
    else
      node.type = NODE_TYPE.FIELD_NAME
      node.value = node.name
    # # for RELATION_NODE node
    # else if isPrimitive token or token.op? and token.value?
    #   node.type = NODE_TYPE.RELATION_NODE
    
    # # for RELATION_GROUP node
    # else isArray token
    #   node.type = NODE_TYPE.RELATION_GROUP
  
  check_logical_op_validation: (op_name) ->
    op_name of @LOGICAL_OPS

  output: (node = @tree, depth = 0) =>
    TAB = [0...depth].map => @TAB_STR 
      .join '|'
    { name, value, type, parent, children, field_name, token } = node
    switch type
      when NODE_TYPE.ROOT
        """
          #{TAB}TYPE = ROOT
          #{TAB}PARENT = NIL
          #{TAB}CHILDREN =
          #{(@output child, depth + 1 for child in children).join '\n'}
        """
      when NODE_TYPE.FIELD_NAME
        """
          #{TAB}| -> TYPE = FIELD_NAME
          #{TAB}| -> NAME = #{name}
          #{TAB}| -> VALUE = #{value}
          #{TAB}| -> FIELD_NAME = #{field_name}
          #{TAB}| -> CHILDREN =
          #{(@output child, depth + 1 for child in children).join '\n'}
        """
      when NODE_TYPE.RELATION_NODE
        """
          #{TAB}| -> TYPE = RELATION_NODE
          #{TAB}| -> VALUE = #{token.value ? token}
          #{TAB}| -> OP = #{token.op ? "NIL"}
          #{TAB}| -> FIELD_NAME = #{field_name}
        """
      when NODE_TYPE.RELATION_GROUP
        (for item in token
          """
            #{TAB}| -> TYPE = RELATION_GROUP
            #{TAB}| -> VALUE = #{item.value ? item}
            #{TAB}| -> OP = #{item.op ? "NIL"}
            #{TAB}| -> FIELD_NAME = #{field_name}
          """
        ).join "\n#{TAB}================\n"
      when NODE_TYPE.LOGICAL_OPERATOR
        """
          #{TAB}| -> TYPE = LOGICAL_OPERATOR
          #{TAB}| -> NAME = #{name}
          #{TAB}| -> VALUE = #{value}
          #{TAB}| -> FIELD_NAME = #{field_name}
          #{TAB}| -> CHILDREN =
          #{(@output child, depth + 1 for child in children).join '\n'}
        """

# 语义分析 & 中间代码生成
class SemanticAnalysis

  constructor: (@tree) ->
    @ffi = global.ffi
    @query_code = @analyze @tree

  analyze: (node) =>
    {type, name, value, parent, children, field_name } = node

    switch type
      when NODE_TYPE.ROOT
        @analyze children[0]
      when NODE_TYPE.FIELD_NAME
        @derive_field_name node
      when NODE_TYPE.LOGICAL_OPERATOR
        @derive_logical_operator node
      else
        throw new SyntaxError "can not analyze this node: #{node.name}"

  derive_field_name: ({ children }) =>
    for child in children
      { token, type, value, field_name, children } = child
      if type is NODE_TYPE.RELATION_NODE
        { op, value } = token
        @ffi[op ? 'eq'] field_name, value ? token
      else
        @derive_logical_operator child

  derive_logical_operator: ({ value, field_name, children }) =>
    sub_query = []
    for child in children
      { token, type } = child
      switch type
        when NODE_TYPE.RELATION_GROUP
          sub_query.push (@ffi[sub_token.op ? 'eq'] field_name, sub_token.value ? sub_token for sub_token in token)...
        when NODE_TYPE.RELATION_NODE
          { op, value } = token
          sub_query.push @ffi[op ? 'eq'] field_name, value ? token
        when NODE_TYPE.LOGICAL_OPERATOR
          sub_query.push @derive_logical_operator child
        when NODE_TYPE.FIELD_NAME
          sub_query.push (@derive_field_name child)...
    
    @ffi[value] sub_query
  
  output: ->
    _tmp_ffi = @ffi
    @ffi = internal_ffi
    o = @analyze @tree
    @ffi = _tmp_ffi
    o

setup_ffi = (ffi) => global.ffi = ffi

module.exports = { setup_ffi, Parser, SemanticAnalysis }