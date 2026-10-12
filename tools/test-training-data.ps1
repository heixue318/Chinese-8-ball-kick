$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$out = '.tools/training-data-test'
New-Item -ItemType Directory -Force $out | Out-Null
& '.\experiments\tailuge-lab\node_modules\.bin\tsc.cmd' --target ES2022 --module commonjs --moduleResolution node --esModuleInterop --outDir $out training-data/zhongba-drills.ts training-data/zhongba-drills.test.ts
if ($LASTEXITCODE -ne 0) { throw '训练球型数据编译失败。' }
$env:NODE_PATH = (Resolve-Path '.\experiments\tailuge-lab\node_modules')
& node "$out/training-data/zhongba-drills.test.js"
if ($LASTEXITCODE -ne 0) { throw '训练球型数据测试失败。' }
