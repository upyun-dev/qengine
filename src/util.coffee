exports.output: (node, depth) ->
  node ?= @root
  depth ?= 0

  TAB = [0...depth].map => @TAB_STR 
    .join '|'

  { name, type, value, parent, children, related_field_name, token } = node
  switch type
    when NODE_TYPE.ROOT
      """
        #{TAB}TYPE = ROOT
        #{TAB}PARENT = NIL
        #{TAB}CHILDREN =
        #{(@output child, depth + 1 for child in children).join '\n'}
      """
    when NODE_TYPE.FIELD
      """
        #{TAB}| -> TYPE = FIELD
        #{TAB}| -> NAME = #{name}
        #{TAB}| -> VALUE = #{value}
        #{TAB}| -> FIELD_NAME = #{related_field_name}
        #{TAB}| -> CHILDREN =
        #{(@output child, depth + 1 for child in children).join '\n'}
      """
    when NODE_TYPE.UNARY_RELATION_OPERATOR, NODE_TYPE.BINARY_RELATION_OPERATOR
      """
        #{TAB}| -> TYPE = RELATION_OPERATOR
        #{TAB}| -> NAME = #{name}
        #{TAB}| -> VALUE = #{value}
        #{TAB}| -> FIELD_NAME = #{related_field_name}
        #{(@output child, depth + 1 for child in children).join '\n'}
      """
    when NODE_TYPE.UNARY_LOGICAL_OPERATOR, NODE_TYPE.BINARY_LOGICAL_OPERATOR
      """
        #{TAB}| -> TYPE = LOGICAL_OPERATOR
        #{TAB}| -> NAME = #{name}
        #{TAB}| -> VALUE = #{value}
        #{TAB}| -> FIELD_NAME = #{related_field_name}
        #{TAB}| -> CHILDREN =
        #{(@output child, depth + 1 for child in children).join '\n'}
      """
    when NODE_TYPE.LEAF
      """
        #{TAB}| -> TYPE = LEAF
        #{TAB}| -> NAME = #{name}
        #{TAB}| -> VALUE = #{value}
        #{TAB}| -> FIELD_NAME = #{related_field_name}
      """