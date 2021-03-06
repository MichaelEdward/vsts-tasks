[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation
try {
    Import-VstsLocStrings "$PSScriptRoot\Task.json"

    # Get the inputs.
    [string]$vsVersion = Get-VstsInput -Name VSVersion
    [string]$msBuildArchitecture = Get-VstsInput -Name MSBuildArchitecture
    [string]$msBuildArgs = Get-VstsInput -Name MSBuildArgs
    [string]$solution = Get-VstsInput -Name Solution -Require
    [string]$platform = Get-VstsInput -Name Platform
    [string]$configuration = Get-VstsInput -Name Configuration
    [bool]$clean = Get-VstsInput -Name Clean -AsBool
    [bool]$maximumCpuCount = Get-VstsInput -Name MaximumCpuCount -AsBool
    [bool]$restoreNugetPackages = Get-VstsInput -Name RestoreNugetPackages -AsBool
    [bool]$logProjectEvents = Get-VstsInput -Name LogProjectEvents -AsBool
    [bool]$createLogFile = Get-VstsInput -Name CreateLogFile -AsBool

    # Warn if deprecated inputs were specified.
    if ([string]$vsLocation = Get-VstsInput -Name VSLocation) {
        Write-Warning (Get-VstsLocString -Key VSLocationDeprecated0 -ArgumentList $vsLocation)
        $vsLocation = $null
    }

    if ([string]$msBuildLocation = Get-VstsInput -Name MSBuildLocation) {
        Write-Warning (Get-VstsLocString -Key MSBuildLocationDeprecated0 -ArgumentList $msBuildLocation)
        $msBuildLocation = $null
    }

    if ([string]$msBuildVersion = Get-VstsInput -Name MSBuildVersion) {
        Write-Warning (Get-VstsLocString -Key MSBuildVersionDeprecated0 -ArgumentList $msBuildVersion)
        $msBuildVersion = $null
    }

    # Import the helpers.
    . $PSScriptRoot\Get-VSPath.ps1
    . $PSScriptRoot\Select-MSBuildLocation.ps1
    . $PSScriptRoot\Select-VSVersion.ps1
    Import-Module -Name $PSScriptRoot\ps_modules\MSBuildHelpers\MSBuildHelpers.psm1

    # Resolve match patterns.
    $solutionFiles = Get-SolutionFiles -Solution $Solution

    # Only search Willow installs if 15.0 was explicitly chosen.
    $searchCom = $vsVersion -eq "15.0"

    # Resolve a VS version.
    $vsVersion = Select-VSVersion -PreferredVersion $vsVersion -SearchCom:$searchCom

    # Resolve the corresponding MSBuild location.
    $msBuildLocation = Select-MSBuildLocation -VSVersion $vsVersion -Architecture $msBuildArchitecture -SearchCom:$searchCom

    # Format the MSBuild args.
    $MSBuildArgs = Format-MSBuildArguments -MSBuildArguments $MSBuildArgs -Platform $Platform -Configuration $Configuration -VSVersion $VSVersion -MaximumCpuCount:$maximumCpuCount

    # Change the error action preference to 'Continue' so that each solution will build even if
    # one fails. Since the error action preference is being changed from 'Stop' (the default for
    # PowerShell3 handler) to 'Continue', errors will no longer be terminating and "Write-VstsSetResult"
    # needs to explicitly be called to fail the task. Invoke-BuildTools handles calling
    # "Write-VstsSetResult" on nuget.exe/msbuild.exe failure.
    $global:ErrorActionPreference = 'Continue'

    # Build each solution.
    Invoke-BuildTools -NuGetRestore:$RestoreNuGetPackages -SolutionFiles $solutionFiles -MSBuildLocation $MSBuildLocation -MSBuildArguments $MSBuildArgs -Clean:$Clean -NoTimelineLogger:(!$LogProjectEvents) -CreateLogFile:$createLogFile
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}