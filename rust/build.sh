# Generate the bridge thing for Durt, without
# it rust can't be compiled and explodes
cd ..
rm -r ./lib/src/rust
flutter_rust_bridge_codegen generate

cd rust
cargo build
