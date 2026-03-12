using 'main.bicep'

param location = 'australiaeast'
param resourcePrefix = 'sw'
param vmAdminUsername = 'azureuser'
param vmAdminPassword = 'ReplaceWithSecurePassword123!'
param deployerPublicIp = '167.220.242.221/32'
param githubToken = 'ghp_REPLACE_WITH_YOUR_GITHUB_PAT'
param githubOwner = 'anwather'
param githubRepo = 'win-investigator'
param foundryAgentId = 'TODO-AGENT-ID'
param enableEventGrid = false
