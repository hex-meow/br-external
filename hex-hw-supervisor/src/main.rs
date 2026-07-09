//! hex-hw-supervisor:controller 级硬件的开源 supervisor(设计:robot-overall-design/09)。
//!
//! - **板卡配置是唯一事实源**(默认 /etc/hexmeow/board.yaml):有哪些资源、什么驱动。
//!   变更落盘 + sync 后**断电重启生效**(09 §13.1,不做热 reload)。
//! - 每个资源 = 本进程内一个 task:在 `<vendor>/<cid>/hw/<id>` 发布 typed message,
//!   并持有同 key 的 liveliness token(01 三态:配置里有=支持①;token 在=在③)。
//! - `<vendor>/<cid>/hw/info` queryable:HwInfo(本板支持的资源清单,来自配置)。
//! - zenoh:client 模式连本机 router(scouting 关、无限重试)——router 是唯一 LAN 入口,
//!   ACL 在 router 上强制(09 §3/§5)。
//!
//! P2 骨架:仅 mock IMU 驱动;真驱动(QMI8658 I2C、估计/vbus/遥控器)在 P3 逐个迁入。

use anyhow::anyhow;
use prost::Message;
use std::collections::BTreeMap;
use std::time::Instant;

pub mod pb {
    include!(concat!(env!("OUT_DIR"), "/robot_api.rs"));
}

const VENDOR: &str = "hexmeow";

#[derive(Debug, serde::Deserialize)]
#[serde(deny_unknown_fields)]
struct BoardConfig {
    #[serde(default)]
    zenoh: ZenohCfg,
    #[serde(default)]
    resources: BTreeMap<String, ResourceCfg>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(deny_unknown_fields)]
struct ZenohCfg {
    #[serde(default = "default_connect")]
    connect: String,
}
impl Default for ZenohCfg {
    fn default() -> Self {
        Self { connect: default_connect() }
    }
}
fn default_connect() -> String {
    "tcp/127.0.0.1:7447".into()
}

#[derive(Debug, Clone, serde::Deserialize)]
#[serde(deny_unknown_fields)]
struct ResourceCfg {
    kind: String,                 // "imu" | "estop" | "remote" | "vbus" | ...
    #[serde(default = "default_driver")]
    driver: String,               // "mock" | 真驱动名(P3)
    #[serde(default)]
    model: Option<String>,
    #[serde(default)]
    rate_hz: Option<f64>,
}
fn default_driver() -> String {
    "mock".into()
}

/// 控制器稳定标识(与 hex-controller 同约定):/etc/machine-id → hostname → "unknown"。
fn controller_id() -> String {
    std::fs::read_to_string("/etc/machine-id")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| {
            std::process::Command::new("hostname")
                .output()
                .ok()
                .and_then(|o| String::from_utf8(o.stdout).ok())
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .unwrap_or_else(|| "unknown".into())
        })
}

async fn open_session(connect: &str) -> anyhow::Result<zenoh::Session> {
    let mut cfg = zenoh::Config::default();
    cfg.insert_json5("mode", "\"client\"").map_err(|e| anyhow!("mode: {e}"))?;
    cfg.insert_json5("connect/endpoints", &format!("[\"{connect}\"]"))
        .map_err(|e| anyhow!("connect: {e}"))?;
    // 本机进程零监听零广播(ACL 单入口姿势);router 可能晚起 → 无限重试。
    cfg.insert_json5("scouting/multicast/enabled", "false").map_err(|e| anyhow!("{e}"))?;
    cfg.insert_json5("scouting/gossip/enabled", "false").map_err(|e| anyhow!("{e}"))?;
    cfg.insert_json5("connect/timeout_ms", "-1").map_err(|e| anyhow!("{e}"))?;
    zenoh::open(cfg).await.map_err(|e| anyhow!("zenoh open: {e}"))
}

/// mock IMU:静止姿态 + 微小噪声波形,按 rate_hz 发布。真驱动在 P3 以同签名并列。
async fn run_mock_imu(
    session: zenoh::Session,
    key: String,
    rate_hz: f64,
    t0: Instant,
) -> anyhow::Result<()> {
    // liveliness = "在"(三态③);task 退出(drop)即 token 消失 = "支持但不在"(三态②)。
    let _alive = session
        .liveliness()
        .declare_token(key.clone())
        .await
        .map_err(|e| anyhow!("liveliness {key}: {e}"))?;
    let publisher = session.declare_publisher(key.clone()).await.map_err(|e| anyhow!("{e}"))?;
    let period = std::time::Duration::from_secs_f64(1.0 / rate_hz.max(1.0));
    let mut tick = tokio::time::interval(period);
    tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    let mut seq: u64 = 0;
    loop {
        tick.tick().await;
        seq += 1;
        let t = t0.elapsed();
        let s = t.as_secs_f32();
        let msg = pb::ImuData {
            header: Some(pb::Header {
                seq,
                stamp_ns: t.as_nanos() as i64,
                sync_ns: None,
            }),
            accel: Some(pb::Vec3 { x: 0.02 * s.sin(), y: 0.02 * s.cos(), z: 9.81 }),
            gyro: Some(pb::Vec3 { x: 0.001 * s.sin(), y: 0.0, z: 0.0 }),
            quat: Some(pb::Quat { w: 1.0, x: 0.0, y: 0.0, z: 0.0 }),
        };
        publisher
            .put(msg.encode_to_vec())
            .await
            .map_err(|e| anyhow!("publish {key}: {e}"))?;
    }
}

/// `<cid>/hw/info` queryable:HwInfo 在声明时一次性预编码(配置在运行期不变,09 §13.1)。
async fn serve_hw_info(
    session: &zenoh::Session,
    key: String,
    info: pb::HwInfo,
) -> anyhow::Result<tokio::task::JoinHandle<()>> {
    let payload = info.encode_to_vec();
    let queryable = session
        .declare_queryable(key.clone())
        .await
        .map_err(|e| anyhow!("queryable {key}: {e}"))?;
    Ok(tokio::spawn(async move {
        while let Ok(query) = queryable.recv_async().await {
            if let Err(e) = query.reply(query.key_expr().clone(), payload.clone()).await {
                log::warn!("hw/info reply: {e}");
            }
        }
    }))
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    let cfg_path = std::env::args().nth(1).unwrap_or_else(|| "/etc/hexmeow/board.yaml".into());
    let raw = std::fs::read_to_string(&cfg_path)
        .map_err(|e| anyhow!("读板卡配置 {cfg_path}: {e}"))?;
    let cfg: BoardConfig = serde_yaml::from_str(&raw).map_err(|e| anyhow!("解析 {cfg_path}: {e}"))?;

    let cid = controller_id();
    let hw_prefix = format!("{VENDOR}/{cid}/hw");
    log::info!("hex-hw-supervisor v{} cid={cid} 配置={cfg_path} 资源×{}",
        env!("CARGO_PKG_VERSION"), cfg.resources.len());

    let session = open_session(&cfg.zenoh.connect).await?;
    let t0 = Instant::now();

    // hw/info:清单 = 板卡配置全量(三态①"支持");在不在看各 key 的 liveliness。
    let info = pb::HwInfo {
        controller_id: cid.clone(),
        sup_version: env!("CARGO_PKG_VERSION").into(),
        resources: cfg
            .resources
            .iter()
            .map(|(id, r)| pb::HwResource {
                id: id.clone(),
                kind: r.kind.clone(),
                model: r.model.clone().unwrap_or_else(|| r.driver.clone()),
            })
            .collect(),
    };
    let _info_task = serve_hw_info(&session, format!("{hw_prefix}/info"), info).await?;

    // 资源 task:单资源失败只降级该资源(token 不在/消失),不拖垮进程。
    let mut tasks = Vec::new();
    for (id, r) in &cfg.resources {
        let key = format!("{hw_prefix}/{id}");
        match (r.kind.as_str(), r.driver.as_str()) {
            ("imu", "mock") => {
                let rate = r.rate_hz.unwrap_or(100.0);
                let (s, k) = (session.clone(), key.clone());
                let id_task = id.clone();
                tasks.push(tokio::spawn(async move {
                    if let Err(e) = run_mock_imu(s, k, rate, t0).await {
                        log::error!("资源 {id_task} 退出: {e}"); // token 随 drop 消失 → 三态②
                    }
                }));
                log::info!("资源 {id}: imu/mock @ {rate}Hz → {key}");
            }
            (kind, driver) => {
                // 配置声明了但驱动未实现:诚实地不声明 liveliness(= 支持但不在),只告警。
                log::warn!("资源 {id}: kind={kind} driver={driver} 尚无驱动(P3),跳过");
            }
        }
    }

    // SIGTERM(systemd)/SIGINT:drop 所有声明(liveliness/queryable 撤销)后退出。
    let mut term = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())?;
    tokio::select! {
        _ = tokio::signal::ctrl_c() => log::info!("SIGINT"),
        _ = term.recv() => log::info!("SIGTERM"),
    }
    for t in &tasks {
        t.abort();
    }
    session.close().await.map_err(|e| anyhow!("close: {e}"))?;
    Ok(())
}
