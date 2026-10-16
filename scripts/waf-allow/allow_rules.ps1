$updateScript = Join-Path $PSScriptRoot 'update-waf-ado-agent-ranges.ps1'


$devADO = @{
    ResourceGroup = 'rg-t1dv-gias'
    WafPolicyName = 'giast1dvwafpolicy'
    InputFile = (Join-Path $PSScriptRoot 'azure-devops-agent-ip-ranges.json')
    RuleName = 'AllowAzureDevOpsAgents'
    RulePriority = 100
    RuleAction = 'Allow'
}

$devGithub = @{
    ResourceGroup = 'rg-t1dv-gias'
    WafPolicyName = 'giast1dvwafpolicy'
    InputFile = (Join-Path $PSScriptRoot 'github-actions-agent-ip-ranges.json')
    RuleName = 'AllowGithubAgents'
    RulePriority = 101
    RuleAction = 'Allow'
}


$testADO = @{
    ResourceGroup = 'rg-t1dv-gias'
    WafPolicyName = 'giast1tewafpolicy'
    InputFile = (Join-Path $PSScriptRoot 'azure-devops-agent-ip-ranges.json')
    RuleName = 'AllowAzureDevOpsAgents'
    RulePriority = 100
    RuleAction = 'Allow'
}

$testGithub = @{
    ResourceGroup = 'rg-t1dv-gias'
    WafPolicyName = 'giast1tewafpolicy'
    InputFile = (Join-Path $PSScriptRoot 'github-actions-agent-ip-ranges.json')
    RuleName = 'AllowGithubAgents'
    RulePriority = 101
    RuleAction = 'Allow'
}


& $updateScript @devADO
& $updateScript @devGithub
& $updateScript @testADO
& $updateScript @testGithub