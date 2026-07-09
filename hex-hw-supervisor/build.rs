//! 从 hex-robot-proto(公共契约仓)生成消息类型。
//! proto 目录解析顺序:HEX_ROBOT_PROTO_DIR env(buildroot 指向 staging 里按 SHA 钉住的
//! 副本,见 package/hex-robot-proto)→ 兄弟目录 ../hex-robot-proto/proto(本机开发约定,
//! 与 hex-controller 相同)。

fn main() {
    let proto_dir = std::env::var("HEX_ROBOT_PROTO_DIR")
        .unwrap_or_else(|_| "../hex-robot-proto/proto".into());
    println!("cargo:rerun-if-env-changed=HEX_ROBOT_PROTO_DIR");
    println!("cargo:rerun-if-changed={proto_dir}");
    std::env::set_var("PROTOC", protoc_bin_vendored::protoc_bin_path().unwrap());
    prost_build::compile_protos(
        &[
            format!("{proto_dir}/common.proto"),
            format!("{proto_dir}/controller.proto"),
        ],
        &[proto_dir],
    )
    .expect("compile hex-robot-proto");
}
