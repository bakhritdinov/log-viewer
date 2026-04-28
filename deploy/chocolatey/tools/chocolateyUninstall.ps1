$ErrorActionPreference = 'Stop';
$packageName = 'log-viewer'

$packageArgs = @{
  packageName   = $packageName
  fileType      = 'exe'
  silentArgs    = '/S'
}

Uninstall-ChocolateyPackage @packageArgs
