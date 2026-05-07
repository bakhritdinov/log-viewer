$ErrorActionPreference = 'Stop'

# Stop any running LogViewer instance so the NSIS uninstaller / installer
# can replace files on `choco upgrade`. Silently ignored if not running.
Get-Process -Name "LogViewer" -ErrorAction SilentlyContinue |
  Stop-Process -Force -ErrorAction SilentlyContinue
