# Windows Server Diagnostic Skills

This directory contains PowerShell diagnostic skills for the SERVERWHISPERER Copilot CLI tool. Each skill is a comprehensive reference document that guides AI agents on how to investigate specific aspects of Windows Server systems.

## Available Skills

| Skill | Purpose | Key Metrics |
|-------|---------|-------------|
| **connectivity** | Test WinRM, establish PowerShell remoting, handle credentials | Ping, WinRM, CIM sessions |
| **server-overview** | Quick system snapshot | Hostname, OS version, uptime, domain membership, hardware |
| **processes** | Running process analysis | CPU usage, memory consumption, hung processes |
| **performance** | Real-time performance metrics | CPU %, memory %, disk I/O, counters |
| **disk-storage** | Disk space and health | Volume space, SMART data, disk health |
| **services** | Windows service status | Running/stopped services, crashes, dependencies |
| **installed-apps** | Software inventory | Installed applications, recent updates, hotfixes |
| **network** | Network configuration | IP config, DNS, ports, firewall rules |
| **roles-features** | Server roles and features | IIS, AD DS, installed Windows features |
| **event-logs** | System event analysis | Critical/error events, crashes, reboots |

## Usage Pattern

1. **Start with connectivity** - Establish connection to target server
2. **Run server-overview** - Get baseline understanding
3. **Choose specific diagnostics** based on the issue:
   - Performance problem → **performance**, **processes**
   - Disk space → **disk-storage**
   - Service failure → **services**, **event-logs**
   - Network issue → **network**, **connectivity**
   - Application problem → **installed-apps**, **processes**, **event-logs**

## Skill File Structure

Each `SKILL.md` contains:
- **Purpose** - What the skill investigates
- **PowerShell Code** - Complete code blocks ready to execute
- **Interpreting Results** - Tables and guidance on what findings mean
- **Common Issues** - Problems this skill can reveal
- **Error Handling** - Patterns for handling failures gracefully
- **Next Steps** - Which skills to run next based on findings

## Variables Convention

All code blocks use these standard variables:
- `$ServerName` - Target server hostname or IP (e.g., "SERVER01" or "192.168.1.10")
- `$Credential` - PSCredential object or `$null` for current user context

## Design Philosophy

1. **CIM over WMI** - Modern `Get-CimInstance` instead of deprecated `Get-WmiObject`
2. **Error Handling** - Every remote call wrapped in try/catch with `-ErrorAction Stop`
3. **Structured Data** - Return objects, not raw text
4. **Timeout Handling** - Include patterns for unresponsive servers
5. **Interpretation** - Not just data collection, but guidance on what it means

## For AI Agents

These skills are instruction/reference files, not executable PowerShell modules. The AI agent should:
1. Read the relevant SKILL.md file
2. Extract appropriate code blocks
3. Substitute actual values for `$ServerName` and `$Credential`
4. Execute the PowerShell remotely
5. Interpret results using the guidance in the skill file
6. Recommend next steps based on findings

## Contributing

When adding new skills:
- Follow the established structure
- Include comprehensive error handling
- Provide interpretation tables
- Document common issues revealed
- Link to related skills in "Next Steps"
