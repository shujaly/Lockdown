# Compiles Launcher.cs into Lockdown.exe (with the Lockdown icon), using the C# compiler built into Windows.
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $dir 'Lockdown.exe'
$ico = Join-Path $dir 'Lockdown.ico'

$cp = New-Object System.CodeDom.Compiler.CompilerParameters
$cp.GenerateExecutable = $true
$cp.OutputAssembly = $out
$cp.CompilerOptions = "/target:winexe /optimize /win32icon:`"$ico`""
[void]$cp.ReferencedAssemblies.Add('System.dll')
[void]$cp.ReferencedAssemblies.Add('System.Core.dll')

$provider = New-Object Microsoft.CSharp.CSharpCodeProvider
$result = $provider.CompileAssemblyFromSource($cp, (Get-Content (Join-Path $dir 'Launcher.cs') -Raw))
if ($result.Errors.HasErrors) {
    $result.Errors | ForEach-Object { Write-Host $_.ToString() }
    exit 1
}
"Built $out"
