<#
    .SYNOPSIS
    Searches WMI for versions for legacy versions of Adobe Reader
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
Write-Output "Starting detection of orphaned Zoom registry keys"

if(Get-WmiObject -Class Win32_Product -Filter "Name LIKE 'Adobe Reader%'"){
    Write-Output "Adobe Reader detected"
    Stop-Transcript
    Exit 1
}
else{
    Write-Output "Adobe Reader not detected"
    Stop-Transcript
    Exit 0
}