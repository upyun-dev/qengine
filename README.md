ooq-lang
===

一个类似 MongoDB 查询语法的 MySQL 面向对象(JavaScript 对象字面量表示法)查询语言.

qengine 是目前到编译器.

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

+ `NODE_TYPE::ROOT`: 整个语法树的入口节点, 没有特殊作用
+ `NODE_TYPE::FIELD_NAME`: 表示 SQL column 名字的节点, 用于向下传递 column, 展开子表达式.
+ `NODE_TYPE::RELATION_NODE`: 叶节点之一. 开始回溯用 ffi 生成代码.
+ `NODE_TYPE::RELATION_GROUP`: 叶节点之一, 表示一组上一类型. 开始回溯用 ffi 生成代码.
+ `NODE_TYPE::LOGICAL_OPERATOR`: 表示逻辑运算符节点, 作用于子节点, 构建他们之间的逻辑关系.

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