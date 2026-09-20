param([single]$Inset = 0.17)
$ErrorActionPreference = 'Stop'
if ($Inset -le 0 -or $Inset -ge 1) { throw 'Inset must be between zero and one.' }
if (Get-Process CrownSiege -ErrorAction SilentlyContinue) { throw 'Close Crown Siege before applying the patch.' }
[Reflection.Assembly]::Load([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot '../lib/Mono.Cecil.dll'))) | Out-Null
$target = Join-Path $PSScriptRoot '../CrownSiege_Data/Managed/Assembly-CSharp.dll'
$backup = Join-Path $PSScriptRoot 'Assembly-CSharp.before-zoom-limit.dll'
if (!(Test-Path $backup)) { Copy-Item -LiteralPath $target -Destination $backup }
$a = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($backup)
$t = $a.MainModule.Types | Where-Object Name -eq 'SkillTreeCamera'
$m = $t.Methods | Where-Object Name -eq 'Awake'
$min = [Mono.Cecil.FieldReference]($t.Fields | Where-Object Name -eq 'minZoom')
$max = [Mono.Cecil.FieldReference]($t.Fields | Where-Object Name -eq 'maxZoom')
$normalize = @($m.Body.Instructions | Where-Object { $_.Operand -is [Mono.Cecil.MethodReference] -and $_.Operand.Name -eq 'NormalizeZoomSettings' })
if ($normalize.Count -ne 1) { throw 'Unexpected Awake method.' }
$anchor = $normalize[0].Previous
if ($anchor.OpCode -ne [Mono.Cecil.Cil.OpCodes]::Ldarg_0) { throw 'Unexpected normalization arguments.' }
$index = $m.Body.Instructions.IndexOf($anchor)
# A smaller orthographic size means greater magnification. Move the lower
# bound 17% into the original range, matching the reference slider position.
$ops = @(
 [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0)
 [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0)
 [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldfld, $min)
 [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0)
 [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldfld, $max)
 [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0)
 [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldfld, $min)
 [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Sub)
 [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldc_R4, $Inset)
 [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Mul)
 [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Add)
 [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Stfld, $min)
)
$il = $m.Body.GetILProcessor()
foreach ($op in $ops) { $il.InsertBefore($anchor, $op) }
$out = Join-Path $PSScriptRoot 'Assembly-CSharp.autobuy-fastzoom-limited.dll'
$a.Write($out); $a.Dispose()
$before = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($backup)
$after = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($out)
function AllTypes($types) { foreach ($t in $types) { $t; AllTypes $t.NestedTypes } }
function Signature($m) { ($m.Body.Instructions | ForEach-Object { "$($_.OpCode) $($_.Operand)" }) -join "`n" }
$lookup = @{}; foreach ($t in (AllTypes $after.MainModule.Types)) { $lookup[$t.FullName] = $t }
$count = 0
foreach ($t in (AllTypes $before.MainModule.Types)) { foreach ($m in $t.Methods) {
 $n = $lookup[$t.FullName].Methods | Where-Object FullName -eq $m.FullName
 if ($m.FullName -eq 'System.Void SkillTreeCamera::Awake()') {
  if ($n.Body.Instructions.Count -ne $m.Body.Instructions.Count + $ops.Count) { throw 'Invalid insertion size.' }
  for ($j=0; $j -lt $ops.Count; $j++) {
   $actual = $n.Body.Instructions[$index+$j]
   if ("$($actual.OpCode) $($actual.Operand)" -ne "$($ops[$j].OpCode) $($ops[$j].Operand)") { throw 'Invalid limit instructions.' }
  }
  for ($j=0; $j -lt $ops.Count; $j++) { $n.Body.Instructions.RemoveAt($index) }
 }
 if ((Signature $m) -ne (Signature $n)) { throw "Unexpected change: $($m.FullName)" }
 $count++
} }
$before.Dispose(); $after.Dispose()
Copy-Item -LiteralPath $out -Destination $target -Force
"PASS: $count methods verified. Only the Awake zoom-bound insertion changed; wheel sensitivity and auto-buy preserved."


