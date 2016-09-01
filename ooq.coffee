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

{ isPrimitive, isArray } = require 'util'

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
# 构造语法树
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


  ROOT_NAME: 'QUERY_ROOT'

  constructor: (@token) ->
    @parse null

  parse: (parent) ->
    @tree = @make_node parent, @ROOT_NAME, @token

    if @tree.children.length > 1
      implict_logic_operator = @tree
      @tree = new Node '$and': implict_logic_operator.token
      implict_logic_operator.name = '$and'
      implict_logic_operator.type = NODE_TYPE::LOGICAL_OPERATOR
      implict_logic_operator.value = 'and'
      implict_logic_operator.parent = @tree

      @tree.type = NODE_TYPE::ROOT
      @tree.name = @ROOT_NAME
      @tree.value = @ROOT_NAME
      @tree.children.push implict_logic_operator
    
    @tree

  make_node: (parent, name, token) =>
    node = new Node token
    node.name = name
    node.parent = parent

    @analyze_spec node, token

    node.field_name = if node.type is NODE_TYPE::FIELD_NAME
      node.name
    else
      parent?.field_name

    # check relationship between parent and child
    @semantic_checker parent, node

    # for the "in logical" leaf node (RELATION_NODE),
    # it has no child left
    unless node.type is NODE_TYPE::RELATION_NODE or node.type isnt NODE_TYPE::RELATION_GROUP
      # make child nodes for node
      node.children.push (make_node parent, name, child_token for name, child_token of token)...
      # node.children.type = node.children[0].type

    node
    
  semantic_checker: (parent, child) ->
    
    # check node type
    # if parent?.children.type?
    #   unless parent.children.type is child.type
    #     throw new SemanticError "the brother nodes must be of the same type to each other"
    # else
    #   parent.children.type ?= child.type

    # check field name
    parent_field_name = parent?.field_name
    child_field_name = child.field_name
    
    if parent_field_name? and parent_field_name isnt child.field_name
      throw new SemanticError "field can not be embed inside a another field => a previous field name has been found: ('#{field_name}')"

    if child.type is NODE_TYPE::LOGICAL_OPERATOR
      unless check_logical_op_validation child.name
        throw new SyntaxError "invalid LOGICAL_OPERATOR => `#{node.name}`"

    switch parent?.type
    
    when NODE_TYPE::FIELD_NAME
      switch child.type
      
      when NODE_TYPE::RELATION_NODE
      when NODE_TYPE::LOGICAL_OPERATOR

      else throw new SemanticError 
        "can not inferer the semantic of the #{child.token} on field name (#{parent.name})"
    
    when NODE_TYPE::LOGICAL_OPERATOR
      if parent.name is '$not' and parent.children.length > 0
        throw new SemanticError "`$not` LOGICAL_OPERATOR node must has only one child"
      
      switch child.type
      
      when NODE_TYPE::RELATION_GROUP
      when NODE_TYPE::RELATION_NODE
      when NODE_TYPE::LOGICAL_OPERATOR
      when NODE_TYPE::FIELD_NAME

      else throw new SemanticError 
        "can not inferer the semantic of the #{child.token} on logical operator (#{parent.name})"
  
  analyze_spec: (node, token) ->
    
    # for ROOT node
    if not node.name?
      node.type = NODE_TYPE::ROOT
      node.value = @ROOT_NAME
    
    # for LOGICAL_OPERATOR node
    else if node.name[0] is '$'
      node.type = NODE_TYPE::LOGICAL_OPERATOR
      node.value = node.name[1..]
    
    # for RELATION_NODE node
    else if isPrimitive token or token.op? and token.value?
      node.type = NODE_TYPE::RELATION_NODE
    
    # for RELATION_GROUP node
    else if isArray token
      node.type = NODE_TYPE::RELATION_GROUP
    
    # for FIELD_NAME node
    else
      node.type = NODE_TYPE::FIELD_NAME
      node.value = node.name
  
  check_logical_op_validation: (op_name) ->
    op_name of @LOGICAL_OPERATOR


# 语义分析
class Semantic

  constructor: (@tree) ->
    @analyze @tree

  analyze: (node) ->
    {type, name, value, parent, children, field_name } = node

    switch node.type
    when NODE_TYPE::ROOT
      exec_query children
    when NODE_TYPE::FIELD_NAME
      parse_field_name_node field_name, children
    when NODE_TYPE::LOGICAL_OPERATOR
      parse_logical_operator_node field_name, value, children
    else
      throw new SyntaxError "can not analyze this node: #{node.name}"

  derive_field_name: ({ children }) ->
    for child in children
      { token, type, value, field_name, children } = child
      if type is NODE_TYPE::RELATION_NODE
        token
      else
        derive_logical_operator child

  derive_logical_operator: ({ token, type, value, field_name, children }) ->
    logical_op = ext_code[value]

    for child in children
      { token, type } = child
      switch type
      when NODE::RELATION_GROUP
        logical_op token...
      when NODE::RELATION_NODE
        logical_op token
      when NODE::LOGICAL_OPERATOR
        logical_op derive_logical_operator child
      when NODE::FIELD_NAME
        logical_op derive_field_name child

  parse_relation_node: (relation_node) ->
    gen_relation_query relation_node
  
  parse_field_name_node: (field_name_node) ->
    { field_name, children } = field_name_node
    if children.type is NODE_TYPE::RELATION_NODE
      relation_node = children[0]
      parse_relation_node relation_node
    else
      parse_logical_operator_node child for child in children
  
  parse_logical_operator_node: (n) ->
    { children, name, value, field_name } = n

    # child is a relation group
    if children.type is NODE_TYPE::RELATION_GROUP
      relation_group = children[0]
      # the child is a relation node's group

      # the $not op can not be used here
      # if value is 'not'
      #   throw new SyntaxError "LOGICAL_OPERATOR #{name} can not be used in multiple relation query"
      # else
        gen_logical_query [field_name, value, relation_group...]...
   
    # child is a relation node
    else if children.type is NODE_TYPE::RELATION_NODE
      relation_node = children[0]

      if value isnt 'not'
        throw new SyntaxError "only `$not` operator can be used in one-relation query"
      else
        gen_logical_query field_name, value, parse_relation_node relation_node
   
    # children are field_name nodes
    else if children.type is NODE_TYPE::FIELD_NAME
      if field_name?
        throw new SyntaxError "can not embed the field(s) inside a LOGICAL_OPERATOR which has been accept a field => ('#{field_name}')"
      else
        gen_logical_query [null, value, parse_field_name_node(children)...]...
   
    # children are logical_operator nodes
    else if children.type is NODE_TYPE::LOGICAL_OPERATOR
      gen_logical_query field_name, value, (parse_logical_operator_node child for child in children)..

  # parse_relation_group: (field_name, relation_group) ->
  #   for relation in relation_group
  gen_relation_query: (relation_node) ->


  gen_logical_query: (field_name, op, sub_query...) ->
    