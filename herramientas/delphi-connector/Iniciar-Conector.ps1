$ErrorActionPreference = 'Stop'
$node = Get-Command node -ErrorAction Stop
Write-Host 'Conector local de Delphi. Ctrl+C lo detiene. No abre puertos de red.'
& $node.Source (Join-Path $PSScriptRoot 'relay.cjs')
