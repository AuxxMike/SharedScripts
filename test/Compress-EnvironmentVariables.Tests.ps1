﻿<#
.SYNOPSIS
Tests replacing each of the longest matching parts of a string with an embedded environment variable with that value.
#>

Write-Information "# env vars = $([Environment]::GetEnvironmentVariables().Count)" -infa Continue
[Environment]::GetEnvironmentVariables() |
	Out-String |
	Write-Information -infa Continue
Describe 'Compress-EnvironmentVariables' -Tag Compress-EnvironmentVariables {
	BeforeAll {
		if(!(Get-Module -List PSScriptAnalyzer)) {Install-Module PSScriptAnalyzer -Force}
		$scriptsdir,$sep = (Split-Path $PSScriptRoot),[io.path]::PathSeparator
		$ScriptName = Join-Path $scriptsdir Compress-EnvironmentVariables.ps1
		if($scriptsdir -notin ($env:Path -split $sep)) {$env:Path += "$sep$scriptsdir"}
	}
	Context 'Comment-based help' -Tag CommentHelp {
		It "Should produce help object" {
			Get-Help $ScriptName |Should -Not -BeOfType string `
				-Because 'Get-Help should not fall back to the default help string'
		}
	}
	Context 'Script style' -Tag Style {
		It "Should follow best practices for style" {
			Invoke-ScriptAnalyzer -Path $ScriptName -Severity Warning |
				ForEach-Object {$_.Severity,$_.ScriptName,$_.Line,$_.Column,$_.RuleName,$_.Message -join ':'} |
				Should -BeExactly $null -Because 'there should be no style warnings'
			Invoke-ScriptAnalyzer -Path $ScriptName -Severity Error |
				ForEach-Object {$_.Severity,$_.ScriptName,$_.Line,$_.Column,$_.RuleName,$_.Message -join ':'} |
				Should -BeExactly $null -Because 'there should be no style errors'
		}
	}
	Context 'Replaces each of the longest matching parts of a string with an embedded environment variable with that value' -Tag EnvironmentVariables {
		It "For '<Value>', returns '<Result>'" -TestCases @(
			@{ Value ="[$env:APPDATA]"; Result = '[%APPDATA%]' }
			@{ Value ="[$env:COMPUTERNAME]"; Result = '[%COMPUTERNAME%]' }
			@{ Value ="$env:TEMP\tempdata"; Result = '%TEMP%\tempdata' }
		) {
			Param([string] $Value, [string] $Result)
			throw "$([Environment]::GetEnvironmentVariables() |Out-String)"
			Compress-EnvironmentVariables.ps1 $Value |Should -Be $Result
		}
	}
}
