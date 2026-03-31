# Launcher: read build_android.ps1 as UTF-8 to fix encoding/parse errors on Chinese Windows
$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "build_android.ps1"
$content = [System.IO.File]::ReadAllText($scriptPath, [System.Text.Encoding]::UTF8)
$scriptBlock = [ScriptBlock]::Create($content)
$argList = @("-ScriptDir", $PSScriptRoot) + $args
& $scriptBlock @argList
