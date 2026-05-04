$ErrorActionPreference = 'Stop';
$packageName= 'log-viewer'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url64      = "https://github.com/bakhritdinov/log-viewer/releases/download/v[[VERSION]]/LogViewer-Windows-x64.exe"

$packageArgs = @{
  packageName   = $packageName
  fileType      = 'exe'
  url64bit      = $url64
  silentArgs    = '/S'
  validExitCodes= @(0)
  checksum64    = '[[CHECKSUM64]]'
  checksumType64= 'sha256'
}

Install-ChocolateyPackage @packageArgs
