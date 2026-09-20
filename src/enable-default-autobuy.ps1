$ErrorActionPreference = 'Stop'
[Reflection.Assembly]::Load([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot '../lib/Mono.Cecil.dll'))) | Out-Null
$target = Join-Path $PSScriptRoot '../CrownSiege_Data/Managed/Assembly-CSharp.dll'
$backup = Join-Path $PSScriptRoot 'Assembly-CSharp.original.dll'
if (Get-Process CrownSiege -ErrorAction SilentlyContinue) { throw 'Close Crown Siege before applying the patch.' }
if (!(Test-Path $backup)) { Copy-Item -LiteralPath $target -Destination $backup }
$a = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($backup)
$mod = $a.MainModule
function Method($type, $name) { @($type.Methods | Where-Object Name -eq $name)[0] }
function CloneMethod($type, $sourceName, $newName) {
 $src = Method $type $sourceName
 $dst = [Mono.Cecil.MethodDefinition]::new($newName, $src.Attributes, $src.ReturnType)
 $dst.Body.InitLocals = $src.Body.InitLocals
 $dst.Body.MaxStackSize = $src.Body.MaxStackSize
 $map = @{}
 foreach ($v in $src.Body.Variables) { $nv = [Mono.Cecil.Cil.VariableDefinition]::new($v.VariableType); $dst.Body.Variables.Add($nv); $map[$v] = $nv }
 foreach ($i in $src.Body.Instructions) { $ni = [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Nop); $ni.OpCode = $i.OpCode; $ni.Operand = $i.Operand; $dst.Body.Instructions.Add($ni); $map[$i] = $ni }
 foreach ($i in $dst.Body.Instructions) { if ($null -ne $i.Operand -and $map.ContainsKey($i.Operand)) { $i.Operand = $map[$i.Operand] } }
 $type.Methods.Add($dst)
 return $dst
}
$keyboard = $mod.Types | Where-Object Name -eq 'KeyboardButtonTrigger'
$button = $mod.Types | Where-Object Name -eq 'SpawnUnitButton'
$manager = $mod.Types | Where-Object Name -eq 'GameManager'
$start = [Mono.Cecil.MethodDefinition]::new('StartDefaultAutoBuy', [Mono.Cecil.MethodAttributes]134, $mod.TypeSystem.Void)
$keyboard.Methods.Add($start)
$il = $start.Body.GetILProcessor()
foreach ($name in @('isHolding','isLatched')) {
 $il.Emit([Mono.Cecil.Cil.OpCodes]::Ldarg_0)
 $il.Emit([Mono.Cecil.Cil.OpCodes]::Ldc_I4_1)
 $il.Emit([Mono.Cecil.Cil.OpCodes]::Stfld, [Mono.Cecil.FieldReference]($keyboard.Fields | Where-Object Name -eq $name))
}
$il.Emit([Mono.Cecil.Cil.OpCodes]::Ldarg_0)
$il.Emit([Mono.Cecil.Cil.OpCodes]::Ldc_R4, [single]0)
$il.Emit([Mono.Cecil.Cil.OpCodes]::Stfld, [Mono.Cecil.FieldReference]($keyboard.Fields | Where-Object Name -eq 'nextRepeatTime'))
$il.Emit([Mono.Cecil.Cil.OpCodes]::Ret)
$startButton = CloneMethod $button 'StopLock' 'StartDefaultAutoBuy'
foreach ($i in $startButton.Body.Instructions) {
 if ($i.Operand -is [Mono.Cecil.MethodReference]) {
  if ($i.Operand.Name -eq 'StopHolding') { $i.Operand = $start }
  if ($i.Operand.Name -eq 'ResetLockVisuals') { $i.Operand = Method $button 'Update' }
 }
}
$startAll = CloneMethod $manager 'StopSpawnUnitButtonLocks' 'StartDefaultAutoBuy'
foreach ($i in $startAll.Body.Instructions) { if ($i.Operand -is [Mono.Cecil.MethodReference] -and $i.Operand.Name -eq 'StopLock') { $i.Operand = $startButton } }
$restart = Method $manager 'RestartGame'
$last = $restart.Body.Instructions[$restart.Body.Instructions.Count - 1]
if ($last.OpCode -ne [Mono.Cecil.Cil.OpCodes]::Ret) { throw 'Unexpected RestartGame body' }
$il = $restart.Body.GetILProcessor()
$il.InsertBefore($last, [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
$il.InsertBefore($last, [Mono.Cecil.Cil.Instruction]::Create([Mono.Cecil.Cil.OpCodes]::Call, $startAll))
$out = Join-Path $PSScriptRoot 'Assembly-CSharp.patched.dll'
$a.Write($out)
$a.Dispose()
$check = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($out)
foreach ($name in @('KeyboardButtonTrigger','SpawnUnitButton','GameManager')) {
 $type = $check.MainModule.Types | Where-Object Name -eq $name
 if (!(Method $type 'StartDefaultAutoBuy')) { throw "Missing patch in $name" }
}
$check.Dispose()
Copy-Item -LiteralPath $out -Destination $target -Force
Get-FileHash $backup,$target




