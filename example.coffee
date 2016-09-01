query = [
  {
    "name":
      op: "eq"
      value: "John"
    "age":
      "$and": [
        { op: "gt", value: 15 }
        { op: "lt", value: 30 }
      ]
  }
  {
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
  }
]