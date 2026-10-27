# Builds the portfolio demo of Rota Manager.
#
# Usage (from PowerShell, in this folder):
#   .\build_demo.ps1                       # served at /rota-demo/
#   .\build_demo.ps1 -BaseHref "/"         # served at the root of a subdomain
#
# Output: build\web-demo (the site) and build\rota-demo.zip (to upload
# to cPanel and extract with File Manager).

param(
    [string]$BaseHref = "/rota-demo/"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Invoke-Step([string]$Name, [scriptblock]$Command) {
    Write-Host "`n== $Name ==" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "$Name failed (exit code $LASTEXITCODE)" }
}

if (-not ($BaseHref.StartsWith("/") -and $BaseHref.EndsWith("/"))) {
    throw "BaseHref must start and end with a slash, e.g. /rota-demo/"
}

Invoke-Step "Getting packages" { flutter pub get }
Invoke-Step "Testing the demo backend" { flutter test test/demo_backend_test.dart }
Invoke-Step "Building the demo" {
    flutter build web --release --dart-define=DEMO=true --base-href $BaseHref --output build/web-demo
}

$zip = "build/rota-demo.zip"
Compress-Archive -Path "build/web-demo/*" -DestinationPath $zip -Force

Write-Host "`nDone." -ForegroundColor Green
Write-Host "Site:   build\web-demo"
Write-Host "Upload: $zip  (extract it into the folder served at $BaseHref)"
