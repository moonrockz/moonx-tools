///|
pub fn hello() -> String {
  "hello from consumer"
}

///|
test "hello" {
  assert_eq(hello(), "hello from consumer")
}
