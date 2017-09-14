ooq-lang
===

一个类似 MongoDB 查询语法的 MySQL 面向对象(JavaScript 对象字面量表示法)查询语言.

qengine 是目前的编译器. 
采用了自顶向下方式构建语法分析器, 语法分析阶段使用了简单的递归下降来构建语法树, 同时进行语法制导翻译.

### usage

```coffee
Parser = require 'ooq'

# 接入外部调用接口
# 例如使用 discover 的 Critiera 类提供的 ffi
ffi require('discover').Critiera.init({db, cache})

# 句法分析
t = new Parser q_lang, ffi

# 生成语法树
tree = t.parse()

# 生成中间代码
s = t.gen_code tree
```

### ooq

+ `$` 前缀的字段表示对其直接子节点应用了对应的运算符.
+ 关系运算, 作用于其祖先字段节点.
+ 如果一个逻辑运算节点有一个祖先字段节点, 那么不允许再把其他字段节点作为其子孙节点.
+ 一元逻辑运算符 `$not` 只能有一个子节点, 并且这个子节点类型不能是组关系运算节点, 否则 qengine 会编译出语义错误.
+ 一元关系运算符 `$null` 只能有一个子节点: 叶节点, 表示 field name.
+ 字段节点只能有一个子节点, 否则 qengine 会编译出错. 

### ffi

提供 ffi 的 ORM 需要提供至少如下接口:

```coffee
ffi:
  # 逻辑操作符集
  and: (args...) -> 
  or: (args...) -> 
  not: (arg) -> 
  xor: (args...) -> 

  # 关系操作符集
  eq: (column, value) -> 
  neq: (column, value) ->
  gt: (column, value) -> 
  lt: (column, value) -> 
  gte: (column, value) ->
  lte: (column, value) ->
  like: (column, value) ->
  null: (column) ->
```

### 内幕

#### 语法规则
ooq-lang 文法规则:

```coq
BINARY_LOGICAL_OPERATOR → BINARY_LOGICAL_OPERATOR_NAME: {
                            (FIELD
                            | UNARY_LOGICAL_OPERATOR
                            | BINARY_LOGICAL_OPERATOR
                            | UNARY_RELATION_OPERATOR
                            | BINARY_RELATION_OPERATOR)
                          }
UNARY_LOGICAL_OPERATOR → UNARY_LOGICAL_OPERATOR_NAME: ({
                            (FIELD
                            | UNARY_LOGICAL_OPERATOR
                            | BINARY_LOGICAL_OPERATOR
                            | UNARY_RELATION_OPERATOR
                            | BINARY_RELATION_OPERATOR)
                          }
                          | LEAF)
BINARY_RELATION_OPERATOR → BINARY_RELATION_OPERATOR_NAME: LEAF
UNARY_RELATION_OPERATOR → UNARY_RELATION_OPERATOR_NAME: LEAF
FIELD → FIELD_NAME: {
          (LEAF
          | UNARY_LOGICAL_OPERATOR
          | BINARY_LOGICAL_OPERATOR
          | BINARY_RELATION_OPERATOR)
        }
LEAF → LEAF_NAME

BINARY_LOGICAL_OPERATOR_NAME → \$(and | or | xor)
UNARY_LOGICAL_OPERATOR_NAME → \$not
BINARY_RELATION_OPERATOR_NAME → \$(eq | neq | gt | lt | gte | lte | like)
UNARY_RELATION_OPERATOR_NAME → \$null
FIELD_NAME → ^[^\$][\w\-]+
LEAF_NAME → number | string | boolean | nullable
```

在 JSON 的语法结构中, 几乎每个 `k-v` pair 表示一个节点, 每个节点都有一个**类型**.
叶节点比较特殊, 是 k-v 中的 v. 表示 `关系运算的一个操作数`, 具备 `NODE_TYPE.LEAF` 类型.

#### 节点类型

```yaml
UNARY_LOGICAL_OPERATOR: "UNARY_LOGICAL_OPERATOR"
BINARY_LOGICAL_OPERATOR: "BINARY_LOGICAL_OPERATOR"
UNARY_RELATION_OPERATOR: "UNARY_RELATION_OPERATOR"
BINARY_RELATION_OPERATOR: "BINARY_RELATION_OPERATOR"
FIELD: "FIELD"
LEAF: "LEAF"
```

#### 错误提示

qengine 会对误用的语法语义给出适当的错误提示, 方便使用和调试过程. ooq 定义两种类型的错误: 语法错误和语义错误.

绝大多数潜在的错误会在语义分析阶段之前的语法树构建阶段检测出来.

```coffee
SyntaxError "the #{@type} missing child node"
SemanticError "invalid type: `#{Node::type}`, the accepted child type of `#{@type}` must be included in #{@child_type}"
SyntaxError "the operator `#{name}` doesn't implement in the current FFI"
SemanticError "previous field name [#{@parent.related_field_name}] has been found, can not specify other `Field` type inside one `Field`"
SemanticError "`Field` type can not have multiple child"
SemanticError "unary logical operator [#{@name}] can't have more than one child"
SemanticError "unary relation operator [#{@name}] can't be used under a Field, but previous related field: #{@parent.related_field_name}"
SemanticError "unary relation operator [#{@name}] can't have more than one child"
```

#### notice

需要明确 ooq-lang 是基于 `JSON` 构建的，因此不能违反 JSON 的基本语法，比如想要构造这样的一个查询：『age 不大于等于 5 且不等于 2』，如果写成：

```coffee
age: { $and: { $not:{ $gte: 5}, $not: {$eq: "2"}} }
```

尽管语义上是明确的，但是由于 JSON 不允许在存在两个相同的 key，所以前一个 `$not` 会被后一个覆盖掉，当然这个条件有很多种变种写法，比如把否定变肯定，或者仍然使用否定语义：

```coffee
age: { $and: { $lt: 5, $neq: 2 }}
age: { $not: { $or: { $gte: 5, $eq: "2" }}}
```

#### 示例

给出如下查询语句:

```coffee
query =
  name:
    $like: "ran_meow"
  love: "coding"
  $not:
    $xor:
      athome: false
      age: 
        $or:
          $lt: 20
          $gt: 10
  $or:
    age: 10
    location:
      $and:
        $lt: "dasasd"
        $neq: "ddd"
    $and:
      xx: $like: 456
      $null: "id"
```

qengine分析结果(AST 和 intermediate code)如下所示:

```
抽象语法树 =>
| -> TYPE = LOGICAL_OPERATOR
| -> NAME = $and
| -> VALUE = and
| -> FIELD_NAME = null
| -> CHILDREN =
    | -> TYPE = FIELD
    | -> NAME = name
    | -> VALUE = name
    | -> FIELD_NAME = name
    | -> CHILDREN =
    |    | -> TYPE = RELATION_OPERATOR
    |    | -> NAME = $like
    |    | -> VALUE = like
    |    | -> FIELD_NAME = name
    |    |    | -> TYPE = LEAF
    |    |    | -> NAME = null
    |    |    | -> VALUE = ran_meow
    |    |    | -> FIELD_NAME = name
    | -> TYPE = FIELD
    | -> NAME = love
    | -> VALUE = love
    | -> FIELD_NAME = love
    | -> CHILDREN =
    |    | -> TYPE = RELATION_OPERATOR
    |    | -> NAME = $eq
    |    | -> VALUE = eq
    |    | -> FIELD_NAME = love
    |    |    | -> TYPE = LEAF
    |    |    | -> NAME = null
    |    |    | -> VALUE = coding
    |    |    | -> FIELD_NAME = love
    | -> TYPE = LOGICAL_OPERATOR
    | -> NAME = $not
    | -> VALUE = not
    | -> FIELD_NAME = null
    | -> CHILDREN =
    |    | -> TYPE = LOGICAL_OPERATOR
    |    | -> NAME = $xor
    |    | -> VALUE = xor
    |    | -> FIELD_NAME = null
    |    | -> CHILDREN =
    |    |    | -> TYPE = FIELD
    |    |    | -> NAME = athome
    |    |    | -> VALUE = athome
    |    |    | -> FIELD_NAME = athome
    |    |    | -> CHILDREN =
    |    |    |    | -> TYPE = RELATION_OPERATOR
    |    |    |    | -> NAME = $eq
    |    |    |    | -> VALUE = eq
    |    |    |    | -> FIELD_NAME = athome
    |    |    |    |    | -> TYPE = LEAF
    |    |    |    |    | -> NAME = null
    |    |    |    |    | -> VALUE = false
    |    |    |    |    | -> FIELD_NAME = athome
    |    |    | -> TYPE = FIELD
    |    |    | -> NAME = age
    |    |    | -> VALUE = age
    |    |    | -> FIELD_NAME = age
    |    |    | -> CHILDREN =
    |    |    |    | -> TYPE = LOGICAL_OPERATOR
    |    |    |    | -> NAME = $or
    |    |    |    | -> VALUE = or
    |    |    |    | -> FIELD_NAME = age
    |    |    |    | -> CHILDREN =
    |    |    |    |    | -> TYPE = RELATION_OPERATOR
    |    |    |    |    | -> NAME = $lt
    |    |    |    |    | -> VALUE = lt
    |    |    |    |    | -> FIELD_NAME = age
    |    |    |    |    |    | -> TYPE = LEAF
    |    |    |    |    |    | -> NAME = null
    |    |    |    |    |    | -> VALUE = 20
    |    |    |    |    |    | -> FIELD_NAME = age
    |    |    |    |    | -> TYPE = RELATION_OPERATOR
    |    |    |    |    | -> NAME = $gt
    |    |    |    |    | -> VALUE = gt
    |    |    |    |    | -> FIELD_NAME = age
    |    |    |    |    |    | -> TYPE = LEAF
    |    |    |    |    |    | -> NAME = null
    |    |    |    |    |    | -> VALUE = 10
    |    |    |    |    |    | -> FIELD_NAME = age
    | -> TYPE = LOGICAL_OPERATOR
    | -> NAME = $or
    | -> VALUE = or
    | -> FIELD_NAME = null
    | -> CHILDREN =
    |    | -> TYPE = FIELD
    |    | -> NAME = age
    |    | -> VALUE = age
    |    | -> FIELD_NAME = age
    |    | -> CHILDREN =
    |    |    | -> TYPE = RELATION_OPERATOR
    |    |    | -> NAME = $eq
    |    |    | -> VALUE = eq
    |    |    | -> FIELD_NAME = age
    |    |    |    | -> TYPE = LEAF
    |    |    |    | -> NAME = null
    |    |    |    | -> VALUE = 10
    |    |    |    | -> FIELD_NAME = age
    |    | -> TYPE = FIELD
    |    | -> NAME = location
    |    | -> VALUE = location
    |    | -> FIELD_NAME = location
    |    | -> CHILDREN =
    |    |    | -> TYPE = LOGICAL_OPERATOR
    |    |    | -> NAME = $and
    |    |    | -> VALUE = and
    |    |    | -> FIELD_NAME = location
    |    |    | -> CHILDREN =
    |    |    |    | -> TYPE = RELATION_OPERATOR
    |    |    |    | -> NAME = $lt
    |    |    |    | -> VALUE = lt
    |    |    |    | -> FIELD_NAME = location
    |    |    |    |    | -> TYPE = LEAF
    |    |    |    |    | -> NAME = null
    |    |    |    |    | -> VALUE = dasasd
    |    |    |    |    | -> FIELD_NAME = location
    |    |    |    | -> TYPE = RELATION_OPERATOR
    |    |    |    | -> NAME = $neq
    |    |    |    | -> VALUE = neq
    |    |    |    | -> FIELD_NAME = location
    |    |    |    |    | -> TYPE = LEAF
    |    |    |    |    | -> NAME = null
    |    |    |    |    | -> VALUE = ddd
    |    |    |    |    | -> FIELD_NAME = location
    |    | -> TYPE = LOGICAL_OPERATOR
    |    | -> NAME = $and
    |    | -> VALUE = and
    |    | -> FIELD_NAME = null
    |    | -> CHILDREN =
    |    |    | -> TYPE = FIELD
    |    |    | -> NAME = xx
    |    |    | -> VALUE = xx
    |    |    | -> FIELD_NAME = xx
    |    |    | -> CHILDREN =
    |    |    |    | -> TYPE = RELATION_OPERATOR
    |    |    |    | -> NAME = $like
    |    |    |    | -> VALUE = like
    |    |    |    | -> FIELD_NAME = xx
    |    |    |    |    | -> TYPE = LEAF
    |    |    |    |    | -> NAME = null
    |    |    |    |    | -> VALUE = 456
    |    |    |    |    | -> FIELD_NAME = xx
    |    |    | -> TYPE = RELATION_OPERATOR
    |    |    | -> NAME = $null
    |    |    | -> VALUE = null
    |    |    | -> FIELD_NAME = null
    |    |    |    | -> TYPE = LEAF
    |    |    |    | -> NAME = null
    |    |    |    | -> VALUE = id
    |    |    |    | -> FIELD_NAME = null
中间代码 =>
AND(
  like(name, ran_meow),eq(love, coding),NOT(
    XOR(
      eq(athome, false),OR(
        lt(age, 20),gt(age, 10)
      )
    )
  ),OR(
    eq(age, 10),AND(
      lt(location, dasasd),neq(location, ddd)
    ),AND(
      like(xx, 456),null(id)
    )
  )
)
```
