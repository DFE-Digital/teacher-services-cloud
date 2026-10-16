param(
    [string]$ResourceGroup,
    [string]$WafPolicyName,
    [string]$InputFile,
    [string]$RuleName,
    [ValidateRange(0, 1000)]
    [int]$RulePriority ,
    [ValidateSet('Allow', 'Block', 'Log')]
    [string]$RuleAction = 'Allow',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Import-Module Az.FrontDoor -ErrorAction Stop

if (-not (Test-Path -LiteralPath $InputFile -PathType Leaf)) {
    throw "Input JSON file not found: $InputFile"
}

$inputDocument = Get-Content -LiteralPath $InputFile -Raw | ConvertFrom-Json
$ranges = @(
    $inputDocument.addressPrefixes |
        Where-Object { $_ -is [string] } |
        Sort-Object -Unique
)
if ($ranges.Count -eq 0) {
    throw "Input JSON must contain a non-empty addressPrefixes array: $InputFile"
}
foreach ($range in $ranges) {
    if ($range -notmatch '^[^/]+/\d{1,3}$') {
        throw "Invalid CIDR-like IP prefix in input: $range"
    }
}

$policy = Get-AzFrontDoorWafPolicy -ResourceGroupName $ResourceGroup -Name $WafPolicyName
if ($null -eq $policy) {
    throw "Front Door WAF policy '$WafPolicyName' was not found in resource group '$ResourceGroup'."
}

$rules = @($policy.CustomRule | Where-Object { $null -ne $_ })
$ruleNamePattern = '^' + [regex]::Escape($RuleName) + '-\d+$'
$managedRules = @($rules | Where-Object {
    $_.Name -eq $RuleName -or $_.Name -match $ruleNamePattern
})
$ruleCount = [math]::Ceiling($ranges.Count / 500)
if ($RulePriority + $ruleCount - 1 -gt 1000) {
    throw "The $ruleCount generated rules exceed the available priority range starting at $RulePriority."
}

$priorityOwner = $rules | Where-Object {
    $_.Priority -ge $RulePriority -and
    $_.Priority -lt ($RulePriority + $ruleCount) -and
    $_.Name -ne $RuleName -and
    $_.Name -notmatch $ruleNamePattern
} | Select-Object -First 1
if ($null -ne $priorityOwner) {
    throw "Priority $($priorityOwner.Priority) is already used by custom rule '$($priorityOwner.Name)'."
}

$newRules = @(
    for ($offset = 0; $offset -lt $ranges.Count; $offset += 500) {
        $ruleNumber = [int]($offset / 500) + 1
        $matchValues = @($ranges | Select-Object -Skip $offset -First 500)
        $condition = New-AzFrontDoorWafMatchConditionObject `
            -MatchValue $matchValues `
            -MatchVariable 'RemoteAddr' `
            -OperatorProperty 'IPMatch'
        New-AzFrontDoorWafCustomRuleObject `
            -Name "$RuleName$ruleNumber" `
            -Priority ($RulePriority + $ruleNumber - 1) `
            -RuleType 'MatchRule' `
            -Action $RuleAction `
            -EnabledState 'Enabled' `
            -MatchCondition @($condition)
    }
)
$updatedRules = @($rules | Where-Object {
    $_.Name -ne $RuleName -and $_.Name -notmatch $ruleNamePattern
}) + $newRules

Write-Host "Set $ruleCount rules named '$RuleName' through '$RuleName$ruleCount' for $($ranges.Count) IP prefixes (maximum 500 per rule)."
if ($DryRun) {
    Write-Host 'Dry run: no Azure resources were modified.'
    return
}

Update-AzFrontDoorWafPolicy `
    -ResourceGroupName $ResourceGroup `
    -Name $WafPolicyName `
    -Customrule $updatedRules

Write-Host "Successfully updated Front Door WAF policy '$WafPolicyName'."