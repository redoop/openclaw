# OpenClaw Windows MSI 安装包

企业级 Windows 原生安装包,支持 GPO 部署和静默安装。

## 功能特性

- ✅ 打包 Node.js 22+ 运行时
- ✅ 安装 OpenClaw CLI 和桌面应用
- ✅ 自动配置 PATH 环境变量
- ✅ Gateway 作为 Windows 服务自动启动
- ✅ 支持静默安装 (`/quiet`)
- ✅ 支持 GPO 部署
- ✅ 完整的卸载支持

## 系统要求

- Windows 10 或更高版本 (x64)
- 管理员权限(安装服务需要)

## 构建要求

- [WiX Toolset 3.11+](https://wixtoolset.org/releases/)
- Node.js 22+
- PowerShell 5.1+

## 构建步骤

### 1. 安装 WiX Toolset

```powershell
# 下载并安装 WiX
# https://github.com/wixtoolset/wix3/releases/latest

# 验证安装
$env:WIX
```

### 2. 构建 MSI

```powershell
cd installers/windows
.\scripts\build-msi.ps1 -Version "2026.2.14"
```

输出: `output/OpenClaw-2026.2.14-x64.msi`

### 3. 测试安装

```powershell
# 交互式安装
msiexec /i output\OpenClaw-2026.2.14-x64.msi

# 静默安装
msiexec /i output\OpenClaw-2026.2.14-x64.msi /quiet /norestart

# 静默安装 + 日志
msiexec /i output\OpenClaw-2026.2.14-x64.msi /quiet /l*v install.log
```

## 安装内容

```
C:\Program Files\OpenClaw\
├── nodejs\              # Node.js 运行时
├── cli\                 # OpenClaw CLI
├── desktop\             # 桌面应用
└── service\             # Windows 服务包装器

%PROGRAMDATA%\openclaw\
└── openclaw.json        # 配置文件

注册表:
HKLM\SYSTEM\CurrentControlSet\Services\OpenClawGateway
```

## 服务管理

```powershell
# 查看服务状态
Get-Service OpenClawGateway

# 启动/停止服务
Start-Service OpenClawGateway
Stop-Service OpenClawGateway

# 查看服务日志
Get-EventLog -LogName Application -Source OpenClawGateway -Newest 50
```

## GPO 部署

### 1. 创建共享文件夹

```powershell
# 在域控制器上
New-Item -Path "\\dc\software\OpenClaw" -ItemType Directory
Copy-Item output\OpenClaw-*.msi "\\dc\software\OpenClaw\"
```

### 2. 创建 GPO

1. 打开 **组策略管理控制台** (gpmc.msc)
2. 创建新 GPO: `Deploy OpenClaw`
3. 编辑 GPO:
   - **计算机配置** → **策略** → **软件设置** → **软件安装**
   - 右键 → **新建** → **程序包**
   - 选择 `\\dc\software\OpenClaw\OpenClaw-2026.2.14-x64.msi`
   - 部署方法: **已分配**

### 3. 链接到 OU

将 GPO 链接到目标组织单位 (OU)

### 4. 强制更新

```powershell
# 在客户端机器上
gpupdate /force
```

## 卸载

```powershell
# 交互式卸载
msiexec /x {PRODUCT-CODE}

# 静默卸载
msiexec /x {PRODUCT-CODE} /quiet /norestart

# 或通过控制面板
# 设置 → 应用 → OpenClaw → 卸载
```

## 自定义配置

### 修改默认端口

编辑 `wix/Product.wxs`:

```xml
<ServiceInstall Arguments='--port 18790 --bind loopback' />
```

### 禁用自动启动服务

编辑 `wix/Product.wxs`:

```xml
<ServiceInstall Start="demand" />  <!-- 改为手动启动 -->
```

### 添加桌面快捷方式

```xml
<DirectoryRef Id="DesktopFolder">
  <Component Id="DesktopShortcut" Guid="...">
    <Shortcut Id="DesktopShortcut"
              Name="OpenClaw"
              Target="[DesktopFolder]OpenClaw.exe"
              WorkingDirectory="DesktopFolder" />
  </Component>
</DirectoryRef>
```

## 签名 (可选)

```powershell
# 使用代码签名证书
signtool sign /f cert.pfx /p password `
  /t http://timestamp.digicert.com `
  output\OpenClaw-2026.2.14-x64.msi
```

## 故障排查

### 服务无法启动

```powershell
# 检查服务日志
Get-EventLog -LogName Application -Source OpenClawGateway

# 手动测试
cd "C:\Program Files\OpenClaw\cli"
node openclaw.js gateway run --port 18789
```

### 权限问题

```powershell
# 授予用户配置目录权限
icacls "%PROGRAMDATA%\openclaw" /grant Users:(OI)(CI)F
```

### 端口冲突

```powershell
# 检查端口占用
netstat -ano | findstr :18789

# 修改配置
notepad "%PROGRAMDATA%\openclaw\openclaw.json"
# 修改 gateway.port
```

## 开发注意事项

1. **Node.js 版本**: 确保打包的 Node.js 版本与 OpenClaw 要求一致
2. **服务包装器**: 使用 `node-windows` 或 `pkg` 编译为独立可执行文件
3. **桌面应用**: 根据实际技术栈 (Electron/Tauri) 调整构建流程
4. **升级策略**: `MajorUpgrade` 确保旧版本自动卸载
5. **权限**: 服务以 `LocalSystem` 运行,配置目录需要用户读写权限

## 参考资料

- [WiX Toolset 文档](https://wixtoolset.org/documentation/)
- [Windows Installer 最佳实践](https://docs.microsoft.com/en-us/windows/win32/msi/windows-installer-best-practices)
- [GPO 软件部署指南](https://docs.microsoft.com/en-us/troubleshoot/windows-server/group-policy/use-group-policy-to-install-software)
