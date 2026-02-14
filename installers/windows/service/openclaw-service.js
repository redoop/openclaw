const { Service } = require("node-windows");
const path = require("path");
const fs = require("fs");

// 读取配置
const configPath =
  process.env.OPENCLAW_CONFIG || path.join(process.env.PROGRAMDATA, "openclaw", "openclaw.json");

let config = {};
try {
  if (fs.existsSync(configPath)) {
    config = JSON.parse(fs.readFileSync(configPath, "utf8"));
  }
} catch (err) {
  console.error("Failed to load config:", err);
}

// Gateway 配置
const port = config.gateway?.port || 18789;
const bind = config.gateway?.bind || "loopback";

// 创建服务
const svc = new Service({
  name: "OpenClawGateway",
  description: "OpenClaw AI Assistant Gateway Service",
  script: path.join(__dirname, "..", "cli", "openclaw.js"),
  scriptOptions: `gateway run --port ${port} --bind ${bind}`,
  nodeOptions: ["--max-old-space-size=4096"],
  env: [
    {
      name: "NODE_ENV",
      value: "production",
    },
    {
      name: "OPENCLAW_CONFIG",
      value: configPath,
    },
  ],
  workingDirectory: path.join(__dirname, "..", "cli"),
  allowServiceLogon: true,
});

// 服务事件
svc.on("install", () => {
  console.log("OpenClaw Gateway service installed");
  svc.start();
});

svc.on("alreadyinstalled", () => {
  console.log("Service already installed");
});

svc.on("start", () => {
  console.log("OpenClaw Gateway service started");
});

svc.on("stop", () => {
  console.log("OpenClaw Gateway service stopped");
});

svc.on("error", (err) => {
  console.error("Service error:", err);
});

// 处理命令行参数
const command = process.argv[2];

switch (command) {
  case "install":
    svc.install();
    break;
  case "uninstall":
    svc.uninstall();
    break;
  case "start":
    svc.start();
    break;
  case "stop":
    svc.stop();
    break;
  case "restart":
    svc.restart();
    break;
  default:
    console.log("Usage: openclaw-service.js [install|uninstall|start|stop|restart]");
    process.exit(1);
}
