---
name: azure-connectivity
description: "Connect to Azure VMs via PowerShell remoting over public IP (HTTPS/5986)"
---

# Azure VM Connectivity — PowerShell Remoting over Public IP

## Purpose

Establish PowerShell remoting sessions to Azure VMs accessed via public IP address or `*.cloudapp.azure.com` hostname. This skill covers Azure-specific concerns: NSG rules, WinRM HTTPS listener setup on the VM, and alternative access methods.

> **Connection pattern:** All connections (Azure and non-Azure) use HTTPS on port 5986 with `-SkipCACheck` and `-SkipCNCheck`. See the **connectivity** skill for the universal connection pattern.

---

## Prerequisites for Azure VM Remoting

### On the Azure VM (target)

1. **WinRM HTTPS listener configured** (port 5986)
2. **Windows Firewall** allows inbound TCP 5986
3. **SSL certificate** bound to WinRM (self-signed or CA-issued)

### In Azure Portal / NSG

1. **NSG inbound rule** allowing TCP 5986 from your client IP
2. Any Azure Firewall or third-party NVA must also permit the traffic

### On the Client Machine (your workstation)

1. **Explicit credentials ready** — Kerberos does not work over public IP. User must save credentials 
   to an encrypted file BEFORE using SERVERWHISPERER:
   ```powershell
   New-Item -ItemType Directory -Path "$HOME\.serverwhisperer" -Force
   Get-Credential | Export-Clixml -Path "$HOME\.serverwhisperer\credentials.xml"
   ```
2. No TrustedHosts modification needed — `-SkipCACheck` and `-SkipCNCheck` handle certificate validation

⚠️ **SECURITY: NEVER ask users to type Azure VM passwords in the chat.** The user creates an encrypted 
credential file outside of Copilot CLI using Export-Clixml (DPAPI encryption).

---

## Step 1: Verify NSG Rules (Azure Side)

NSG rules must allow inbound traffic on port 5986. Check via Azure CLI or the portal.

```powershell
# Azure CLI — check NSG rules for the VM's NIC
# (Run this where Az CLI is installed)
az network nsg rule list `
    --resource-group "YOUR_RG" `
    --nsg-name "YOUR_NSG_NAME" `
    --query "[?destinationPortRange=='5986' || destinationPortRange=='*'].{Name:name, Access:access, Direction:direction, Priority:priority, Source:sourceAddressPrefix}" `
    --output table
```

**What to look for:**
- An `Allow` rule for destination port `5986`, direction `Inbound`
- Source should be your client IP or a known range (avoid `*` in production)
- No higher-priority `Deny` rule blocking the same port

**Portal path:** Azure Portal → VM → Networking → Inbound port rules → Verify port 5986 is listed as Allow.

> ⚠️ If no rule exists, the connection will silently timeout. NSG denies are the #1 cause of "cannot connect to Azure VM" issues.

---

## Step 2: WinRM HTTPS Setup on the Azure VM

If the Azure VM doesn't already have a WinRM HTTPS listener, configure it. This requires console access (Azure Serial Console, Run Command, or RDP).

```powershell
# Run ON the Azure VM (via RDP, Serial Console, or Run Command)

# Create a self-signed certificate
$cert = New-SelfSignedCertificate `
    -DnsName $env:COMPUTERNAME `
    -CertStoreLocation Cert:\LocalMachine\My `
    -NotAfter (Get-Date).AddYears(3)

# Create WinRM HTTPS listener
winrm create winrm/config/Listener?Address=*+Transport=HTTPS `
    "@{Hostname=`"$env:COMPUTERNAME`"; CertificateThumbprint=`"$($cert.Thumbprint)`"}"

# Open firewall for HTTPS WinRM
New-NetFirewallRule -DisplayName "WinRM HTTPS" `
    -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow

# Verify listener is active
winrm enumerate winrm/config/Listener
```

**Via Azure Run Command (no RDP needed):**
```powershell
az vm run-command invoke `
    --resource-group "YOUR_RG" `
    --name "YOUR_VM_NAME" `
    --command-id RunPowerShellScript `
    --scripts "winrm enumerate winrm/config/Listener"
```

---

## Step 3: Test HTTPS Connectivity

Before establishing a full session, verify the HTTPS port is reachable.

```powershell
$ServerName = "20.100.50.25"  # Azure VM public IP
$Port = 5986

# Test TCP connectivity to port 5986
$tcpTest = Test-NetConnection -ComputerName $ServerName -Port $Port -WarningAction SilentlyContinue
if ($tcpTest.TcpTestSucceeded) {
    Write-Host "✓ TCP port $Port is reachable on $ServerName" -ForegroundColor Green
} else {
    Write-Warning "✗ TCP port $Port is NOT reachable on $ServerName"
    Write-Host "  → Check Azure NSG rules allow inbound TCP $Port" -ForegroundColor Yellow
    Write-Host "  → Check Windows Firewall on the VM allows TCP $Port" -ForegroundColor Yellow
    Write-Host "  → Check the VM is running and WinRM HTTPS listener is active" -ForegroundColor Yellow
    return
}

# Test WinRM over HTTPS
try {
    Test-WSMan -ComputerName $ServerName -UseSSL -ErrorAction Stop
    Write-Host "✓ WinRM HTTPS is responding on $ServerName" -ForegroundColor Green
} catch {
    Write-Warning "✗ WinRM HTTPS test failed: $($_.Exception.Message)"
    Write-Host "  → Verify WinRM HTTPS listener is configured on the VM" -ForegroundColor Yellow
}
```

---

## Step 4: Establish PSSession over HTTPS

```powershell
$ServerName = "20.100.50.25"  # Azure VM public IP or hostname

# Load saved credentials (Azure VMs ALWAYS require explicit credentials)
$credPath = Join-Path $HOME ".serverwhisperer" "credentials.xml"
if (-not (Test-Path $credPath)) {
    Write-Host "⚠️ No saved credentials found. Azure VMs require explicit credentials." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To save credentials, run:" -ForegroundColor Cyan
    Write-Host '  New-Item -ItemType Directory -Path "$HOME\.serverwhisperer" -Force' -ForegroundColor White
    Write-Host '  Get-Credential | Export-Clixml -Path "$HOME\.serverwhisperer\credentials.xml"' -ForegroundColor White
    Write-Host ""
    Write-Host "Username formats for Azure VMs:" -ForegroundColor Gray
    Write-Host "  • Local account: .\AdminUser  or  VMName\AdminUser" -ForegroundColor Gray
    Write-Host "  • Azure AD account: user@domain.com" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Then ask me again and I'll connect." -ForegroundColor Cyan
    return
}

$credential = Import-Clixml -Path $credPath
$SessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck

try {
    $session = New-PSSession `
        -ComputerName $ServerName `
        -Credential $credential `
        -UseSSL `
        -Port 5986 `
        -SessionOption $SessionOption `
        -ErrorAction Stop

    Write-Host "✓ PSSession established to $ServerName over HTTPS" -ForegroundColor Green

    # Verify the session works
    $info = Invoke-Command -Session $session -ScriptBlock {
        [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            UserContext  = "$env:USERDOMAIN\$env:USERNAME"
            PSVersion    = $PSVersionTable.PSVersion.ToString()
            OS           = (Get-CimInstance Win32_OperatingSystem).Caption
            Timestamp    = Get-Date -Format 'o'
        }
    }

    Write-Host "  Computer: $($info.ComputerName)" -ForegroundColor Gray
    Write-Host "  User: $($info.UserContext)" -ForegroundColor Gray
    Write-Host "  OS: $($info.OS)" -ForegroundColor Gray

} catch {
    Write-Warning "✗ PSSession failed: $($_.Exception.Message)"

    if ($_.Exception.Message -match "Access is denied") {
        Write-Host "  → Verify saved credentials are correct" -ForegroundColor Yellow
        Write-Host "  → Username format: VM_NAME\AdminUser or user@domain.com" -ForegroundColor Yellow
        Write-Host "  → Re-create credential file if needed" -ForegroundColor Yellow
    } elseif ($_.Exception.Message -match "cannot connect") {
        Write-Host "  → Check NSG, firewall, and WinRM HTTPS listener" -ForegroundColor Yellow
    } elseif ($_.Exception.Message -match "certificate") {
        Write-Host "  → Certificate issue — ensure -SkipCACheck and -SkipCNCheck are set" -ForegroundColor Yellow
    }
} finally {
    # Clean up when done (uncomment when finished with diagnostics)
    # if ($session) { Remove-PSSession -Session $session }
}
```

---

## Step 5: Create CIM Session over HTTPS

CIM sessions are used by many diagnostic skills (`Get-CimInstance`).

```powershell
$ServerName = "20.100.50.25"

# Open secure credential dialog
$Credential = Get-Credential -Message "Enter credentials for Azure VM at $ServerName"

try {
    $CimOption = New-CimSessionOption -UseSsl -SkipCACheck -SkipCNCheck
    $cimSession = New-CimSession `
        -ComputerName $ServerName `
        -Credential $Credential `
        -SessionOption $CimOption `
        -Port 5986 `
        -ErrorAction Stop

    Write-Host "✓ CIM session established to $ServerName over HTTPS" -ForegroundColor Green

    # Test with a quick query
    $os = Get-CimInstance -CimSession $cimSession -ClassName Win32_OperatingSystem
    Write-Host "  OS: $($os.Caption)" -ForegroundColor Gray
    Write-Host "  Last Boot: $($os.LastBootUpTime)" -ForegroundColor Gray

} catch {
    Write-Warning "✗ CIM session failed: $($_.Exception.Message)"
    Write-Host "  → Ensure WinRM HTTPS listener is configured on port 5986" -ForegroundColor Yellow
    Write-Host "  → Verify NSG allows TCP 5986 from your IP" -ForegroundColor Yellow
    Write-Host "  → Verify credentials in Get-Credential dialog were correct" -ForegroundColor Yellow
} finally {
    # Clean up when done
    # if ($cimSession) { Remove-CimSession -CimSession $cimSession }
}
```

---

## Common Azure VM Remoting Errors

| Error Message | Likely Cause | Resolution |
|---|---|---|
| Connection timed out / no response | NSG blocking port 5986 | Add NSG inbound rule for TCP 5986 |
| "The server certificate on the destination computer has errors" | Self-signed cert | Handled by `-SkipCACheck -SkipCNCheck` in session options |
| "Access is denied" | Wrong credentials or username format | Verify credentials entered in Get-Credential dialog; use `VM_NAME\AdminUser` or `user@domain.com` |
| "WinRM cannot complete the operation" | WinRM HTTPS listener not configured | Configure listener on the VM (Step 2) |
| "The connection to the specified remote host was refused" | WinRM service stopped or wrong port | Verify WinRM service is running, listener on 5986 |
| "Cannot find the computer" | DNS resolution failure | Verify IP address, try direct IP instead of hostname |
| "Negotiate authentication error" | Kerberos attempted over public IP | Ensure explicit credentials via Get-Credential |

---

## Alternative Approaches

If WinRM HTTPS is not feasible, consider these Azure-native alternatives:

### Azure Bastion
- Provides secure RDP/SSH without exposing public IPs
- No WinRM or NSG configuration needed for management access
- Portal: VM → Connect → Bastion

### Azure Serial Console
- Direct console access for emergency recovery
- Works even when networking/RDP is broken
- Portal: VM → Help → Serial Console

### Azure Run Command
- Execute PowerShell scripts on the VM without WinRM
- Good for one-off diagnostics or setting up WinRM
- Portal: VM → Run Command → RunPowerShellScript
```powershell
# Via Azure CLI
az vm run-command invoke `
    --resource-group "YOUR_RG" `
    --name "YOUR_VM_NAME" `
    --command-id RunPowerShellScript `
    --scripts "Get-Service WinRM; Get-Process | Sort-Object CPU -Descending | Select-Object -First 10"
```

### Azure VPN / ExpressRoute
- Connect your network to Azure via VPN gateway
- Once connected, VMs appear on your network (use standard connectivity skill)
- Best for ongoing management of many Azure VMs

---

## Security Considerations

1. **Always use HTTPS** (port 5986) for Azure VMs over public IP — HTTP sends credentials in clear text
2. **Use Get-Credential for passwords** — Never type passwords in the chat; always use the secure Windows login dialog
3. **Explicit credentials required** — Kerberos does not work over public IP without domain trust
4. **Restrict NSG source IP** — Never allow `*` (any) as source for port 5986
5. **Self-signed certs are acceptable** for known VMs you control, but CA-issued certs are preferred for production
6. **Remove NSG rules** when remoting is no longer needed — minimize attack surface
7. **Consider Azure Bastion** as a more secure alternative for ongoing management

---

## Next Steps

Once connected:
1. Run **server-overview** skill for baseline system information
2. Run specific diagnostic skills based on the investigation
3. Reuse the `$session` or `$cimSession` for all subsequent commands to avoid re-authentication
4. Clean up sessions when done: `Remove-PSSession` / `Remove-CimSession`
