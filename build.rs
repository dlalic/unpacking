// build.rs

use json_typegen_shared::{codegen, Options};
use std::env;
use std::fs::OpenOptions;
use std::io::Write;
use std::path::Path;

fn main() {
    let out_dir = env::var_os("CARGO_MANIFEST_DIR").unwrap();
    let dest_path = Path::new(&out_dir).join("src/resources/i18n.rs");
    let mut options = Options::default();
    options.derives = "Debug, Clone, PartialEq, serde_derive::Serialize, serde_derive::Deserialize, openapi_type::OpenapiType".to_string();
    let code = codegen(
        "Translation",
        "frontend/translations/translations.en.json",
        options,
    );
    let mut file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(true)
        .open(dest_path)
        .unwrap();
    file.write_all(code.unwrap().as_bytes()).unwrap();
    println!("cargo:rerun-if-changed=frontend/translations");
}
