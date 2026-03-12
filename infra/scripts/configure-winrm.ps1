[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host 'Configuring WinRM over HTTPS...'

$existingCert = Get-ChildItem -Path Cert:\LocalMachine\My |
    Where-Object { $_.Subject -eq "CN=$env:COMPUTERNAME" } |
    Sort-Object NotAfter -Descending |
    Select-Object -First 1

if (-not $existingCert) {
    $existingCert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My
}

winrm quickconfig -quiet

$hasHttpsListener = winrm enumerate winrm/config/Listener | Select-String -Pattern 'Transport = HTTPS'
if (-not $hasHttpsListener) {
    winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$env:COMPUTERNAME`"; CertificateThumbprint=`"$($existingCert.Thumbprint)`"}"
}

winrm set winrm/config/service/auth '@{Basic="true";CredSSP="true"}'
winrm set winrm/config/client/auth '@{CredSSP="true"}'

if (-not (Get-NetFirewallRule -DisplayName 'WinRM HTTPS' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName 'WinRM HTTPS' -Name 'WinRM-HTTPS-5986' -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow | Out-Null
}

Set-Service -Name WinRM -StartupType Automatic
Restart-Service -Name WinRM

Write-Host 'WinRM HTTPS configuration complete.'
