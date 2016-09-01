query = [
  {
    "name":
      op: "eq"
      value: "John"
    "age":
      "$and": [
        { op: "gt", value: 15 }
        { op: "lt", value: 30 }
      ]
  }
  {
    "$or":
      "type":
        "$not":
          "$and": [
            { op: "eq", value: "food" }
            { op: "gt", value: "z*" }
            { op: "lt", value: "m*" }
          ]
      "location":
        "$or": [
          { op: "eq", value: "New Yorks" }
          { op: "eq", value: "Missiby" }
        ]
  }
]

# 由于采用 JSON 对象表示法, 可以省略 tokenize 过程, 直接得到词法分析结果.
# 构造语法树
class SyntaxTree

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

  constructor(@raw) ->
  
  analyze: ->
    @root = new Node @raw
    check @raw, @root
  
  analyze_type: (node) ->
    unless node.name?
      node.type = NODE_TYPE::ROOT
      node.value = 'QUERY_ROOT'
      node.children = analyze node
    else if node.name[0] is '$'
      if check_logical_op_validation node.name
        node.type = NODE_TYPE::LOGICAL_OPERATOR
        node.value = node.name[1..]
      else
        throw new SyntaxError "invalid LOGICAL_OPERATOR => `#{node.name}`"
    else
      node.type = NODE_TYPE::FIELD_NAME
      node.value = node.name
  
  check_logical_op_validation: (op_name) ->
    op_name of @LOGICAL_OPERATOR

  check: ->

# 生成语法树节点
class Node
  constructor: (o) ->
    @_raw = o
    @name = null
    @type = null
    @value = null
    @children = []
    @field_name = null

# 语法分析
class Parser

  constructor(@tree) ->
    

  rules: ->

  check: (o) ->

  parse: (o) ->
    node = o
    node_type = analyze_type node
    switch node_type
    when NODE_TYPE::ROOT
      exec_query node.children
    when NODE_TYPE::FIELD_NAME
      arg = node.node_value
      parse_field_name_node arg node.children
    when NODE_TYPE::LOGICAL_OPERATOR
      parse_logical_operator_node arg, node.node_value, node.children
    # when NODE_TYPE::RELATION_NODE
    #   gen_query_lang arg, node.parent, node
    else
      throw new SyntaxError o

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
      if value is 'not'
        throw new SyntaxError "LOGICAL_OPERATOR #{name} can not be used in multiple relation query"
      else
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
  

# 生成SQL查询代码
class Semantic
  constructor(@) ->
    