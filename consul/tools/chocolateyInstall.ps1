$Tools = $(Split-Path -Parent $MyInvocation.MyCommand.Definition) 
$Base = $(Split-Path -Parent $Tools) 

$PackageName = "consul"
$PackageVersion = $(Split-Path -Leaf $Base).Split(".", 2)[1] 

$PackageUrl = "https://dl.bintray.com/mitchellh/consul/$($PackageVersion)_windows_386.zip"
$PackageUIUrl = "https://dl.bintray.com/mitchellh/consul/$($PackageVersion)_web_ui.zip"

# Get Consul
Install-ChocolateyZipPackage "$PackageName" "$PackageUrl" "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"

# Get the Web UI
Install-ChocolateyZipPackage "$PackageName.UI" "$PackageUIUrl" "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"

# Install Args
$ia = $env:chocolateyInstallArguments;
Function Get-Argv([string]$key, [string]$default = '') {
    return Invoke-Expression "function Get_Argv($('$'+$key)='$default'){ $('$'+$key) } Get_Argv $ia"
}
Function Have-Argv([string]$key) {
    return "$ia" -match "(^|\W)-$key($|\W)"
}
Function AllBut-Argv([string[]]$keys) {
    $params = ($keys | % { '$' + $_ + "=''" }) -join ","
    return Invoke-Expression "function AllBut_Argv($params){ $('$MyInvocation').UnboundArguments } AllBut_Argv $ia"
}

# Install the service
$ServiceName = "Consul"

$AppLocation = "$Tools\consul.exe"
$UILocation = "$Tools\dist"

$InstallLocation = Get-Argv -key "base" -default "$Tools"
$ConfigLocation = "$InstallLocation\config"
$DataLocation = "$InstallLocation\data"

New-Item -ItemType Directory -Force -Path $ConfigLocation
New-Item -ItemType Directory -Force -Path $DataLocation

if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName") {
	Stop-Service $ServiceName -ErrorAction SilentlyContinue
    nssm remove $ServiceName confirm -ErrorAction SilentlyContinue
}

Write-Host "Installing Consul as service..." 

$Params = @( 
    "agent", 
    "$(AllBut-Argv @("base"))",   
    "-config-dir=$ConfigLocation",
    "-data-dir=$DataLocation",    
    "-ui-dir=$UILocation",
    "-log-level=err")

nssm install $ServiceName $AppLocation ($Params -join " ")

# Update service params
$PP = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName\Parameters"
Set-ItemProperty -Path $PP -Name "AppStopMethodSkip" -Value 00000014
Set-ItemProperty -Path $PP -Name "AppStdout" -Value "$DataLocation\out.log"
Set-ItemProperty -Path $PP -Name "AppStderr" -Value "$DataLocation\error.log"
Set-ItemProperty -Path $PP -Name "AppEnvironmentExtra" -type MultiString -Value "GOMAXPROCS=2"
Set-ItemProperty -Path $PP -Name "AppRotate" -Value 1
Set-ItemProperty -Path $PP -Name "AppRotateBytes " -Value 100000000

# Start the service
Start-Service $ServiceName