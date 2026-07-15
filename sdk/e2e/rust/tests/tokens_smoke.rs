//! Smoke test for token counting from the published crate.

use chunk_your_tools::count_tokens;

#[test]
fn count_tokens_smoke() -> Result<(), String> {
    let n = count_tokens("hello world")?;
    assert!(n >= 1);
    Ok(())
}
