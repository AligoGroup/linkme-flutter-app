#Requires -Version 5.1
<#
.SYNOPSIS
    LinkMe Flutter Android APK 全流程打包脚本（Windows 10/11）
.DESCRIPTION
    从零环境到打包 APK 的完整流程，包含环境下载、配置、构建。
    失败时自动回滚，支持 PowerShell 进度条；PowerShell 不可用时请使用 build_android.cmd。
#>

param(
    [string]$EnvRoot = "",
    [switch]$UseCmdFallback,
    [string]$AmapAndroidKey = "",  # 可选。若需在 APK 内编译进高德 Android Key（运行时定位用），可传入
    [string]$ScriptDir = ""        # 由 run_build.ps1 传入，避免 ScriptBlock 中 $PSScriptRoot 为空
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # 关闭 Write-Progress，避免与 Write-Host 文字重叠

# 中文乱码：根据当前控制台代码页选择编码
try {
    $cp = [Console]::OutputEncoding.CodePage
    if ($cp -eq 65001) {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $OutputEncoding = [System.Text.Encoding]::UTF8
    } else {
        [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(936)
        $OutputEncoding = [System.Text.Encoding]::GetEncoding(936)
    }
} catch {
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
}

# 确保 HTTPS 下载可用（部分系统需显式启用 TLS 1.2）
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# ========== 配置 ==========
if ([string]::IsNullOrEmpty($ScriptDir)) {
    $ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { $null }
}
if (-not $ScriptDir) { throw "无法确定脚本目录，请使用 build_android.cmd 双击运行。" }
# 脚本在 cmdding/cmdding/ 目录，需要上升两级到项目根目录
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
if ([string]::IsNullOrEmpty($EnvRoot)) {
    $EnvRoot = Join-Path $env:TEMP "LinkMeBuildEnv"
}
$EnvRoot = [System.IO.Path]::GetFullPath($EnvRoot)

# 下载地址（使用国内镜像加速）
# Flutter 国内镜像
$FlutterMirrorUrl = "https://storage.flutter-io.cn/flutter_infra_release/releases"
$FlutterReleasesUrl = "https://storage.flutter-io.cn/flutter_infra_release/releases/releases_windows.json"
$FlutterBaseUrl = $FlutterMirrorUrl

# JDK 国内镜像（JDK 17 - Android推荐版本）
$Jdk17Urls = @(
    "https://mirrors.huaweicloud.com/openjdk/17.0.2/openjdk-17.0.2_windows-x64_bin.zip",
    "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/windows/OpenJDK17U-jdk_x64_windows_hotspot_17.0.13_11.zip",
    "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.13%2B11/OpenJDK17U-jdk_x64_windows_hotspot_17.0.13_11.zip"
)

# Android SDK 国内镜像
$AndroidCmdlineUrls = @(
    "https://mirrors.cloud.tencent.com/AndroidSDK/commandlinetools-win-11076708_latest.zip",
    "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
)

# x265：使用 libx265.so（.a 常缺 x265_api_get 等符号）
$X265MirrorUrls = @{
    "arm64-v8a" = @(
        "https://raw.githubusercontent.com/BeckYoung/x265_android_build/master/arm64-v8a/usr/local/lib/libx265.so",
        "https://cdn.jsdelivr.net/gh/BeckYoung/x265_android_build@master/arm64-v8a/usr/local/lib/libx265.so",
        "https://ghproxy.com/https://raw.githubusercontent.com/BeckYoung/x265_android_build/master/arm64-v8a/usr/local/lib/libx265.so",
        "https://mirror.ghproxy.com/https://raw.githubusercontent.com/BeckYoung/x265_android_build/master/arm64-v8a/usr/local/lib/libx265.so"
    )
    "armeabi-v7a" = @(
        "https://raw.githubusercontent.com/BeckYoung/x265_android_build/master/armeabi-v7a/usr/local/lib/libx265.so",
        "https://cdn.jsdelivr.net/gh/BeckYoung/x265_android_build@master/armeabi-v7a/usr/local/lib/libx265.so",
        "https://ghproxy.com/https://raw.githubusercontent.com/BeckYoung/x265_android_build/master/armeabi-v7a/usr/local/lib/libx265.so",
        "https://mirror.ghproxy.com/https://raw.githubusercontent.com/BeckYoung/x265_android_build/master/armeabi-v7a/usr/local/lib/libx265.so"
    )
}

$FlutterDir = Join-Path $EnvRoot "flutter"
$JdkDir = Join-Path $EnvRoot "jdk17"
$AndroidHome = Join-Path $EnvRoot "android_sdk"

# 回滚追踪（已禁用 - 改为断点续传）
$BackupFiles = @()
$OriginalPath = $env:PATH
$RollbackNeeded = $false
$EnableRollback = $false  # 禁用回滚，保留已下载内容

# ========== 工具函数 ==========
function Write-Step {
    param([string]$Msg, [int]$Step, [int]$Total = 20)
    Write-Host "`n[步骤 $Step/$Total] $Msg" -ForegroundColor Cyan
}

function Write-SubProgress {
    param([string]$Msg, [int]$Percent)
    Write-Host "  $Msg ($Percent)" -ForegroundColor Gray
}

function Invoke-Rollback {
    param([string]$Reason)
    
    if (-not $EnableRollback) {
        Write-Host "`n========================================" -ForegroundColor Yellow
        Write-Host " 构建失败，但已保留下载内容" -ForegroundColor Yellow
        Write-Host " 原因: $Reason" -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Yellow
        Write-Host "已下载的内容保留在: $EnvRoot" -ForegroundColor Cyan
        Write-Host "重新运行脚本将从失败处继续，不会重复下载" -ForegroundColor Cyan
        return
    }
    
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "回滚中: $Reason" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Red

    # 恢复 PATH
    $env:PATH = $OriginalPath

    # 恢复备份文件
    foreach ($bf in $BackupFiles) {
        if (Test-Path "$bf.bak") {
            Copy-Item "$bf.bak" $bf -Force
            Remove-Item "$bf.bak" -Force
            Write-Host "  已恢复: $bf" -ForegroundColor Yellow
        } elseif (Test-Path $bf) {
            Remove-Item $bf -Force
            Write-Host "  已删除（新建）: $bf" -ForegroundColor Yellow
        }
    }

    # 删除环境目录
    if (Test-Path $EnvRoot) {
        Write-Host "  正在删除环境目录: $EnvRoot ..." -ForegroundColor Yellow
        Remove-Item -Path $EnvRoot -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  已删除." -ForegroundColor Yellow
    }

    Write-Host "`n回滚完成。环境已恢复至最初状态。`n" -ForegroundColor Green
}

function Test-DownloadWithProgress {
    param([string]$Url, [string]$DestPath, [string]$StepDesc, [int]$MaxRetries = 3)
    $destDir = Split-Path $DestPath -Parent
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

    $retryCount = 0
    $downloadSuccess = $false
    
    while (-not $downloadSuccess -and $retryCount -lt $MaxRetries) {
        try {
            if ($retryCount -gt 0) {
                Write-Host "`n  [重试 $retryCount/$MaxRetries] 继续下载..." -ForegroundColor Yellow
            } else {
                Write-Host "  正在下载: $StepDesc" -ForegroundColor Gray
            }
            
            # 检查是否有部分下载的文件（断点续传）
            $startByte = 0
            if (Test-Path $DestPath) {
                $startByte = (Get-Item $DestPath).Length
                if ($startByte -gt 0) {
                    Write-Host "  检测到部分文件，从 $([math]::Round($startByte/1MB, 1)) MB 处继续..." -ForegroundColor Cyan
                }
            }
            
            # 使用 WebRequest 进行流式下载（支持断点续传）
            $request = [System.Net.WebRequest]::Create($Url)
            $request.Timeout = 300000  # 5分钟超时
            $request.ReadWriteTimeout = 300000
            $request.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
            $request.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
            
            # 设置断点续传
            if ($startByte -gt 0) {
                $request.AddRange($startByte)
            }
            
            $response = $request.GetResponse()
            $totalBytes = $response.ContentLength + $startByte
            $responseStream = $response.GetResponseStream()
            
            # 追加模式打开文件
            $fileStream = if ($startByte -gt 0) {
                [System.IO.File]::Open($DestPath, [System.IO.FileMode]::Append)
            } else {
                [System.IO.File]::Create($DestPath)
            }
            
            $buffer = New-Object byte[] 65536  # 64KB缓冲区
            $totalRead = $startByte
            $lastPct = -1
            $startTime = Get-Date
            $lastUpdateTime = Get-Date
            $lastReadBytes = $startByte
            
            if ($startByte -eq 0) {
                Write-Host "  文件总大小: $([math]::Round($totalBytes / 1MB, 1)) MB" -ForegroundColor Gray
            }
            
            while ($true) {
                $read = $responseStream.Read($buffer, 0, $buffer.Length)
                if ($read -eq 0) { break }
                
                $fileStream.Write($buffer, 0, $read)
                $fileStream.Flush()  # 确保数据写入磁盘
                $totalRead += $read
                
                # 每500ms更新一次进度
                $now = Get-Date
                if (($now - $lastUpdateTime).TotalMilliseconds -gt 500) {
                    if ($totalBytes -gt 0) {
                        $pct = [math]::Floor(($totalRead / $totalBytes) * 100)
                        
                        $barLength = 40
                        $completed = [math]::Floor($barLength * $pct / 100)
                        $remaining = $barLength - $completed
                        $bar = "[" + ("=" * $completed) + (">" * [math]::Min(1, $remaining)) + (" " * [math]::Max(0, $remaining - 1)) + "]"
                        
                        $downloadedMB = [math]::Round($totalRead / 1MB, 1)
                        $totalMB = [math]::Round($totalBytes / 1MB, 1)
                        
                        # 计算实时速度
                        $elapsed = ($now - $lastUpdateTime).TotalSeconds
                        if ($elapsed -gt 0) {
                            $speedMBps = [math]::Round((($totalRead - $lastReadBytes) / 1MB) / $elapsed, 2)
                            $sizeInfo = " ($downloadedMB/$totalMB MB, $speedMBps MB/s)"
                        } else {
                            $sizeInfo = " ($downloadedMB/$totalMB MB)"
                        }
                        
                        Write-Host "`r  $bar $pct%$sizeInfo" -NoNewline -ForegroundColor Cyan
                        $lastPct = $pct
                        $lastReadBytes = $totalRead
                    }
                    $lastUpdateTime = $now
                }
            }
            
            $fileStream.Close()
            $responseStream.Close()
            $response.Close()
            
            Write-Host "`r  [========================================] 100% - 完成!    " -ForegroundColor Green
            $downloadSuccess = $true
            
        } catch {
            if ($fileStream) { $fileStream.Close() }
            if ($responseStream) { $responseStream.Close() }
            if ($response) { $response.Close() }
            
            $retryCount++
            
            if ($retryCount -lt $MaxRetries) {
                Write-Host "`n  [错误] 下载中断: $($_.Exception.Message.Split("`n")[0])" -ForegroundColor Yellow
                Write-Host "  等待3秒后重试..." -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            } else {
                Write-Host "`n  [错误] 下载失败（已重试$MaxRetries次）: $($_.Exception.Message.Split("`n")[0])" -ForegroundColor Red
                Write-Host "  尝试使用 WebClient 最后一次下载..." -ForegroundColor Yellow
                
                try {
                    # 删除部分文件，重新下载
                    if (Test-Path $DestPath) {
                        Remove-Item $DestPath -Force
                    }
                    
                    $wc = New-Object System.Net.WebClient
                    $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                    $wc.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
                    $wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                    
                    Write-Host "  使用同步下载（请耐心等待）..." -ForegroundColor Yellow
                    $wc.DownloadFile($Url, $DestPath)
                    
                    $fileSize = (Get-Item $DestPath).Length
                    $sizeMB = [math]::Round($fileSize / 1MB, 1)
                    Write-Host "  下载完成: $sizeMB MB" -ForegroundColor Green
                    
                    $wc.Dispose()
                    $downloadSuccess = $true
                } catch {
                    Write-Host "  最终下载失败。" -ForegroundColor Red
                    Write-Host "  建议：" -ForegroundColor Yellow
                    Write-Host "    1) 检查网络连接稳定性" -ForegroundColor Gray
                    Write-Host "    2) 尝试使用VPN或更换网络" -ForegroundColor Gray
                    Write-Host "    3) 手动下载文件并放置到指定位置" -ForegroundColor Gray
                    throw $_
                }
            }
        }
    }
}

function Expand-ArchiveWithProgress {
    param([string]$ZipPath, [string]$DestDir, [string]$StepDesc)
    
    Write-Host "  正在解压: $StepDesc" -ForegroundColor Cyan
    
    try {
        # 使用 .NET 类进行解压，可以获取进度
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
        $totalEntries = $zip.Entries.Count
        $currentEntry = 0
        $lastPct = -1
        
        Write-Host "  文件总数: $totalEntries" -ForegroundColor Gray
        
        foreach ($entry in $zip.Entries) {
            $currentEntry++
            $pct = [math]::Floor(($currentEntry / $totalEntries) * 100)
            
            # 每1%更新一次进度
            if ($pct -ne $lastPct) {
                $barLength = 40
                $completed = [math]::Floor($barLength * $pct / 100)
                $remaining = $barLength - $completed
                $bar = "[" + ("=" * $completed) + (">" * [math]::Min(1, $remaining)) + (" " * [math]::Max(0, $remaining - 1)) + "]"
                
                Write-Host "`r  $bar $pct% ($currentEntry/$totalEntries)" -NoNewline -ForegroundColor Cyan
                $lastPct = $pct
            }
            
            $targetPath = Join-Path $DestDir $entry.FullName
            $targetDir = Split-Path $targetPath -Parent
            
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            
            if (-not $entry.FullName.EndsWith('/')) {
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targetPath, $true)
            }
        }
        
        $zip.Dispose()
        Write-Host "`r  [========================================] 100% - 解压完成!    " -ForegroundColor Green
        
    } catch {
        Write-Host "`n  [错误] 解压失败: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  尝试使用备用方法..." -ForegroundColor Yellow
        
        try {
            # 备用方法：使用 Expand-Archive
            Expand-Archive -Path $ZipPath -DestinationPath $DestDir -Force
            Write-Host "  解压完成（备用方法）。" -ForegroundColor Green
        } catch {
            Write-Host "  解压失败，无法继续。" -ForegroundColor Red
            throw "解压失败: $ZipPath"
        }
    }
}

# ========== 主流程 ==========
$TotalSteps = 20
$CurrentStep = 0

try {
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host " LinkMe Flutter Android APK 打包脚本" -ForegroundColor Green
    Write-Host " 支持 Windows 10 / Windows 11" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green

    # 检测系统
    $os = Get-CimInstance Win32_OperatingSystem
    $osVer = $os.Caption
    Write-Host "系统: $osVer" -ForegroundColor Gray
    Write-Host "项目路径: $ProjectRoot" -ForegroundColor Gray
    Write-Host "环境目录: $EnvRoot`n" -ForegroundColor Gray

    # ----- 步骤 1: 预检查并自动配置 C++ 与 x265 -----
    $CurrentStep = 1
    Write-Step "预检查并配置：C++ 原生模块与 x265" $CurrentStep $TotalSteps

    $nativeDir = Join-Path $ProjectRoot "native\linkme_av_core"
    $x265Dir = Join-Path $nativeDir "third_party\x265"
    $cmakeLists = Join-Path $nativeDir "CMakeLists.txt"

    if (-not (Test-Path $cmakeLists)) {
        throw "C++ 模块缺失：未找到 $cmakeLists，请检查项目完整性。"
    }
    
    $cmakeContent = Get-Content $cmakeLists -Raw
    if ($cmakeContent -match "x265") {
        # 检查 x265 目录
        if (-not (Test-Path $x265Dir)) {
            New-Item -ItemType Directory -Path $x265Dir -Force | Out-Null
            Write-Host "  [信息] 创建 x265 目录" -ForegroundColor Gray
        }
        
        # 检查 x265 库文件
        $x265LibDir = Join-Path $x265Dir "lib\arm64-v8a"
        $x265LibFile = Join-Path $x265LibDir "libx265.so"
        
        if (-not (Test-Path $x265LibFile)) {
            Write-Host "  [信息] x265 库不存在，开始自动下载..." -ForegroundColor Yellow
            
            # 创建库目录
            if (-not (Test-Path $x265LibDir)) {
                New-Item -ItemType Directory -Path $x265LibDir -Force | Out-Null
            }
            
            # 下载预编译的 x265 库（使用国内镜像）
            $x265Urls = $X265MirrorUrls["arm64-v8a"]
            
            $downloadSuccess = $false
            foreach ($url in $x265Urls) {
                try {
                    Write-Host "  [下载] 尝试从: $url" -ForegroundColor Gray
                    Test-DownloadWithProgress -Url $url -DestPath $x265LibFile -StepDesc "x265 库 (arm64-v8a)"
                    
                    if (Test-Path $x265LibFile) {
                        $fileSize = (Get-Item $x265LibFile).Length
                        if ($fileSize -gt 100KB) {
                            Write-Host "  [成功] x265 库下载完成 ($([math]::Round($fileSize/1MB, 2)) MB)" -ForegroundColor Green
                            $downloadSuccess = $true
                            break
                        } else {
                            Remove-Item $x265LibFile -Force
                            Write-Host "  [失败] 文件太小，尝试下一个源..." -ForegroundColor Yellow
                        }
                    }
                } catch {
                    Write-Host "  [失败] 下载失败: $($_.Exception.Message)" -ForegroundColor Yellow
                    if (Test-Path $x265LibFile) {
                        Remove-Item $x265LibFile -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            
            if (-not $downloadSuccess) {
                Write-Host "`n  [错误] 无法自动下载 x265 库" -ForegroundColor Red
                Write-Host "  请手动下载并放置到: $x265LibFile" -ForegroundColor Yellow
                Write-Host "  下载源:" -ForegroundColor Yellow
                Write-Host "    1. https://github.com/BeckYoung/x265_android_build (usr/local/lib/libx265.so)" -ForegroundColor Gray
                Write-Host "    2. https://github.com/videolan/x265 (需自行编译)" -ForegroundColor Gray
                throw "x265 库缺失且自动下载失败"
            }
            
            # 同时下载 armeabi-v7a 版本
            $x265LibDirV7a = Join-Path $x265Dir "lib\armeabi-v7a"
            $x265LibFileV7a = Join-Path $x265LibDirV7a "libx265.so"
            if (-not (Test-Path $x265LibDirV7a)) {
                New-Item -ItemType Directory -Path $x265LibDirV7a -Force | Out-Null
            }
            
            if (-not (Test-Path $x265LibFileV7a)) {
                try {
                    Write-Host "  [下载] armeabi-v7a 版本..." -ForegroundColor Gray
                    $v7aUrls = $X265MirrorUrls["armeabi-v7a"]
                    
                    $v7aSuccess = $false
                    foreach ($url in $v7aUrls) {
                        try {
                            Test-DownloadWithProgress -Url $url -DestPath $x265LibFileV7a -StepDesc "x265 库 (armeabi-v7a)"
                            if (Test-Path $x265LibFileV7a) {
                                $fileSize = (Get-Item $x265LibFileV7a).Length
                                if ($fileSize -gt 100KB) {
                                    Write-Host "  [成功] armeabi-v7a 版本下载完成 ($([math]::Round($fileSize/1MB, 2)) MB)" -ForegroundColor Green
                                    $v7aSuccess = $true
                                    break
                                }
                            }
                        } catch {
                            continue
                        }
                    }
                    
                    if (-not $v7aSuccess) {
                        Write-Host "  [警告] armeabi-v7a 版本下载失败（可选）" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "  [警告] armeabi-v7a 版本下载失败（可选）: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "  [信息] x265 库已存在: $x265LibFile" -ForegroundColor Green
        }
        
        # 验证头文件
        $x265Header = Join-Path $x265Dir "include\x265.h"
        if (-not (Test-Path $x265Header)) {
            Write-Host "  [警告] x265 头文件缺失，项目已包含必要的头文件" -ForegroundColor Yellow
        }
    }

    $cppSrc = Join-Path $nativeDir "src"
    $requiredCpp = @("jni_bridge.cpp", "video_encoder.cpp", "video_decoder.cpp", "audio_processor.cpp", "frame_buffer.cpp", "codec_factory.cpp", "hardware_accelerator.cpp", "quality_controller.cpp")
    $missing = @()
    foreach ($f in $requiredCpp) {
        if (-not (Test-Path (Join-Path $cppSrc $f))) { $missing += $f }
    }
    if ($missing.Count -gt 0) {
        throw "C++ 源文件缺失: $($missing -join ', ')。请补全后重试。"
    }
    Write-Host "  C++ 模块检查通过。" -ForegroundColor Green

    # ----- 步骤 2: 检查并修补 Android 构建配置（高德 SDK）-----
    # 高德 Key 不是打包必须项；Key 仅影响运行时“发送位置”页。iOS 已有 fallback Key，Android 可选 -AmapAndroidKey 或改 send_location_page.dart
    $CurrentStep = 2
    Write-Step "检查并修补 Android 构建配置（高德 SDK）" $CurrentStep $TotalSteps

    $appBuild = Join-Path $ProjectRoot "android\app\build.gradle.kts"
    $content = Get-Content $appBuild -Raw
    if ($content -notmatch "com\.amap\.api") {
        Copy-Item $appBuild "$appBuild.bak" -Force
        $BackupFiles += $appBuild
        $content = $content -replace "(coreLibraryDesugaring\([^)]+\)\s*)(\})", "`$1`n    implementation(`"com.amap.api:3dmap:8.1.0`")`n    implementation(`"com.amap.api:location:5.6.0`")`n`$2"
        Set-Content $appBuild $content -Encoding UTF8
        Write-Host "  已添加高德 SDK 依赖。" -ForegroundColor Green
    } else {
        Write-Host "  高德 SDK 依赖已存在，跳过。" -ForegroundColor Gray
    }

    # ----- 步骤 3: 创建环境目录 -----
    $CurrentStep = 3
    Write-Step "创建环境根目录" $CurrentStep $TotalSteps
    if (Test-Path $EnvRoot) {
        Write-Host "  环境目录已存在，将使用现有目录。" -ForegroundColor Yellow
    } else {
        try {
            New-Item -ItemType Directory -Path $EnvRoot -Force -ErrorAction Stop | Out-Null
            Write-Host "  已创建: $EnvRoot" -ForegroundColor Green
        } catch {
            Write-Host "`n[权限不足] 无法创建环境目录: $EnvRoot" -ForegroundColor Red
            Write-Host "请以管理员身份重新运行：右键 build_android.cmd -> 以管理员身份运行" -ForegroundColor Yellow
            throw "需要管理员权限以创建目录。请右键 build_android.cmd 选择「以管理员身份运行」。"
        }
    }

    # ----- 步骤 4: 下载 Flutter SDK -----
    $CurrentStep = 4
    Write-Step "下载 Flutter SDK（使用国内镜像）" $CurrentStep $TotalSteps

    $flutterZip = Join-Path $EnvRoot "flutter.zip"
    if (-not (Test-Path (Join-Path $FlutterDir "bin\flutter.bat"))) {
        # Flutter 版本和正确的镜像源路径
        $FlutterVersion = "3.41.5"
        $FlutterUrls = @(
            # 腾讯云镜像（最稳定）
            "https://mirrors.cloud.tencent.com/flutter/flutter_infra_release/releases/stable/windows/flutter_windows_${FlutterVersion}-stable.zip",
            # Flutter中国官方镜像
            "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_${FlutterVersion}-stable.zip",
            # Google官方源
            "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_${FlutterVersion}-stable.zip"
        )
        
        Write-Host "  使用 Flutter 稳定版: $FlutterVersion" -ForegroundColor Gray
        
        $downloadSuccess = $false
        foreach ($FlutterUrl in $FlutterUrls) {
            try {
                $sourceName = if ($FlutterUrl -match "tencent") { "腾讯云镜像" }
                    elseif ($FlutterUrl -match "flutter-io.cn") { "Flutter中国镜像" }
                    else { "Google官方源" }
                
                Write-Host "  尝试 $sourceName" -ForegroundColor Gray
                Write-Host "  URL: $FlutterUrl" -ForegroundColor DarkGray
                
                # 先测试URL是否可访问（缩短超时时间）
                try {
                    $testRequest = [System.Net.WebRequest]::Create($FlutterUrl)
                    $testRequest.Method = "HEAD"
                    $testRequest.Timeout = 5000
                    $testRequest.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
                    $testRequest.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                    $testResponse = $testRequest.GetResponse()
                    $contentLength = $testResponse.ContentLength
                    $testResponse.Close()
                    
                    if ($contentLength -gt 0) {
                        Write-Host "  文件大小: $([math]::Round($contentLength/1MB, 1)) MB" -ForegroundColor Green
                    } else {
                        Write-Host "  [跳过] 无法获取文件大小" -ForegroundColor Yellow
                        continue
                    }
                } catch {
                    Write-Host "  [跳过] 源不可用: $($_.Exception.Message.Split("`n")[0])" -ForegroundColor Yellow
                    continue
                }
                
                Test-DownloadWithProgress -Url $FlutterUrl -DestPath $flutterZip -StepDesc "Flutter SDK ($sourceName)"
                
                if (Test-Path $flutterZip) {
                    $fileSize = (Get-Item $flutterZip).Length
                    if ($fileSize -gt 100MB) {
                        Write-Host "  下载成功: $([math]::Round($fileSize/1MB, 1)) MB" -ForegroundColor Green
                        $downloadSuccess = $true
                        break
                    } else {
                        Write-Host "  [失败] 文件不完整 ($([math]::Round($fileSize/1MB, 1)) MB)，尝试下一个源" -ForegroundColor Yellow
                        Remove-Item $flutterZip -Force -ErrorAction SilentlyContinue
                    }
                }
            } catch {
                Write-Host "  [失败] $($_.Exception.Message.Split("`n")[0])" -ForegroundColor Red
                if (Test-Path $flutterZip) {
                    Remove-Item $flutterZip -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        if (-not $downloadSuccess) {
            Write-Host "`n========================================" -ForegroundColor Red
            Write-Host " Flutter SDK 下载失败" -ForegroundColor Red
            Write-Host "========================================" -ForegroundColor Red
            Write-Host "`n请尝试以下方案：" -ForegroundColor Yellow
            Write-Host "  1. 检查网络连接和防火墙设置" -ForegroundColor Gray
            Write-Host "  2. 手动下载并解压到: $FlutterDir" -ForegroundColor Gray
            Write-Host "     下载地址: https://flutter.cn/docs/get-started/install/windows" -ForegroundColor Gray
            Write-Host "  3. 或使用 Git 克隆: git clone https://github.com/flutter/flutter.git -b stable" -ForegroundColor Gray
            throw "Flutter SDK 下载失败"
        }
        
        Write-Host "  解压 Flutter SDK（可能需要几分钟）..." -ForegroundColor Gray
        Expand-Archive -Path $flutterZip -DestinationPath $EnvRoot -Force
        
        $flutterFolder = Get-ChildItem $EnvRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName "bin\flutter.bat") } | Select-Object -First 1
        if ($flutterFolder -and $flutterFolder.FullName -ne $FlutterDir) {
            if (Test-Path $FlutterDir) { Remove-Item $FlutterDir -Recurse -Force }
            Move-Item $flutterFolder.FullName $FlutterDir -Force
        } elseif ($flutterFolder) {
            $FlutterDir = $flutterFolder.FullName
        }
        Remove-Item $flutterZip -Force -ErrorAction SilentlyContinue
        Write-Host "  Flutter SDK 安装完成。" -ForegroundColor Green
    } else {
        Write-Host "  Flutter SDK 已存在，跳过下载。" -ForegroundColor Gray
    }

    $env:PATH = "$FlutterDir\bin;$env:PATH"
    
    # 配置 Flutter 国内镜像环境变量
    $env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
    $env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
    Write-Host "  已配置 Flutter 国内镜像加速" -ForegroundColor Green

    # ----- 步骤 5: 下载 JDK 17 -----
    $CurrentStep = 5
    Write-Step "下载 JDK 17（使用国内镜像）" $CurrentStep $TotalSteps

    $jdkZip = Join-Path $EnvRoot "jdk17.zip"
    if (-not (Test-Path (Join-Path $JdkDir "bin\java.exe"))) {
        $jdkDownloadSuccess = $false
        
        foreach ($jdkUrl in $Jdk17Urls) {
            try {
                $sourceName = if ($jdkUrl -match "huaweicloud") { "华为云镜像" }
                    elseif ($jdkUrl -match "tuna") { "清华大学镜像" }
                    else { "GitHub官方源" }
                
                Write-Host "  尝试 $sourceName" -ForegroundColor Gray
                Test-DownloadWithProgress -Url $jdkUrl -DestPath $jdkZip -StepDesc "JDK 17 ($sourceName)"
                
                if (Test-Path $jdkZip) {
                    $fileSize = (Get-Item $jdkZip).Length
                    if ($fileSize -gt 50MB) {
                        Write-Host "  下载成功: $([math]::Round($fileSize/1MB, 1)) MB" -ForegroundColor Green
                        $jdkDownloadSuccess = $true
                        break
                    } else {
                        Write-Host "  [失败] 文件不完整，尝试下一个源" -ForegroundColor Yellow
                        Remove-Item $jdkZip -Force -ErrorAction SilentlyContinue
                    }
                }
            } catch {
                Write-Host "  [失败] $($_.Exception.Message.Split("`n")[0])" -ForegroundColor Yellow
                if (Test-Path $jdkZip) {
                    Remove-Item $jdkZip -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        if (-not $jdkDownloadSuccess) {
            throw "无法从任何镜像源下载 JDK 17"
        }
        
        Write-Host "  解压 JDK 17..." -ForegroundColor Gray
        Expand-Archive -Path $jdkZip -DestinationPath $EnvRoot -Force
        
        $jdkExtracted = Get-ChildItem $EnvRoot -Directory | Where-Object { $_.Name -like "jdk*" -or $_.Name -like "*jdk*" } | Select-Object -First 1
        if ($jdkExtracted -and $jdkExtracted.FullName -ne $JdkDir) {
            if (Test-Path $JdkDir) { Remove-Item $JdkDir -Recurse -Force }
            Move-Item $jdkExtracted.FullName $JdkDir -Force
        }
        Remove-Item $jdkZip -Force -ErrorAction SilentlyContinue
        Write-Host "  JDK 17 安装完成。" -ForegroundColor Green
    } else {
        Write-Host "  JDK 17 已存在，跳过下载。" -ForegroundColor Gray
    }

    $env:JAVA_HOME = $JdkDir
    $env:PATH = "$JdkDir\bin;$env:PATH"

    # ----- 步骤 6: 下载 Android 命令行工具 -----
    $CurrentStep = 6
    Write-Step "下载 Android 命令行工具（使用国内镜像）" $CurrentStep $TotalSteps

    $cmdlineZip = Join-Path $EnvRoot "cmdline-tools.zip"
    $cmdlineDir = Join-Path $AndroidHome "cmdline-tools\latest"
    if (-not (Test-Path (Join-Path $cmdlineDir "bin\sdkmanager.bat"))) {
        $cmdlineDownloadSuccess = $false
        
        foreach ($cmdlineUrl in $AndroidCmdlineUrls) {
            try {
                $sourceName = if ($cmdlineUrl -match "tencent") { "腾讯云镜像" } else { "Google官方源" }
                
                Write-Host "  尝试 $sourceName" -ForegroundColor Gray
                Test-DownloadWithProgress -Url $cmdlineUrl -DestPath $cmdlineZip -StepDesc "Android cmdline-tools ($sourceName)"
                
                if (Test-Path $cmdlineZip) {
                    $fileSize = (Get-Item $cmdlineZip).Length
                    if ($fileSize -gt 50MB) {
                        Write-Host "  下载成功: $([math]::Round($fileSize/1MB, 1)) MB" -ForegroundColor Green
                        $cmdlineDownloadSuccess = $true
                        break
                    } else {
                        Write-Host "  [失败] 文件不完整，尝试下一个源" -ForegroundColor Yellow
                        Remove-Item $cmdlineZip -Force -ErrorAction SilentlyContinue
                    }
                }
            } catch {
                Write-Host "  [失败] $($_.Exception.Message.Split("`n")[0])" -ForegroundColor Yellow
                if (Test-Path $cmdlineZip) {
                    Remove-Item $cmdlineZip -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        if (-not $cmdlineDownloadSuccess) {
            throw "无法从任何镜像源下载 Android 命令行工具"
        }
        
        $tempExtract = Join-Path $EnvRoot "cmdline-tools-temp"
        Expand-Archive -Path $cmdlineZip -DestinationPath $tempExtract -Force
        $inner = Get-ChildItem $tempExtract -Directory | Select-Object -First 1
        $targetParent = Join-Path $AndroidHome "cmdline-tools"
        New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
        Move-Item $inner.FullName (Join-Path $targetParent "latest") -Force
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $cmdlineZip -Force -ErrorAction SilentlyContinue
        Write-Host "  Android 命令行工具安装完成。" -ForegroundColor Green
    } else {
        Write-Host "  Android 命令行工具已存在，跳过。" -ForegroundColor Gray
    }

    $env:ANDROID_HOME = $AndroidHome
    $env:PATH = "$cmdlineDir\bin;$env:PATH;$AndroidHome\platform-tools"

    # 验证JDK
    Write-Host "  验证 JDK 配置..." -ForegroundColor Gray
    try {
        $javaVersion = & "$JdkDir\bin\java.exe" -version 2>&1
        Write-Host "  JDK 版本: $($javaVersion[0])" -ForegroundColor Green
    } catch {
        Write-Host "  [警告] JDK 验证失败，可能影响 Android SDK 安装" -ForegroundColor Yellow
    }

    # ----- 步骤 7: 安装 Android SDK 组件 -----
    $CurrentStep = 7
    Write-Step "安装 Android SDK 组件（platforms, build-tools, NDK, CMake）" $CurrentStep $TotalSteps

    $sdkmanager = Join-Path $cmdlineDir "bin\sdkmanager.bat"
    
    # 检查组件是否已安装
    $components = @(
        "platform-tools",
        "platforms;android-36",
        "build-tools;35.0.0",
        "ndk;27.0.12077973",
        "cmake;3.22.1"
    )
    
    Write-Host "  检查已安装组件..." -ForegroundColor Gray
    $installedComponents = @()
    try {
        $listOutput = & $sdkmanager "--sdk_root=$AndroidHome" --list 2>&1 | Out-String
        foreach ($comp in $components) {
            if ($listOutput -match [regex]::Escape($comp)) {
                $installedComponents += $comp
                Write-Host "  ✓ $comp 已安装" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "  [警告] 无法检查已安装组件，将尝试全部安装" -ForegroundColor Yellow
    }
    
    # 只安装未安装的组件
    $componentsToInstall = $components | Where-Object { $installedComponents -notcontains $_ }
    
    if ($componentsToInstall.Count -eq 0) {
        Write-Host "  所有组件已安装，跳过" -ForegroundColor Green
    } else {
        Write-Host "  需要安装 $($componentsToInstall.Count) 个组件" -ForegroundColor Cyan
        foreach ($c in $componentsToInstall) {
            Write-Host "  安装: $c" -ForegroundColor Gray
            try {
                $installOutput = & $sdkmanager "--sdk_root=$AndroidHome" $c 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  [警告] $c 安装可能失败，退出码: $LASTEXITCODE" -ForegroundColor Yellow
                    Write-Host "  错误信息: $($installOutput | Select-Object -First 3)" -ForegroundColor DarkGray
                } else {
                    Write-Host "  ✓ $c 安装成功" -ForegroundColor Green
                }
            } catch {
                Write-Host "  [错误] $c 安装失败: $($_.Exception.Message)" -ForegroundColor Red
                throw "Android SDK 组件安装失败。请检查 JDK 配置和网络连接。"
            }
        }
    }
    Write-Host "  SDK 组件安装完成。" -ForegroundColor Green

    # ----- 步骤 8: 配置 local.properties -----
    $CurrentStep = 8
    Write-Step "配置 local.properties" $CurrentStep $TotalSteps

    $localProps = Join-Path $ProjectRoot "android\local.properties"
    if (Test-Path $localProps) {
        Copy-Item $localProps "$localProps.bak" -Force
    }
    $BackupFiles += $localProps
    $flutterSdk = $FlutterDir -replace "\\", "/"
    $androidSdk = $AndroidHome -replace "\\", "/"
    $props = @"
sdk.dir=$androidSdk
flutter.sdk=$flutterSdk
"@
    Set-Content $localProps $props -Encoding UTF8
    Write-Host "  已写入 local.properties。" -ForegroundColor Green

    # ----- 步骤 9: 接受 Android 许可 -----
    $CurrentStep = 9
    Write-Step "接受 Android SDK 许可" $CurrentStep $TotalSteps

    try {
        # 方法1：使用多个y输入
        $yesInput = "y`ny`ny`ny`ny`ny`ny`ny`ny`n"
        $yesInput | & $sdkmanager "--sdk_root=$AndroidHome" --licenses 2>&1 | Out-Null
        Write-Host "  许可已接受。" -ForegroundColor Green
    } catch {
        Write-Host "  [警告] 自动接受许可失败，尝试手动方式..." -ForegroundColor Yellow
        try {
            # 方法2：使用--update参数（自动接受）
            & $sdkmanager "--sdk_root=$AndroidHome" --licenses --update 2>&1 | Out-Null
            Write-Host "  许可已接受。" -ForegroundColor Green
        } catch {
            Write-Host "  [警告] 许可接受可能失败，继续执行..." -ForegroundColor Yellow
            Write-Host "  如果后续构建失败，请手动运行: $sdkmanager --licenses" -ForegroundColor Gray
        }
    }

    # ----- 步骤 10: 配置 Flutter Android SDK 路径 -----
    $CurrentStep = 10
    Write-Step "配置 Flutter Android SDK 路径" $CurrentStep $TotalSteps

    Push-Location $ProjectRoot
    try {
        # 显式告诉 Flutter Android SDK 的位置
        & flutter config --android-sdk "$AndroidHome" 2>&1 | Out-Null
        Write-Host "  Flutter Android SDK 路径已配置: $AndroidHome" -ForegroundColor Green
    } catch {
        Write-Host "  [警告] Flutter config 失败，但继续执行..." -ForegroundColor Yellow
    }
    Pop-Location

    # ----- 步骤 11: Flutter 预检查（带超时，失败则修复）-----
    $CurrentStep = 11
    Write-Step "Flutter 预检查（doctor）" $CurrentStep $TotalSteps

    # 验证 FlutterDir 是否有效
    if (-not $FlutterDir -or -not (Test-Path (Join-Path $FlutterDir "bin\flutter.bat"))) {
        Write-Host "  [错误] Flutter SDK 路径无效: $FlutterDir" -ForegroundColor Red
        throw "Flutter SDK 未正确安装，无法继续"
    }

    Push-Location $ProjectRoot
    $doctorSuccess = $false
    $maxDoctorRetries = 2
    
    for ($doctorRetry = 1; $doctorRetry -le $maxDoctorRetries; $doctorRetry++) {
        try {
            Write-Host "  正在执行 flutter doctor（尝试 $doctorRetry/$maxDoctorRetries，最多等待 45 秒）..." -ForegroundColor Cyan
            
            # 使用 Start-Job 实现超时控制
            $doctorJob = Start-Job -ScriptBlock {
                param($flutterPath, $projectPath)
                Set-Location $projectPath
                & "$flutterPath\bin\flutter.bat" doctor -v 2>&1
            } -ArgumentList $FlutterDir, $ProjectRoot
            
            # 等待最多 45 秒
            $completed = Wait-Job $doctorJob -Timeout 45
            
            if ($completed) {
                $doctorOutput = Receive-Job $doctorJob
                Write-Host $doctorOutput -ForegroundColor Gray
                Write-Host "  ✓ Flutter doctor 完成。" -ForegroundColor Green
                $doctorSuccess = $true
                Remove-Job $doctorJob -Force
                break
            } else {
                Write-Host "  ✗ Flutter doctor 超时（45秒）。" -ForegroundColor Yellow
                Stop-Job $doctorJob
                Remove-Job $doctorJob -Force
                
                if ($doctorRetry -lt $maxDoctorRetries) {
                    Write-Host "  尝试清理 Flutter 缓存后重试..." -ForegroundColor Yellow
                    try {
                        & flutter config --clear-features 2>&1 | Out-Null
                        Start-Sleep -Seconds 2
                    } catch { }
                }
            }
        } catch {
            Write-Host "  ✗ Flutter doctor 失败: $($_.Exception.Message)" -ForegroundColor Yellow
            if ($doctorRetry -lt $maxDoctorRetries) {
                Start-Sleep -Seconds 2
            }
        }
    }
    
    if (-not $doctorSuccess) {
        Write-Host "  [警告] Flutter doctor 未能完成，但这通常不影响构建。" -ForegroundColor Yellow
        Write-Host "  继续执行构建流程..." -ForegroundColor Cyan
    }
    Pop-Location

    # ----- 步骤 12: 配置 Git 网络设置（必须成功）-----
    $CurrentStep = 12
    Write-Step "配置 Git 网络设置" $CurrentStep $TotalSteps

    # 检查 Git 是否安装
    $gitAvailable = $false
    try {
        $gitVersion = git --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  检测到 Git: $gitVersion" -ForegroundColor Gray
            $gitAvailable = $true
        }
    } catch { }
    
    if (-not $gitAvailable) {
        Write-Host "  [警告] 系统未检测到 Git" -ForegroundColor Yellow
        
        # 尝试 1: 使用 Flutter 内置 Git（MinGit）
        $flutterMinGit = Join-Path $FlutterDir "bin\mingit\cmd\git.exe"
        if (Test-Path $flutterMinGit) {
            $env:PATH = "$(Split-Path $flutterMinGit);$env:PATH"
            Write-Host "  ✓ 使用 Flutter 内置 MinGit: $flutterMinGit" -ForegroundColor Green
            $gitAvailable = $true
        } else {
            # 尝试 2: 下载便携版 Git
            Write-Host "  正在下载便携版 Git..." -ForegroundColor Cyan
            
            $gitPortableDir = Join-Path $EnvRoot "PortableGit"
            $gitPortableZip = Join-Path $EnvRoot "PortableGit.7z.exe"
            
            if (-not (Test-Path (Join-Path $gitPortableDir "bin\git.exe"))) {
                $gitUrls = @(
                    "https://mirrors.huaweicloud.com/git-for-windows/v2.43.0.windows.1/PortableGit-2.43.0-64-bit.7z.exe",
                    "https://npm.taobao.org/mirrors/git-for-windows/v2.43.0.windows.1/PortableGit-2.43.0-64-bit.7z.exe",
                    "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/PortableGit-2.43.0-64-bit.7z.exe"
                )
                
                $gitDownloadSuccess = $false
                foreach ($gitUrl in $gitUrls) {
                    try {
                        $sourceName = if ($gitUrl -match "huaweicloud") { "华为云" }
                            elseif ($gitUrl -match "taobao") { "淘宝镜像" }
                            else { "GitHub" }
                        
                        Write-Host "  尝试从 $sourceName 下载..." -ForegroundColor Gray
                        Test-DownloadWithProgress -Url $gitUrl -DestPath $gitPortableZip -StepDesc "Git 便携版 ($sourceName)" -MaxRetries 2
                        
                        if (Test-Path $gitPortableZip) {
                            $fileSize = (Get-Item $gitPortableZip).Length
                            if ($fileSize -gt 10MB) {
                                $gitDownloadSuccess = $true
                                break
                            } else {
                                Remove-Item $gitPortableZip -Force -ErrorAction SilentlyContinue
                            }
                        }
                    } catch {
                        Write-Host "  下载失败: $($_.Exception.Message.Split("`n")[0])" -ForegroundColor Yellow
                    }
                }
                
                if ($gitDownloadSuccess) {
                    Write-Host "  正在解压 Git（自解压文件）..." -ForegroundColor Cyan
                    
                    try {
                        # PortableGit 是自解压文件
                        New-Item -ItemType Directory -Path $gitPortableDir -Force | Out-Null
                        
                        $extractProcess = Start-Process -FilePath $gitPortableZip -ArgumentList "-o`"$gitPortableDir`"", "-y" -Wait -PassThru -NoNewWindow
                        
                        if ($extractProcess.ExitCode -eq 0 -and (Test-Path (Join-Path $gitPortableDir "bin\git.exe"))) {
                            Write-Host "  ✓ Git 解压完成" -ForegroundColor Green
                            Remove-Item $gitPortableZip -Force -ErrorAction SilentlyContinue
                        } else {
                            throw "Git 解压失败"
                        }
                    } catch {
                        Write-Host "  [错误] Git 解压失败: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
            
            # 检查 Git 是否可用
            $gitExe = Join-Path $gitPortableDir "bin\git.exe"
            if (Test-Path $gitExe) {
                $env:PATH = "$(Join-Path $gitPortableDir 'bin');$env:PATH"
                Write-Host "  ✓ 使用便携版 Git: $gitExe" -ForegroundColor Green
                $gitAvailable = $true
                
                # 验证
                try {
                    $gitVersion = & $gitExe --version 2>&1
                    Write-Host "  Git 版本: $gitVersion" -ForegroundColor Gray
                } catch { }
            }
        }
    }
    
    if (-not $gitAvailable) {
        Write-Host "`n========================================" -ForegroundColor Red
        Write-Host " Git 不可用" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "`n请手动安装 Git:" -ForegroundColor Yellow
        Write-Host "  下载地址: https://git-scm.com/download/win" -ForegroundColor Gray
        Write-Host "  或使用: winget install Git.Git" -ForegroundColor Gray
        throw "Git 未安装且自动安装失败"
    }

    $gitConfigSuccess = 0
    $gitConfigTotal = 5
    $gitConfigErrors = @()
    
    # 配置 1: postBuffer
    try {
        Write-Host "  [1/$gitConfigTotal] 配置 Git postBuffer..." -ForegroundColor Cyan
        $null = git config --global http.postBuffer 524288000 2>&1
        if ($LASTEXITCODE -eq 0) {
            $gitConfigSuccess++
            Write-Host "    ✓ postBuffer 已设置为 500MB" -ForegroundColor Green
        } else {
            $gitConfigErrors += "postBuffer 配置失败"
            Write-Host "    ✗ postBuffer 配置失败" -ForegroundColor Red
        }
    } catch {
        $gitConfigErrors += "postBuffer 异常: $($_.Exception.Message)"
        Write-Host "    ✗ postBuffer 配置异常" -ForegroundColor Red
    }
    
    # 配置 2: 超时设置
    try {
        Write-Host "  [2/$gitConfigTotal] 配置 Git 超时设置..." -ForegroundColor Cyan
        $null = git config --global http.lowSpeedLimit 0 2>&1
        $null = git config --global http.lowSpeedTime 999999 2>&1
        if ($LASTEXITCODE -eq 0) {
            $gitConfigSuccess++
            Write-Host "    ✓ 超时限制已禁用" -ForegroundColor Green
        } else {
            $gitConfigErrors += "超时配置失败"
            Write-Host "    ✗ 超时配置失败" -ForegroundColor Red
        }
    } catch {
        $gitConfigErrors += "超时配置异常"
        Write-Host "    ✗ 超时配置异常" -ForegroundColor Red
    }
    
    # 配置 3: SSL 验证
    try {
        Write-Host "  [3/$gitConfigTotal] 配置 Git SSL 验证..." -ForegroundColor Cyan
        $null = git config --global http.sslVerify false 2>&1
        if ($LASTEXITCODE -eq 0) {
            $gitConfigSuccess++
            Write-Host "    ✓ SSL 验证已禁用" -ForegroundColor Green
        } else {
            $gitConfigErrors += "SSL 配置失败"
            Write-Host "    ✗ SSL 配置失败" -ForegroundColor Red
        }
    } catch {
        $gitConfigErrors += "SSL 配置异常"
        Write-Host "    ✗ SSL 配置异常" -ForegroundColor Red
    }
    
    # 配置 4: 代理设置
    try {
        Write-Host "  [4/$gitConfigTotal] 清除 Git 代理设置..." -ForegroundColor Cyan
        $null = git config --global --unset http.proxy 2>&1
        $null = git config --global --unset https.proxy 2>&1
        $gitConfigSuccess++
        Write-Host "    ✓ 代理设置已清除" -ForegroundColor Green
    } catch {
        $gitConfigErrors += "代理配置异常"
        Write-Host "    ✗ 代理配置异常" -ForegroundColor Red
    }
    
    # 配置 5: 凭据缓存
    try {
        Write-Host "  [5/$gitConfigTotal] 配置 Git 凭据缓存..." -ForegroundColor Cyan
        $null = git config --global credential.helper store 2>&1
        if ($LASTEXITCODE -eq 0) {
            $gitConfigSuccess++
            Write-Host "    ✓ 凭据缓存已启用" -ForegroundColor Green
        } else {
            $gitConfigErrors += "凭据配置失败"
            Write-Host "    ✗ 凭据配置失败" -ForegroundColor Red
        }
    } catch {
        $gitConfigErrors += "凭据配置异常"
        Write-Host "    ✗ 凭据配置异常" -ForegroundColor Red
    }
    
    Write-Host "`n  Git 配置结果: $gitConfigSuccess/$gitConfigTotal 项成功" -ForegroundColor $(if ($gitConfigSuccess -ge 3) { "Green" } else { "Yellow" })
    
    if ($gitConfigSuccess -lt 3) {
        Write-Host "  [警告] Git 配置不完整，可能影响 pub get。" -ForegroundColor Yellow
        foreach ($err in $gitConfigErrors) {
            Write-Host "    - $err" -ForegroundColor Gray
        }
    }

    # ----- 步骤 13: flutter pub get（必须成功）-----
    $CurrentStep = 13
    Write-Step "执行 flutter pub get" $CurrentStep $TotalSteps

    Push-Location $ProjectRoot
    $pubGetSuccess = $false
    $maxRetries = 5
    
    # 首先检查 pubspec.yaml 是否存在
    $pubspecFile = Join-Path $ProjectRoot "pubspec.yaml"
    if (-not (Test-Path $pubspecFile)) {
        Write-Host "  [错误] pubspec.yaml 文件不存在: $pubspecFile" -ForegroundColor Red
        Pop-Location
        throw "pubspec.yaml 文件缺失，无法继续"
    }
    
    Write-Host "  检测到 pubspec.yaml: $pubspecFile" -ForegroundColor Gray
    
    # 检查 Dart SDK 版本
    try {
        $dartVersion = dart --version 2>&1 | Out-String
        if ($dartVersion -match "Dart SDK version: (\d+\.\d+\.\d+)") {
            $currentDartVersion = $matches[1]
            Write-Host "  当前 Dart SDK 版本: $currentDartVersion" -ForegroundColor Gray
        }
    } catch { }
    
    for ($retry = 1; $retry -le $maxRetries; $retry++) {
        try {
            Write-Host "`n  [尝试 $retry/$maxRetries] 执行 flutter pub get..." -ForegroundColor Cyan
            
            # 根据重试次数使用不同的策略
            if ($retry -eq 1) {
                Write-Host "  使用标准模式..." -ForegroundColor Gray
                Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
                & flutter pub get
                $exitCode = $LASTEXITCODE
                Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
            }
            elseif ($retry -eq 2) {
                Write-Host "  检测到 Dart SDK 版本不兼容问题..." -ForegroundColor Yellow
                Write-Host "  尝试修复: 修改 pubspec.yaml 降级 build_runner..." -ForegroundColor Cyan
                
                # 读取 pubspec.yaml
                $pubspecContent = Get-Content $pubspecFile -Raw
                
                # 备份原文件
                $backupFile = "$pubspecFile.bak"
                Copy-Item $pubspecFile $backupFile -Force
                Write-Host "  已备份 pubspec.yaml 到 $backupFile" -ForegroundColor Gray
                
                # 修改 build_runner 版本要求
                if ($pubspecContent -match "build_runner:\s*[><=^]*[\d\.]+") {
                    $pubspecContent = $pubspecContent -replace "build_runner:\s*[><=^]*[\d\.]+", "build_runner: ^2.4.0"
                    Set-Content $pubspecFile $pubspecContent -NoNewline
                    Write-Host "  已将 build_runner 版本改为 ^2.4.0（兼容 Dart 3.5.4）" -ForegroundColor Green
                }
                
                Write-Host "  重新获取依赖..." -ForegroundColor Gray
                Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
                & flutter pub get
                $exitCode = $LASTEXITCODE
                Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
                
                # 如果失败，恢复备份
                if ($exitCode -ne 0) {
                    Copy-Item $backupFile $pubspecFile -Force
                    Write-Host "  已恢复原 pubspec.yaml" -ForegroundColor Yellow
                }
            }
            elseif ($retry -eq 3) {
                Write-Host "  尝试修复: 升级 Flutter 到最新稳定版..." -ForegroundColor Cyan
                Write-Host "  这可能需要几分钟，请耐心等待..." -ForegroundColor Gray
                Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
                
                # 临时启用进度显示
                $oldProgressPref = $ProgressPreference
                $ProgressPreference = "Continue"
                
                # 直接调用，输出会实时显示
                $env:FLUTTER_UPGRADE_VERBOSE = "1"
                flutter upgrade --force
                $upgradeExitCode = $LASTEXITCODE
                
                $ProgressPreference = $oldProgressPref
                
                Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
                
                if ($upgradeExitCode -eq 0) {
                    Write-Host "  ✓ Flutter 升级完成" -ForegroundColor Green
                    
                    # 检查新版本
                    try {
                        $newFlutterVersion = flutter --version 2>&1 | Select-String "Flutter" | Select-Object -First 1
                        $newDartVersion = dart --version 2>&1 | Out-String
                        
                        Write-Host "  新版本信息:" -ForegroundColor Cyan
                        if ($newFlutterVersion) {
                            Write-Host "    $newFlutterVersion" -ForegroundColor Gray
                        }
                        if ($newDartVersion -match "Dart SDK version: (\d+\.\d+\.\d+)") {
                            Write-Host "    Dart SDK: $($matches[1])" -ForegroundColor Gray
                        }
                    } catch { }
                } else {
                    Write-Host "  ✗ Flutter 升级失败 (退出码: $upgradeExitCode)" -ForegroundColor Yellow
                }
                
                Write-Host "  重新获取依赖..." -ForegroundColor Gray
                Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
                & flutter pub get
                $exitCode = $LASTEXITCODE
                Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
            }
            elseif ($retry -eq 4) {
                Write-Host "  尝试修复: 删除 .dart_tool 和 pubspec.lock..." -ForegroundColor Cyan
                $dartTool = Join-Path $ProjectRoot ".dart_tool"
                $lockFile = Join-Path $ProjectRoot "pubspec.lock"
                if (Test-Path $dartTool) {
                    Remove-Item $dartTool -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "  已删除 .dart_tool" -ForegroundColor Green
                }
                if (Test-Path $lockFile) {
                    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
                    Write-Host "  已删除 pubspec.lock" -ForegroundColor Green
                }
                Start-Sleep -Seconds 1
                Write-Host "  重新获取依赖..." -ForegroundColor Gray
                Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
                & flutter pub get
                $exitCode = $LASTEXITCODE
                Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
            }
            else {
                Write-Host "  最后尝试: 清理缓存后重试..." -ForegroundColor Cyan
                & flutter pub cache clean --force 2>&1 | Out-Null
                Start-Sleep -Seconds 2
                Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
                & flutter pub get
                $exitCode = $LASTEXITCODE
                Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
            }
            
            # 检查是否成功
            if ($exitCode -eq 0) {
                Write-Host "`n  ✓ pub get 完成。" -ForegroundColor Green
                
                # 验证是否真的成功（检查 .dart_tool 目录）
                $dartTool = Join-Path $ProjectRoot ".dart_tool"
                if (Test-Path $dartTool) {
                    Write-Host "  ✓ 依赖已安装到 .dart_tool" -ForegroundColor Green
                    $pubGetSuccess = $true
                    break
                } else {
                    Write-Host "  [警告] 命令成功但 .dart_tool 目录不存在" -ForegroundColor Yellow
                }
            } else {
                Write-Host "`n  ✗ pub get 失败 (退出码: $exitCode)" -ForegroundColor Yellow
                
                # 显示诊断信息（仅第一次）
                if ($retry -eq 1) {
                    Write-Host "`n  诊断信息:" -ForegroundColor Cyan
                    Write-Host "  - 项目路径: $ProjectRoot" -ForegroundColor Gray
                    Write-Host "  - Flutter 路径: $FlutterDir" -ForegroundColor Gray
                    Write-Host "  - 当前目录: $(Get-Location)" -ForegroundColor Gray
                    
                    # 检查网络连接
                    Write-Host "  - 测试网络连接..." -ForegroundColor Gray
                    try {
                        $testPub = Test-Connection -ComputerName "pub.dev" -Count 1 -Quiet -ErrorAction SilentlyContinue
                        if ($testPub) {
                            Write-Host "    ✓ 可以访问 pub.dev" -ForegroundColor Green
                        } else {
                            Write-Host "    ✗ 无法访问 pub.dev" -ForegroundColor Red
                        }
                    } catch {
                        Write-Host "    ? 网络测试失败" -ForegroundColor Yellow
                    }
                    
                    # 检查 Git
                    try {
                        $gitTest = git --version 2>&1
                        Write-Host "    ✓ Git 可用: $gitTest" -ForegroundColor Green
                    } catch {
                        Write-Host "    ✗ Git 不可用" -ForegroundColor Red
                    }
                }
                
                if ($retry -lt $maxRetries) {
                    $waitTime = 3
                    Write-Host "  等待 ${waitTime} 秒后重试..." -ForegroundColor Yellow
                    Start-Sleep -Seconds $waitTime
                }
            }
        } catch {
            Write-Host "  ✗ pub get 异常: $($_.Exception.Message)" -ForegroundColor Red
            if ($retry -lt $maxRetries) {
                Write-Host "  等待 3 秒后重试..." -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }
        }
    }
    
    Pop-Location
    
    # 如果最终失败，抛出详细错误
    if (-not $pubGetSuccess) {
        Write-Host "`n========================================" -ForegroundColor Red
        Write-Host " flutter pub get 失败" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "`n已尝试的修复方法：" -ForegroundColor Yellow
        Write-Host "  1. 标准模式" -ForegroundColor Gray
        Write-Host "  2. 降级 build_runner 到兼容版本" -ForegroundColor Gray
        Write-Host "  3. 升级 Flutter 到最新版本" -ForegroundColor Gray
        Write-Host "  4. 删除 .dart_tool 和 pubspec.lock" -ForegroundColor Gray
        Write-Host "  5. 清理缓存后重试" -ForegroundColor Gray
        Write-Host "`n根本原因：" -ForegroundColor Yellow
        Write-Host "  Dart SDK 版本不兼容 - 当前 3.5.4，需要 >=3.6.0" -ForegroundColor Red
        Write-Host "`n手动解决步骤：" -ForegroundColor Yellow
        Write-Host "  方案 1 - 升级 Flutter（推荐）:" -ForegroundColor Cyan
        Write-Host "    flutter upgrade" -ForegroundColor Gray
        Write-Host "    flutter pub get" -ForegroundColor Gray
        Write-Host "`n  方案 2 - 修改 pubspec.yaml:" -ForegroundColor Cyan
        Write-Host "    将 build_runner 版本改为: ^2.4.0" -ForegroundColor Gray
        Write-Host "    然后运行: flutter pub get" -ForegroundColor Gray
        throw "flutter pub get 失败 - Dart SDK 版本不兼容"
    }

    # ----- 步骤 14-18: 构建 APK -----
    $CurrentStep = 14
    Write-Step "开始构建 Release APK（含 C++ 与 Gradle）" $CurrentStep $TotalSteps

    Push-Location $ProjectRoot
    if (-not [string]::IsNullOrWhiteSpace($AmapAndroidKey)) {
        $buildOutput = flutter build apk --release --dart-define=AMAP_ANDROID_KEY=$AmapAndroidKey 2>&1
    } else {
        $buildOutput = flutter build apk --release 2>&1
    }
    $buildExitCode = $LASTEXITCODE
    Pop-Location

    if ($buildExitCode -ne 0) {
        Write-Host $buildOutput -ForegroundColor Red
        if ($buildOutput -match "Missing class com\.amap\.api") {
            Write-Host "`n[提示] 高德地图 SDK 依赖缺失（与 Key 无关；Key 仅影响运行时定位）。请确认 app 的 build.gradle.kts 中已添加 implementation 高德 SDK。" -ForegroundColor Yellow
        }
        if ($buildOutput -match "x265|CMake|ninja") {
            Write-Host "`n[提示] C++ 原生模块编译失败。请确认 native/linkme_av_core/third_party/x265 已正确配置。" -ForegroundColor Yellow
        }
        throw "APK 构建失败，退出码: $buildExitCode"
    }

    Write-Host $buildOutput -ForegroundColor Gray
    Write-Host "  APK 构建成功。" -ForegroundColor Green

    # ----- 步骤 19: 定位输出 APK -----
    $CurrentStep = 19
    Write-Step "定位输出 APK" $CurrentStep $TotalSteps

    $apkPath = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        $apkFull = [System.IO.Path]::GetFullPath($apkPath)
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host " 打包成功！" -ForegroundColor Green
        Write-Host " APK 路径: $apkFull" -ForegroundColor Green
        Write-Host "========================================`n" -ForegroundColor Green
    } else {
        Write-Host "  未在默认路径找到 APK，请检查 build 输出。" -ForegroundColor Yellow
    }

    # ----- 步骤 20: 完成 -----
    $CurrentStep = 20
    Write-Step "打包流程完成" $CurrentStep $TotalSteps

} catch {
    $RollbackNeeded = $true
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host " 打包失败，请查看上方错误信息" -ForegroundColor Red
    Write-Host " 若权限不足，请右键 build_android.cmd -> 以管理员身份运行" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "`n错误: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
} finally {
    if ($RollbackNeeded) {
        Invoke-Rollback -Reason $_.Exception.Message
        exit 1
    }
}
