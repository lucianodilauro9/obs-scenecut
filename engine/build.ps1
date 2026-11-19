$csc="$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$meta="$env:SystemRoot\System32\WinMetadata"
$refs=@('Windows.AI','Windows.Foundation','Windows.Storage','Windows.Graphics','Windows.Media') | ForEach-Object {"/r:$meta\$_.winmd"}
foreach($name in @('System.Runtime','System.Runtime.InteropServices.WindowsRuntime','System.Runtime.WindowsRuntime','System.Collections','System.ObjectModel')) {$f=Get-ChildItem "$env:SystemRoot\Microsoft.NET\assembly\GAC_MSIL\$name" -Recurse -Filter "$name.dll" -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){$refs += '/r:'+$f.FullName}}
$ErrorActionPreference='Stop'
& $csc /nologo /optimize+ /platform:x64 /target:winexe "/out:$PSScriptRoot\SceneCutWorker.exe" @refs "$PSScriptRoot\Worker.cs"
if ($LASTEXITCODE) { throw "Compilazione fallita: $LASTEXITCODE" }
