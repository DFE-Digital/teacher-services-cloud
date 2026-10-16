# WAF Allow 

This folder contains various scripts and data files to help update custom WAF rules, it has been created as a one off to work with GIAS BAU based on this ticket: https://trello.com/c/UmVOMrH1/3030-gias-bau-dev-test-environments-traffic-limited-to-dfe-only but may be of use elsewhere and may need re-running.

This is not generally considered a practice, used for GIAS with the expectation it will be dropped when its migrated.

## Notes on IP addresses used
### Github
No region specific, simple to add but lots of them: https://docs.github.com/en/actions/reference/runners/github-hosted-runners#ip-addresses

### Azure DevOps
ADO is more ambiguous, the weekly IP range and tags document seems like the most accurate source but should be compared to actual usage.
    - This is used: https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops&tabs=windows-images%2Cyaml#networking
    - This is not used: https://learn.microsoft.com/en-gb/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops&tabs=IP-V4#inbound-connections