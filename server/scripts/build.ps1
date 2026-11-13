# 仓颉服务端编译脚本（cjpm 不可用时的兜底）
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
#   powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1 -CangjieHome "D:\Cangjie"
#
# 之所以不用 cjpm：当前这台机器的 cjpm / 仓颉运行时启动时会 0xC0000005，
# 但 cjc 编译器本身可用。这个脚本按依赖顺序编译各个 package，
# 生成 build/campus_demo.exe。换到正常环境后可以直接 cjpm build。

param(
    [string]$CangjieHome = "C:\Program Files (x86)\Cangjie"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root "build"
New-Item -ItemType Directory -Force -Path $build | Out-Null

$cjc = Join-Path $CangjieHome "bin\cjc.exe"
if (-not (Test-Path $cjc)) {
    throw "cjc not found: $cjc. Pass -CangjieHome <path>."
}

$env:PATH = "$CangjieHome\runtime\lib\windows_x86_64_cjnative;$CangjieHome\bin;$CangjieHome\tools\bin;$CangjieHome\tools\lib;$env:PATH"

function Invoke-Cjc {
    param([string[]]$Arguments)
    & $cjc @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "cjc failed: $($Arguments -join ' ')"
    }
}

$domain = Join-Path $root "src\domain"
$repository = Join-Path $root "src\repository"
$service = Join-Path $root "src\service"
$api = Join-Path $root "src\api"
$src = Join-Path $root "src"

Write-Host "[1/5] domain"
Invoke-Cjc @(
    "-p", $domain,
    "--output-type=staticlib",
    "-o", (Join-Path $build "libcampus_domain.a")
)

Write-Host "[2/5] repository"
Invoke-Cjc @(
    "-p", $repository,
    "--import-path", $build,
    "-L", $build,
    "-l", "campus_domain",
    "--output-type=staticlib",
    "-o", (Join-Path $build "libcampus_repository.a")
)

Write-Host "[3/5] service"
Invoke-Cjc @(
    "-p", $service,
    "--import-path", $build,
    "-L", $build,
    "-l", "campus_repository",
    "-l", "campus_domain",
    "--output-type=staticlib",
    "-o", (Join-Path $build "libcampus_service.a")
)

Write-Host "[4/5] api"
Invoke-Cjc @(
    "-p", $api,
    "--import-path", $build,
    "-L", $build,
    "-l", "campus_service",
    "-l", "campus_repository",
    "-l", "campus_domain",
    "--output-type=staticlib",
    "-o", (Join-Path $build "libcampus_api.a")
)

Write-Host "[5/5] main"
Invoke-Cjc @(
    "-p", $src,
    "--import-path", $build,
    "-L", $build,
    "-l", "campus_api",
    "-l", "campus_service",
    "-l", "campus_repository",
    "-l", "campus_domain",
    "-o", (Join-Path $build "campus_demo.exe")
)

Write-Host ""
Write-Host "OK -> $build\campus_demo.exe"
Write-Host "Run it with the Cangjie runtime on PATH:"
Write-Host "  $CangjieHome\runtime\lib\windows_x86_64_cjnative"
