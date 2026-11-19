$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
& (Join-Path $root 'engine/build.ps1')
$files=@('scenecut.lua','scenecut.effect','engine/bridge.lua','engine/SceneCutWorker.exe','engine/portrait.onnx','engine/portrait.onnx.license','engine/Apache-2.0.txt','README.md')
$resources=$files | ForEach-Object { '/resource:'+(Join-Path $root $_)+','+$_ }
$csc="$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
& $csc /nologo /optimize+ /platform:x64 /target:winexe /r:System.Windows.Forms.dll /r:System.Drawing.dll "/out:$root\SceneCut-Setup.exe" @resources (Join-Path $root 'packaging\Setup.cs')
if ($LASTEXITCODE) {throw "Creazione installer fallita: $LASTEXITCODE"}
