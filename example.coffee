{Parser, SemanticAnalysis} = require './ooq'

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

parser = new Parser query
console.log "抽象语法树 =>"
console.log parser.output()
analyzer = new SemanticAnalysis parser.tree
console.log "中间代码表示 =>"
console.log analyzer.output()
module.exports = {parser, query}