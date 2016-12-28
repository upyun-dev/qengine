{Parser, SemanticAnalysis} = require './ooq'

query =
  name:
    op: 'gt'
    value: 5
  love: 0
  $not:
    # case: 5
    $xor:
      home: 3
      work: 
        $or: [null, 'usa']
  $or:
    age: 10
    location:
      $and: [
        null
        {op: 'lt', value: "dsds"}
        {op: 'neq', value: 'ddd'}
      ]
    $and:
      xx: { op: 'like', value: 465 }
      yy: { op: 'isNull' }


parser = new Parser query
console.log "抽象语法树 =>"
console.log parser.output()
analyzer = new SemanticAnalysis parser.tree
console.log "中间代码表示 =>"
console.log analyzer.output()
module.exports = {parser, query}