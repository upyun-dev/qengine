ooq-lang
===

一个类似 MongoDB 查询语法的 MySQL 面向对象(JavaScript 对象字面量表示法)查询语言.

qengine 是目前的编译器. 
采用了自顶向下分析法, 语法分析阶段使用了简单的递归下降来构建语法树, 
所有语法应用最左推导(最右归约).

### usage

```coffee
{ setup_ffi, Parser, SemanticAnalysis } = require 'ooq'

# 接入外部调用接口
# 例如使用 discover 的 Critiera 类提供的 ffi
setup_ffi require('discover').Critiera.init({db, cache})

# 句法分析
t = new Parser q_lang

# 输出语法树
t.output

# 语义分析用 ffi 生成代码
s = new SemanticAnalysis t.tree

# 输出逻辑表达式和关系表达式
s.output

# 返回包含 ffi 的中间代码
s.query_code
```

### ooq

+ `$` 前缀的字段表示对其直接子节点应用了对应的逻辑运算符.
+ 带有 `op` 和 `value` 的 hash 被看作一个关系运算, 作用于其祖先字段节点.
+ 组关系运算节点不可直接作为字段节点的子节点, 因为这样写隐含的二义性致使 qengine 无法推断正确的语义.
+ 如果一个逻辑运算节点有一个祖先字段节点, 那么不允许再把其他字段节点作为其子孙节点.
+ `$not` 逻辑运算节点只能有一个子节点, 并且这个子节点类型不能是组关系运算节点, 否则 qengine 会编译出语义错误.
+ 字段节点只能有一个子节点, 否则 qengine 会编译出错. 

### ffi

提供 ffi 的 ORM 需要提供至少如下接口:

```coffee
ffi:
  # 逻辑操作符集
  and: (args) -> 
  or: (args) -> 
  not: (arg) -> 
  xor: (args) -> 

  # 关系操作符集
  eq: (column, value) -> 
  neq: (column, value) ->
  gt: (column, value) -> 
  lt: (column, value) -> 
  gte: (column, value) ->
  lte: (column, value) ->
  like: (column, value) ->
  isNull: (column) ->
  isNotNull: (column) ->
```

### 内幕

#### 语法规则
ooq-lang 遵循如下正则文法:

```
LOGICAL_OPERATOR ::= \$(not | and | or | xor)
FIELD_NAME ::= ^[^\$][\w\-]+
RELATION_NODE ::= \{ op: OP, value: VAL \}
OP ::= eq | neq | gt | lt | gte | lte
VAL ::= .|\d*
RELATION_GROUP -> Array(RELATION_NODE)
LOGICAL_OPERATOR_NODE -> RELATION_NODE | RELATION_GROUP | LOGICAL_OPERATOR_NODE | FIELD_NAME_NODE
FIELD_NAME_NODE -> RELATION_NODE | LOGICAL_OPERATOR_NODE
```

在 JSON 的语法结构中, 每个 `k-v` pair 表示一个节点, 每个节点都有一个**类型**.
叶节点比较特殊, 表示 `关系操作符(集合)` 的 `k-v` pair 即叶节点, 具备 `NODE_TYPE::RELATION_NODE | NODE_TYPE::RELATION_GROUP` 类型.

#### 节点类型

+ 根节点 -> `NODE_TYPE::ROOT`: 整个语法树的入口节点, 没有特殊作用
+ 字段节点 -> `NODE_TYPE::FIELD_NAME`: 表示 SQL column 名字的节点, 用于向下传递 column, 展开子表达式.
+ 关系运算节点 -> `NODE_TYPE::RELATION_NODE`: 叶节点之一. 开始回溯用 ffi 生成代码.
+ 组关系运算节点 -> `NODE_TYPE::RELATION_GROUP`: 叶节点之一, 表示一组上一类型. 开始回溯用 ffi 生成代码.
+ 逻辑运算节点 -> `NODE_TYPE::LOGICAL_OPERATOR`: 表示逻辑运算符节点, 作用于子节点, 构建他们之间的逻辑关系.

#### 错误提示

qengine 会对误用的语法语义给出适当的错误提示, 方便使用和调试过程. ooq 定义两种类型的错误: 语法错误和语义错误.

绝大多数潜在的错误会在语义分析阶段之前的语法树构建阶段检测出来.

`SyntaxError`

+ `"invalid LOGICAL_OPERATOR => `#{child.name}`"`
+ `"invalid RELATION_OPERATOR => `#{op}`"`

`SemanticError`:

+ `"field can not be embed inside a another field => a previous field name has been found: ('#{parent_field_name}')"`
+ `"can not inferer the semantic of the #{child.token} on field name (#{parent.name})"`
+ `"can not inferer the semantic of the #{child.token} on logical operator (#{parent.name})"`

#### 示例

给出如下查询语句:

```coffee
query =
  name: 
    $or: [
      "john"
      "baner"
    ]
  age:
    $not:
      op: 'gt'
      value: 30
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

```

qengine分析结果(AST 和 intermediate code)如下所示:

```
# 抽象语法树 =>

TYPE = ROOT
PARENT = NIL
CHILDREN =
    | -> TYPE = LOGICAL_OPERATOR
    | -> NAME = $and
    | -> VALUE = and
    | -> FIELD_NAME = undefined
    | -> CHILDREN =
    |    | -> TYPE = FIELD_NAME
    |    | -> NAME = name
    |    | -> VALUE = name
    |    | -> FIELD_NAME = name
    |    | -> CHILDREN =
    |    |    | -> TYPE = LOGICAL_OPERATOR
    |    |    | -> NAME = $or
    |    |    | -> VALUE = or
    |    |    | -> FIELD_NAME = name
    |    |    | -> CHILDREN =
    |    |    |    | -> TYPE = RELATION_GROUP
    |    |    |    | -> VALUE = john
    |    |    |    | -> OP = NIL
    |    |    |    | -> FIELD_NAME = name
    |    |    |    ================
    |    |    |    | -> TYPE = RELATION_GROUP
    |    |    |    | -> VALUE = baner
    |    |    |    | -> OP = NIL
    |    |    |    | -> FIELD_NAME = name
    |    | -> TYPE = FIELD_NAME
    |    | -> NAME = age
    |    | -> VALUE = age
    |    | -> FIELD_NAME = age
    |    | -> CHILDREN =
    |    |    | -> TYPE = LOGICAL_OPERATOR
    |    |    | -> NAME = $not
    |    |    | -> VALUE = not
    |    |    | -> FIELD_NAME = age
    |    |    | -> CHILDREN =
    |    |    |    | -> TYPE = RELATION_NODE
    |    |    |    | -> VALUE = 30
    |    |    |    | -> OP = gt
    |    |    |    | -> FIELD_NAME = age
    |    | -> TYPE = LOGICAL_OPERATOR
    |    | -> NAME = $or
    |    | -> VALUE = or
    |    | -> FIELD_NAME = undefined
    |    | -> CHILDREN =
    |    |    | -> TYPE = FIELD_NAME
    |    |    | -> NAME = type
    |    |    | -> VALUE = type
    |    |    | -> FIELD_NAME = type
    |    |    | -> CHILDREN =
    |    |    |    | -> TYPE = LOGICAL_OPERATOR
    |    |    |    | -> NAME = $not
    |    |    |    | -> VALUE = not
    |    |    |    | -> FIELD_NAME = type
    |    |    |    | -> CHILDREN =
    |    |    |    |    | -> TYPE = LOGICAL_OPERATOR
    |    |    |    |    | -> NAME = $and
    |    |    |    |    | -> VALUE = and
    |    |    |    |    | -> FIELD_NAME = type
    |    |    |    |    | -> CHILDREN =
    |    |    |    |    |    | -> TYPE = RELATION_GROUP
    |    |    |    |    |    | -> VALUE = food
    |    |    |    |    |    | -> OP = eq
    |    |    |    |    |    | -> FIELD_NAME = type
    |    |    |    |    |    ================
    |    |    |    |    |    | -> TYPE = RELATION_GROUP
    |    |    |    |    |    | -> VALUE = z*
    |    |    |    |    |    | -> OP = gt
    |    |    |    |    |    | -> FIELD_NAME = type
    |    |    |    |    |    ================
    |    |    |    |    |    | -> TYPE = RELATION_GROUP
    |    |    |    |    |    | -> VALUE = m*
    |    |    |    |    |    | -> OP = lt
    |    |    |    |    |    | -> FIELD_NAME = type
    |    |    | -> TYPE = FIELD_NAME
    |    |    | -> NAME = location
    |    |    | -> VALUE = location
    |    |    | -> FIELD_NAME = location
    |    |    | -> CHILDREN =
    |    |    |    | -> TYPE = LOGICAL_OPERATOR
    |    |    |    | -> NAME = $or
    |    |    |    | -> VALUE = or
    |    |    |    | -> FIELD_NAME = location
    |    |    |    | -> CHILDREN =
    |    |    |    |    | -> TYPE = RELATION_GROUP
    |    |    |    |    | -> VALUE = New Yorks
    |    |    |    |    | -> OP = eq
    |    |    |    |    | -> FIELD_NAME = location
    |    |    |    |    ================
    |    |    |    |    | -> TYPE = RELATION_GROUP
    |    |    |    |    | -> VALUE = Missiby
    |    |    |    |    | -> OP = eq
    |    |    |    |    | -> FIELD_NAME = location

# 中间代码表示 =>
AND([ 'OR([ \'eq(\\\'name\\\', \\\'john\\\')\', \'eq(\\\'name\\\', \\\'baner\\\')\' ])',
  'NOT([ \'gt(\\\'age\\\', 30)\' ])',
  'OR([ \'NOT([ \\\'AND([ \\\\\\\'eq(\\\\\\\\\\\\\\\'type\\\\\\\\\\\\\\\', \\\\\\\\\\\\\\\'food\\\\\\\\\\\\\\\')\\\\\\\',\\\\n  \\\\\\\'gt(\\\\\\\\\\\\\\\'type\\\\\\\\\\\\\\\', \\\\\\\\\\\\\\\'z*\\\\\\\\\\\\\\\')\\\\\\\',\\\\n  \\\\\\\'lt(\\\\\\\\\\\\\\\'type\\\\\\\\\\\\\\\', \\\\\\\\\\\\\\\'m*\\\\\\\\\\\\\\\')\\\\\\\' ])\\\' ])\',\n  \'OR([ \\\'eq(\\\\\\\'location\\\\\\\', \\\\\\\'New Yorks\\\\\\\')\\\',\\n  \\\'eq(\\\\\\\'location\\\\\\\', \\\\\\\'Missiby\\\\\\\')\\\' ])\' ])' ])

```