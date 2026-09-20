param([single]$Multiplier = 12)
$ErrorActionPreference = 'Stop'
if ($Multiplier -le 0) { throw 'Multiplier must be positive.' }
if (Get-Process CrownSiege -ErrorAction SilentlyContinue) { throw 'Close Crown Siege before applying the patch.' }
[Reflection.Assembly]::Load([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot '../lib/Mono.Cecil.dll'))) | Out-Null
$target = Join-Path $PSScriptRoot '../CrownSiege_Data/Managed/Assembly-CSharp.dll'
$backup = Join-Path $PSScriptRoot 'Assembly-CSharp.before-zoom.dll'
if (!(Test-Path $backup)) { Copy-Item -LiteralPath $target -Destination $backup }
$a = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($backup)
$type = $a.MainModule.Types | Where-Object Name -eq 'SkillTreeCamera'
$method = $type.Methods | Where-Object Name -eq 'HandleZoom'
$reads = @($method.Body.Instructions | Where-Object { $_.OpCode -eq [Mono.Cecil.Cil.OpCodes]::Ldfld -and $_.Operand.Name -eq 'zoomSpeed' })
if ($reads.Count -ne 1) { throw 'Unexpected zoom method.' }
$il = $method.Body.GetILProcessor()
$factor = [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldc_R4, $Multiplier)
$il.InsertAfter($reads[0], $factor)
$il.InsertAfter($factor, [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Mul))
# Wheel input is an event delta, not a per-second velocity. Use a fixed
# 60-FPS reference interval so high frame rates cannot weaken each notch.
$timeReads = @($method.Body.Instructions | Where-Object { $_.Operand -is [Mono.Cecil.MethodReference] -and $_.Operand.FullName -eq 'System.Single UnityEngine.Time::get_deltaTime()' })
if ($timeReads.Count -ne 1) { throw 'Unexpected wheel timing calculation.' }
$timeReads[0].OpCode = [Mono.Cecil.Cil.OpCodes]::Ldc_R4
$timeReads[0].Operand = [single](1.0 / 60.0)
$out = Join-Path $PSScriptRoot 'Assembly-CSharp.autobuy-fastzoom.dll'
$a.Write($out)
$a.Dispose()
$before = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($backup)
$after = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($out)
function AllTypes($types) { foreach ($t in $types) { $t; AllTypes $t.NestedTypes } }
function Signature($m) { ($m.Body.Instructions | ForEach-Object { "$($_.OpCode) $($_.Operand)" }) -join "`n" }
$typesAfter = @{}; foreach ($t in (AllTypes $after.MainModule.Types)) { $typesAfter[$t.FullName] = $t }
$count = 0
foreach ($t in (AllTypes $before.MainModule.Types)) {
 foreach ($m in $t.Methods) {
  $n = $typesAfter[$t.FullName].Methods | Where-Object FullName -eq $m.FullName
  if ($m.FullName -eq 'System.Void SkillTreeCamera::HandleZoom()') {
   $instructions = @($n.Body.Instructions)
   $index = 0
   while ($instructions[$index].Operand.Name -ne 'zoomSpeed') { $index++ }
   if ($instructions[$index+1].OpCode -ne [Mono.Cecil.Cil.OpCodes]::Ldc_R4 -or $instructions[$index+1].Operand -ne $Multiplier -or $instructions[$index+2].OpCode -ne [Mono.Cecil.Cil.OpCodes]::Mul) { throw 'Invalid multiplier' }
   $filtered = @($instructions | Where-Object { $_ -ne $instructions[$index+1] -and $_ -ne $instructions[$index+2] })
   $originalTime = @($m.Body.Instructions | Where-Object { $_.Operand -is [Mono.Cecil.MethodReference] -and $_.Operand.FullName -eq 'System.Single UnityEngine.Time::get_deltaTime()' })
   if ($originalTime.Count -ne 1) { throw 'Unexpected original timing calculation.' }
   $timeIndex = $m.Body.Instructions.IndexOf($originalTime[0])
   if ($filtered[$timeIndex].OpCode -ne [Mono.Cecil.Cil.OpCodes]::Ldc_R4 -or $filtered[$timeIndex].Operand -ne [single](1.0 / 60.0)) { throw 'Invalid fixed wheel interval.' }
   $originalTime[0].OpCode = [Mono.Cecil.Cil.OpCodes]::Ldc_R4
   $originalTime[0].Operand = [single](1.0 / 60.0)
   if (($filtered | ForEach-Object { "$($_.OpCode) $($_.Operand)" }) -join "`n" -ne (Signature $m)) { throw 'Unexpected zoom changes' }
  } elseif ((Signature $m) -ne (Signature $n)) { throw "Unexpected method change: $($m.FullName)" }
  $count++
 }
}
$before.Dispose(); $after.Dispose()
Copy-Item -LiteralPath $out -Destination $target -Force
"PASS: $count methods checked; mouse-wheel zoom uses multiplier $Multiplier and a fixed 60-FPS reference interval. Auto-buy patch preserved."


