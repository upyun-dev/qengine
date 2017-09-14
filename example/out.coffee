Parser = require '../src'
ffi = require "../src/ffi"
{ output } = require "../src/util"

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


parser = new Parser query, ffi
tree = parser.parse()
console.log "抽象语法树 =>"
console.log output tree
console.log "中间代码 =>"
console.log parser.gen_code tree