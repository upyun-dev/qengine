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

```coffee
# 查询 #1
"name":
  op: "eq"
  value: "John"
"age":
  "$and": [
    { op: "gt", value: 15 }
    { op: "lt", value: 30 }
  ]

# 查询 #2
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