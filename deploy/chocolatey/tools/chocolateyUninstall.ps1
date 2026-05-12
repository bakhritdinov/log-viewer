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

function Get-UninstallerExePath {
  param([string]$UninstallString)
  # UninstallString often looks like: "C:\Program Files\LogViewer\uninst.exe" /S
  # Strip surrounding quotes and trailing arguments to get the bare exe path.
  $trimmed = $UninstallString.Trim()
  if ($trimmed.StartsWith('"')) {
    $endQuote = $trimmed.IndexOf('"', 1)
    if ($endQuote -gt 0) { return $trimmed.Substring(1, $endQuote - 1) }
  }
  return ($trimmed -split '\s+', 2)[0]
}

if ($keys.Count -eq 1) {
  $exePath = Get-UninstallerExePath $keys[0].UninstallString
  if (Test-Path -LiteralPath $exePath) {
    $packageArgs.file = "$($keys[0].UninstallString)"
    Uninstall-ChocolateyPackage @packageArgs
  } else {
    # User deleted the install directory manually but the Add/Remove Programs
    # entry stayed behind. Skip the system uninstaller (it would fail trying
    # to launch a missing exe) so `choco uninstall` / upgrade can proceed.
    Write-Warning "$packageName uninstaller '$exePath' is missing; skipping system uninstall."
  }
} elseif ($keys.Count -eq 0) {
  Write-Warning "$packageName is not registered in the system; nothing to remove."
} else {
  $names = ($keys | ForEach-Object { $_.DisplayName } | Sort-Object -Unique) -join ', '
  Write-Warning "$($keys.Count) installations of LogViewer found - skipping auto-uninstall."
  Write-Warning "Resolve manually: $names"
}
