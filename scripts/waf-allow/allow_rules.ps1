$updateScript = Join-Path $PSScriptRoot 'update-waf-ado-agent-ranges.ps1'


$devADO = @{
    ResourceGroup = 'rg-t1dv-gias'
    WafPolicyName = 'giast1dvwafpolicy'
    InputFile = (Join-Path $PSScriptRoot 'azure-devops-agent-ip-ranges.json')
    RuleName = 'AllowAzureDevOpsAgents261118'
    RulePriority = 120
    RuleAction = 'Allow'
}

$devGithub = @{
    ResourceGroup = 'rg-t1dv-gias'
    WafPolicyName = 'giast1dvwafpolicy'
    InputFile = (Join-Path $PSScriptRoot 'github-actions-agent-ip-ranges.json')
    RuleName = 'AllowGithubAgents261118'
    RulePriority = 125
    RuleAction = 'Allow'
}


$testADO = @{
    ResourceGroup = 'rg-t1dv-gias'
    WafPolicyName = 'giast1tewafpolicy'
    InputFile = (Join-Path $PSScriptRoot 'azure-devops-agent-ip-ranges.json')
    RuleName = 'AllowAzureDevOpsAgents261118'
    RulePriority = 120
    RuleAction = 'Allow'
}

$testGithub = @{
    ResourceGroup = 'rg-t1dv-gias'
    WafPolicyName = 'giast1tewafpolicy'
    InputFile = (Join-Path $PSScriptRoot 'github-actions-agent-ip-ranges.json')
    RuleName = 'AllowGithubAgents261118'
    RulePriority = 125
    RuleAction = 'Allow'
}


#& $updateScript @devADO
& $updateScript @devGithub
& $updateScript @testADO
& $updateScript @testGithub