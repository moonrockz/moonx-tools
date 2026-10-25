///|
pub fn greet(name : String) -> String {
  "Hello, " + name
}

///|
pub fn add(a : Int32, b : Int32) -> Int32 {
  a + b
}

///|
pub fn divide(a : Int32, b : Int32) -> Result[Int32, String] {
  if b == 0 {
    Err("division by zero")
  } else {
    Ok(a / b)
  }
}

///|
test "shared library" {
  assert_eq(greet("世界"), "Hello, 世界")
  assert_eq(add(2, 3), 5)
  assert_eq(divide(1, 0), Err("division by zero"))
}
