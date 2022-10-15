﻿<#
.SYNOPSIS
Calculate the standard deviation of numeric values.

.INPUTS
A collection of System.Double values

.OUTPUTS
System.Double

.LINK
Measure-Object

.EXAMPLE
Get-Process |% Handles |Measure-StandardDeviation.ps1

1206.54722086141
#>

#Requires -Version 3
[CmdletBinding()][OutputType([double])] Param(
# The numeric values to analyze.
[Parameter(Position=0,ValueFromRemainingArguments=$true,ValueFromPipeline=$true)]
[double] $InputObject
)
End
{
	[double] $average = $input |Measure-Object -Average |% Average
	Write-Verbose "Average = $average"
	[double[]] $deviations = $input |% {[math]::Pow(($_-$average),2)}
	Write-Verbose "Deviations = { $deviations }"
	[double] $variance = ($deviations |Measure-Object -Sum).Sum/$input.Count
	Write-Verbose "Variance = $variance"
	[double] $stddev = [math]::Sqrt($variance)
	Write-Verbose "Standard deviation = $stddev"
	$stddev
}
