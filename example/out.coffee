Parser = require '../src'
ffi = require "../src/ffi"
{ output } = require "../src/util"

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

parser = new Parser query, ffi
tree = parser.parse()
console.log "抽象语法树 =>"
console.log output tree
console.log "中间代码 =>"
console.log parser.gen_code tree