<#
    .SYNOPSIS
    Searches local device for Mitel installation directories
#>

# Check if PowerShell is running as a 32-bit process and restart as a 64-bit process
if (!([System.Environment]::Is64BitProcess)) {
    if ([System.Environment]::Is64BitOperatingSystem) {
        Write-Output "Relaunching process as 64-bit process"
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($MyInvocation.MyCommand.Definition)`""
        $ProcessPath = $(Join-Path -Path $Env:SystemRoot -ChildPath "\Sysnative\WindowsPowerShell\v1.0\powershell.exe")
        $params = @{
            FilePath     = $ProcessPath
            ArgumentList = $Arguments
            Wait         = $True
            WindowStyle  = "Hidden"
        }
        Start-Process @params
        exit 0
    }
}

# Start Logging
Start-Transcript -Path "$Env:Programdata\Microsoft\IntuneManagementExtension\Logs\$($MyInvocation.MyCommand.Name).log" -Append
Write-Output "Starting detection of Mitel installation directory"

# Define Mitel installation directory
$MitelPath = "C:\Program Files (x86)\Mitel"

# Check for presence of Mitel installation directory
try {
    if(Test-Path $MitelPath){
        Write-Output "Non Compliant: Mitel application directory found on device"
        Stop-Transcript
        Exit 1
    }
    else{
        Write-Output "Compliant: Mitel application directory not found on device"
        Stop-Transcript
        Exit 0
    }
}
catch {
    $errMsg = $_.exeption.essage
    Write-Output $errMsg
    Stop-Transcript
    Exit 2000
}