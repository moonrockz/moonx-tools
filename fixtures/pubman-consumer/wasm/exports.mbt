///|
pub fn greet(name : String) -> String {
  @lib.greet(name)
}

///|
pub fn add(a : Int32, b : Int32) -> Int32 {
  @lib.add(a, b)
}

///|
pub fn quotient(a : Int32, b : Int32) -> Int32 {
  match @lib.divide(a, b) {
    Ok(n) => n
    Err(_) => -1
  }
}
