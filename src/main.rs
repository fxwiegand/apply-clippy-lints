fn main() {
    let v = [1, 2, 3];
    if v.is_empty() {
        println!("empty");
    }
    let w = [4];
    let b = w.len() > 1;
    if b {
        println!("{}", count(&Vec::new()));
    }
}
fn count(x: &Vec<i32>) -> usize {
    x.len()
}
