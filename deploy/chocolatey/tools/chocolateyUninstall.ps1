$ErrorActionPreference = 'Stop'
$packageName = 'log-viewer'

$packageArgs = @{
  packageName    = $packageName
  softwareName   = 'LogViewer*'
  fileType       = 'exe'
  silentArgs     = '/S'
  validExitCodes = @(0)
}

# Locate the NSIS uninstaller via Windows registry. Without an explicit `file`
# argument, Uninstall-ChocolateyPackage cannot find the executable, leaving the
# previous version registered in Add/Remove Programs after `choco upgrade`.
[array]$keys = Get-UninstallRegistryKey -SoftwareName $packageArgs.softwareName

if ($keys.Count -eq 1) {
  $packageArgs.file = "$($keys[0].UninstallString)"
  Uninstall-ChocolateyPackage @packageArgs
} elseif ($keys.Count -eq 0) {
  Write-Warning "$packageName is not registered in the system; nothing to remove."
} else {
  Write-Warning "$($keys.Count) installations of LogViewer found — skipping auto-uninstall."
  Write-Warning "Resolve manually: $($keys | ForEach-Object { $_.DisplayName } | Sort-Object -Unique)"
}
