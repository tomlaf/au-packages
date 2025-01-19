﻿$ErrorActionPreference = 'Stop';
$toolsDir     = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$minimumOsVersion = "10.0.19041" # 20H1
$osVersion = (Get-CimInstance Win32_OperatingSystem).Version
if ([Version] $osVersion -lt [version] $minimumOsVersion) {
  Write-Error "Microsoft Teams New Client requires a minimum of Windows 10 20H1 version $minimumOsVersion. You have $osVersion"
}

$checksum32 = 'E7F8AA05BDF853212D5E978BDC2D46A58F47C8F96826192FA49FC4B0C78C3879'
$downloadPath = Join-Path $toolsDir "teamsbootstrapper.exe"

$pp = Get-PackageParameters

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  softwareName  = 'microsoft-teams-new-bootstrapper*'
  fileType      = 'exe'
  
  url           = "https://statics.teams.cdn.office.net/production-teamsprovision/lkg/teamsbootstrapper.exe"
  checksum      = $checksum32
  checksumType  = 'sha256'
  FileFullPath  = $downloadPath
}

Get-ChocolateyWebFile @packageArgs

& $downloadPath -p

if($pp['VDI']){
  $teamsVersion = Get-AppXPackage -Name "*msteams*" | Select-Object -ExpandProperty Version
  # Check if $teamsVersion is empty and attempt an alternative method if so
  if (-not $teamsVersion) {
      # Retrieve the newest Teams folder based on LastWriteTime
      $teamsFolders = Get-ChildItem -Path "C:\Program Files\WindowsApps\" -Filter "MSTEAMS*" -Directory | Sort-Object LastWriteTime -Descending
      if ($teamsFolders.Count -gt 0) {
          $newestVersionFolder = $teamsFolders[0].FullName
          $teamsVersion = ($newestVersionFolder -split "_")[1] # Extract version from folder name
          $meetingInstaller = Join-Path -Path $newestVersionFolder -ChildPath "MICROSOFTTEAMSMEETINGADDININSTALLER.MSI"
      } else {
          Write-Error "Teams version could not be determined. Please check if Teams is installed."
          return
      }
  } else {
      # Construct meeting installer path using the AppX package version
      $meetingInstaller = "$($env:ProgramFiles)\WINDOWSAPPS\MSTEAMS_$($teamsVersion)_X64__8WEKYB3D8BBWE\MICROSOFTTEAMSMEETINGADDININSTALLER.MSI"
  }
  
  $meetingVersion = (Get-AppLockerFileInformation -Path $meetingInstaller | Select-Object -ExpandProperty Publisher | Select-Object -ExpandProperty BinaryVersion).ToString()
  $packageArgsMeeting =@{
    packageName  = $env:ChocolateyPackageName +"_MeetingAddIn"
    fileType     = "msi"
    file         = $meetingInstaller
    SilentArgs   = "/qn /norestart ALLUSERS=1  TARGETDIR=`"$($env:ProgramFiles)\Microsoft\TeamsMeetingAdd-in\$($meetingVersion)\`" /l*v `"$($env:TEMP)\$($packageName).meetingAddin_$($meetingVersion).MsiInstall.log`""
  }

  Install-ChocolateyInstallPackage @packageArgsMeeting 
}