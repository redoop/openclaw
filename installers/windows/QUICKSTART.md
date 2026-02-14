# OpenClaw Windows MSI - 快速构建指南

## 最小可用版本 (CLI + 服务)

### 前置要求

1. **Windows 10/11 (x64)**
2. **WiX Toolset 3.11+**

   ```powershell
   # 下载安装
   # https://github.com/wixtoolset/wix3/releases/latest/download/wix311.exe

   # 验证
   $env:WIX  # 应该显示安装路径
   ```

3. **Node.js 22+**
   ```powershell
   node --version  # v22.x.x
   ```

### 一键构建

```powershell
# 克隆仓库
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# 执行构建
.\installers\windows\scripts\build-msi.ps1 -Version "2026.2.14"
```

### 输出

```
installers\windows\output\OpenClaw-2026.2.14-x64.msi
```

### 测试安装

```powershell
# 交互式安装
msiexec /i installers\windows\output\OpenClaw-2026.2.14-x64.msi

# 静默安装
msiexec /i installers\windows\output\OpenClaw-2026.2.14-x64.msi /quiet /norestart

# 验证
openclaw --version
Get-Service OpenClawGateway
```

### 包含内容

- ✅ Node.js 22.12.0 运行时
- ✅ OpenClaw CLI
- ✅ Windows 服务 (OpenClawGateway)
- ✅ PATH 环境变量
- ✅ 开始菜单快捷方式

### 不包含

- ❌ 桌面应用 (未来版本)
- ❌ 图形界面

### 卸载

```powershell
# 控制面板卸载
# 设置 → 应用 → OpenClaw → 卸载

# 或命令行
msiexec /x {产品代码} /quiet
```

### 故障排查

**构建失败: WiX not found**

```powershell
# 设置环境变量
$env:WIX = "C:\Program Files (x86)\WiX Toolset v3.11\"
```

**服务无法启动**

```powershell
# 检查日志
Get-EventLog -LogName Application -Source OpenClawGateway -Newest 10

# 手动测试
cd "C:\Program Files\OpenClaw\cli"
node openclaw.js gateway run
```

**端口冲突**

```powershell
# 检查 18789 端口
netstat -ano | findstr :18789

# 修改配置
notepad "%PROGRAMDATA%\openclaw\openclaw.json"
```

### 下一步

- [ ] 添加桌面应用支持
- [ ] 代码签名
- [ ] 自动更新机制
- [ ] CI/CD 集成
