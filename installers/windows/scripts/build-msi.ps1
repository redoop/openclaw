# OpenClaw Windows MSI 构建脚本
# 需要: WiX Toolset 3.11+, Node.js 22+

param(
    [string]$Version = "2026.2.14",
    [string]$Configuration = "Release",
    [string]$OutputDir = ".\output"
)

$ErrorActionPreference = "Stop"

Write-Host "=== OpenClaw Windows MSI Builder ===" -ForegroundColor Cyan

# 检查 WiX
$wixPath = "${env:WIX}bin"
if (-not (Test-Path $wixPath)) {
    Write-Error "WiX Toolset not found. Install from https://wixtoolset.org/"
    exit 1
}

$candle = Join-Path $wixPath "candle.exe"
$light = Join-Path $wixPath "light.exe"
$heat = Join-Path $wixPath "heat.exe"

# 目录设置
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$wixDir = Join-Path $scriptDir "wix"
$buildDir = Join-Path $scriptDir "build"
$stagingDir = Join-Path $buildDir "staging"

# 清理并创建目录
Write-Host "Preparing directories..." -ForegroundColor Yellow
Remove-Item -Path $buildDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# 1. 打包 Node.js
Write-Host "Bundling Node.js runtime..." -ForegroundColor Yellow
$nodeVersion = "22.12.0"
$nodeUrl = "https://nodejs.org/dist/v$nodeVersion/node-v$nodeVersion-win-x64.zip"
$nodeZip = Join-Path $buildDir "node.zip"
$nodeDir = Join-Path $stagingDir "nodejs"

Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeZip
Expand-Archive -Path $nodeZip -DestinationPath $buildDir
Move-Item -Path (Join-Path $buildDir "node-v$nodeVersion-win-x64\*") -Destination $nodeDir
Remove-Item -Path $nodeZip

# 2. 构建 OpenClaw CLI
Write-Host "Building OpenClaw CLI..." -ForegroundColor Yellow
Push-Location $rootDir
& npm install
& npm run build
Pop-Location

$cliDir = Join-Path $stagingDir "cli"
New-Item -ItemType Directory -Path $cliDir -Force | Out-Null
Copy-Item -Path (Join-Path $rootDir "dist\*") -Destination $cliDir -Recurse
Copy-Item -Path (Join-Path $rootDir "package.json") -Destination $cliDir

# 3. 构建 OpenClaw CLI (跳过桌面应用)
Write-Host "Building OpenClaw CLI..." -ForegroundColor Yellow
Push-Location $rootDir
& npm install
& npm run build
Pop-Location

$cliDir = Join-Path $stagingDir "cli"
New-Item -ItemType Directory -Path $cliDir -Force | Out-Null
Copy-Item -Path (Join-Path $rootDir "dist\*") -Destination $cliDir -Recurse
Copy-Item -Path (Join-Path $rootDir "package.json") -Destination $cliDir

# 4. 编译服务包装器为可执行文件
Write-Host "Compiling service wrapper..." -ForegroundColor Yellow
$serviceDir = Join-Path $scriptDir "service"
Push-Location $serviceDir
& npm install
& npm install -g pkg
& pkg openclaw-service.js --target node22-win-x64 --output (Join-Path $stagingDir "service\openclaw-service.exe")
Pop-Location

# 5. 使用 Heat 生成文件清单
Write-Host "Generating file manifests..." -ForegroundColor Yellow

& $heat dir $nodeDir `
    -cg NodeJSComponents `
    -dr NodeJSFolder `
    -gg -sfrag -srd -sreg `
    -out (Join-Path $wixDir "NodeJS.wxs")

& $heat dir $cliDir `
    -cg OpenClawComponents `
    -dr CLIFolder `
    -gg -sfrag -srd -sreg `
    -out (Join-Path $wixDir "CLI.wxs")

# 6. 编译 WiX 源文件
Write-Host "Compiling WiX sources..." -ForegroundColor Yellow
$wixSources = @(
    "Product.wxs",
    "UI.wxs",
    "NodeJS.wxs",
    "CLI.wxs"
)

$objFiles = @()
foreach ($source in $wixSources) {
    $sourcePath = Join-Path $wixDir $source
    $objPath = Join-Path $buildDir ($source -replace '\.wxs$', '.wixobj')
    
    & $candle $sourcePath `
        -dSourceDir=$stagingDir `
        -dVersion=$Version `
        -ext WixUtilExtension `
        -out $objPath
    
    $objFiles += $objPath
}

# 7. 链接生成 MSI
Write-Host "Linking MSI package..." -ForegroundColor Yellow
$msiPath = Join-Path $OutputDir "OpenClaw-$Version-x64.msi"

& $light $objFiles `
    -ext WixUIExtension `
    -ext WixUtilExtension `
    -cultures:en-us `
    -out $msiPath

if (Test-Path $msiPath) {
    Write-Host "✓ MSI package created: $msiPath" -ForegroundColor Green
    
    # 显示文件信息
    $msi = Get-Item $msiPath
    Write-Host "  Size: $([math]::Round($msi.Length / 1MB, 2)) MB" -ForegroundColor Gray
    
    # 可选: 签名
    # signtool sign /f cert.pfx /p password /t http://timestamp.digicert.com $msiPath
} else {
    Write-Error "Failed to create MSI package"
    exit 1
}

Write-Host "`n=== Build Complete ===" -ForegroundColor Cyan
