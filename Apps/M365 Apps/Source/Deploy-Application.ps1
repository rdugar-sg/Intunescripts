﻿<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall','Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Microsoft'
	[string]$appName = 'Microsoft 365 Apps for Enterprise'
	[string]$appVersion = 'Version 2203 (Build 15028.20248)'
	[string]$appArch = 'x64'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '18/05/2022'
	[string]$appScriptAuthor = 'Murray Clifford'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.4'
	[string]$deployAppScriptDate = '26/01/2021'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Remove legacy Office Click to Run installations
		$C2RKey = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration\"
		if(Test-Path $C2RKey){
			if([System.Version](Get-ItemProperty -Path $C2RKey).VersionToReport -lt [System.Version]"16.0.15028.20248"){
				Show-InstallationProgress "Uninstalling Microsoft Office Click to Run"
				Write-Log "Legacy Microsoft Office Click to Run was detected. Uninstalling..."
				Execute-Process -FilePath "CScript.exe" -Arguments "`"$dirSupportFiles\OffScrubc2r.vbs`" CLIENTALL /S /Q /NoCancel" -WindowStyle Hidden -IgnoreExitCodes "1,2,3"	
			}
		}

		## Remove Office 2016 MSI installations
		if(Test-Path "$envProgramFilesX86\Microsoft Office\Office16\WINWORD.exe"){
			Show-InstallationProgress "Uninstalling Microsoft Office 2016"
			Write-Log "Microsoft Office 2016 was detected. Uninstalling..."
			Execute-Process -FilePath "CScript.exe" -Arguments "`"$dirSupportFiles\OffScrub_O16msi.vbs`" CLIENTALL /S /Q /NoCancel" -WindowStyle Hidden -IgnoreExitCodes "1,2,3"
		}

		if(Test-Path "$envProgramFiles\Microsoft Office\Office16\WINWORD.exe"){
			Show-InstallationProgress "Uninstalling Microsoft Office 2016"
			Write-Log "Microsoft Office 2016 was detected. Uninstalling..."
			Execute-Process -FilePath "CScript.exe" -Arguments "`"$dirSupportFiles\OffScrub_O16msi.vbs`" CLIENTALL /S /Q /NoCancel" -WindowStyle Hidden -IgnoreExitCodes "1,2,3"
		}

		## Remove Office 2013  MSI installations
		if(Test-Path "$envProgramFilesX86\Microsoft Office\Office15\WINWORD.exe"){
			Show-InstallationProgress "Uninstalling Microsoft Office 2013"
			Write-Log "Microsoft Office 2013 was detected. Uninstalling..."
			Execute-Process -FilePath "CScript.exe" -Arguments "`"$dirSupportFiles\OffScrub_O15msi.vbs`" CLIENTALL /S /Q /NoCancel" -WindowStyle Hidden -IgnoreExitCodes "1,2,3"
		}

		if(Test-Path "$envProgramFiles\Microsoft Office\Office15\WINWORD.exe"){
			Show-InstallationProgress "Uninstalling Microsoft Office 2013"
			Write-Log "Microsoft Office 2013 was detected. Uninstalling..."
			Execute-Process -FilePath "CScript.exe" -Arguments "`"$dirSupportFiles\OffScrub_O15msi.vbs`" CLIENTALL /S /Q /NoCancel" -WindowStyle Hidden -IgnoreExitCodes "1,2,3"
		}

		## Remove Office 2010  MSI installations
		if(Test-Path "$envProgramFilesX86\Microsoft Office\Office14\WINWORD.exe"){
			Show-InstallationProgress "Uninstalling Microsoft Office 2010"
			Write-Log "Microsoft Office 2010 was detected. Uninstalling..."
			Execute-Process -FilePath "CScript.exe" -Arguments "`"$dirSupportFiles\OffScrub10.vbs`" CLIENTALL /S /Q /NoCancel" -WindowStyle Hidden -IgnoreExitCodes "1,2,3"
		}

		if(Test-Path "$envProgramFiles\Microsoft Office\Office14\WINWORD.exe"){
			Show-InstallationProgress "Uninstalling Microsoft Office 2010"
			Write-Log "Microsoft Office 2010 was detected. Uninstalling..."
			Execute-Process -FilePath "CScript.exe" -Arguments "`"$dirSupportFiles\OffScrub10.vbs`" CLIENTALL /S /Q /NoCancel" -WindowStyle Hidden -IgnoreExitCodes "1,2,3"
		}

		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Install Microsoft 365 Apps for Enterprise with content from the Office CDN
		Execute-Process -Path "setup.exe" -Parameters "/configure M365_Config.xml"

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>

	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		# Uninstall Microsoft 365 Apps for Enterprise
		Execute-Process -Path "setup.exe" -Parameters "/configure M365_Uninstall.xml"

		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>


	}
	ElseIf ($deploymentType -ieq 'Repair')
	{
		##*===============================================
		##* PRE-REPAIR
		##*===============================================
		[string]$installPhase = 'Pre-Repair'

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Repair tasks here>

		##*===============================================
		##* REPAIR
		##*===============================================
		[string]$installPhase = 'Repair'

		## Handle Zero-Config MSI Repairs
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		# <Perform Repair tasks here>

		##*===============================================
		##* POST-REPAIR
		##*===============================================
		[string]$installPhase = 'Post-Repair'

		## <Perform Post-Repair tasks here>


    }
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}
