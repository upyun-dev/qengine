{Parser, SemanticAnalysis} = require '../src/ooq'

query =
  name:
    $gt: 5
  love: 0
  $not:
    # case: 5
    $xor:
      home: 3
      work: 
        $or:
          $eq: 1
          $gt: 2
  $or:
    age: 10
    location:
      $and:
        $eq: null
        $lt: "dasasd"
        $neq: "ddd"
    $and:
      xx: $like: 456
      $null: "yy"


parser = new Parser query
console.log parser
console.log "抽象语法树 =>"
console.log parser.output()
# analyzer = new SemanticAnalysis parser.tree
# console.log "中间代码表示 =>"
# console.log analyzer.output()
# module.exports = {parser, query}