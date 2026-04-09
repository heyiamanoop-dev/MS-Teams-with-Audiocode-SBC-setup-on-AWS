# ============================================================
# Microsoft Teams Direct Routing - PowerShell Commands Reference
# Lab: MS Teams + AudioCodes Mediant SBC
# ============================================================

# ============================================================
# SECTION 1 — CONNECTION
# ============================================================

# Install Teams PowerShell Module
Install-Module -Name MicrosoftTeams -Force -AllowClobber

# Import module
Import-Module MicrosoftTeams

# Connect with browser auth
Connect-MicrosoftTeams

# Connect with device code auth (use when browser popup fails)
Connect-MicrosoftTeams -UseDeviceAuthentication

# Disconnect
Disconnect-MicrosoftTeams


# ============================================================
# SECTION 2 — SBC MANAGEMENT
# ============================================================

# Register new SBC
New-CsOnlinePSTNGateway `
  -Fqdn "mylab-sbc.ddns.net" `
  -SipSignalingPort 5061 `
  -ForwardCallHistory $true `
  -ForwardPai $true `
  -SendSipOptions $true `
  -MaxConcurrentSessions 10 `
  -Enabled $true `
  -MediaBypass $false

# View all registered SBCs
Get-CsOnlinePSTNGateway

# View SBC details
Get-CsOnlinePSTNGateway | Format-List Fqdn, Identity, Enabled, SipSignalingPort

# Enable SBC
Set-CsOnlinePSTNGateway -Identity "mylab-sbc.ddns.net" -Enabled $true

# Disable SBC (for maintenance or force reconnect)
Set-CsOnlinePSTNGateway -Identity "mylab-sbc.ddns.net" -Enabled $false

# Force SBC reconnect (disable then enable)
Set-CsOnlinePSTNGateway -Identity "mylab-sbc.ddns.net" -Enabled $false
Start-Sleep -Seconds 15
Set-CsOnlinePSTNGateway -Identity "mylab-sbc.ddns.net" -Enabled $true

# Remove SBC (must remove voice routes first)
Remove-CsOnlinePSTNGateway -Identity "mylab-sbc.ddns.net"


# ============================================================
# SECTION 3 — PSTN USAGE
# ============================================================

# View current PSTN usages
Get-CsOnlinePstnUsage

# Add new PSTN usage
Set-CsOnlinePstnUsage -Identity Global -Usage @{Add="LabUsage"}

# Remove PSTN usage
Set-CsOnlinePstnUsage -Identity Global -Usage @{Remove="LabUsage"}


# ============================================================
# SECTION 4 — VOICE ROUTES
# ============================================================

# Create voice route for extension 101
New-CsOnlineVoiceRoute `
  -Identity "Route-Ext101" `
  -NumberPattern "^\+15550101$" `
  -OnlinePstnGatewayList "mylab-sbc.ddns.net" `
  -Priority 1 `
  -OnlinePstnUsages "LabUsage"

# Create voice route for extension 102
New-CsOnlineVoiceRoute `
  -Identity "Route-Ext102" `
  -NumberPattern "^\+15550102$" `
  -OnlinePstnGatewayList "mylab-sbc.ddns.net" `
  -Priority 2 `
  -OnlinePstnUsages "LabUsage"

# Create catch-all voice route (all numbers via SBC)
New-CsOnlineVoiceRoute `
  -Identity "Route-All" `
  -NumberPattern ".*" `
  -OnlinePstnGatewayList "mylab-sbc.ddns.net" `
  -Priority 10 `
  -OnlinePstnUsages "LabUsage"

# View all voice routes
Get-CsOnlineVoiceRoute

# View specific voice route
Get-CsOnlineVoiceRoute -Identity "Route-Ext101"

# Remove voice route
Remove-CsOnlineVoiceRoute -Identity "Route-Ext101"
Remove-CsOnlineVoiceRoute -Identity "Route-Ext102"


# ============================================================
# SECTION 5 — VOICE ROUTING POLICY
# ============================================================

# Create voice routing policy
New-CsOnlineVoiceRoutingPolicy `
  -Identity "LabVoicePolicy" `
  -OnlinePstnUsages "LabUsage"

# View all voice routing policies
Get-CsOnlineVoiceRoutingPolicy

# Remove voice routing policy
Remove-CsOnlineVoiceRoutingPolicy -Identity "LabVoicePolicy"


# ============================================================
# SECTION 6 — USER MANAGEMENT
# ============================================================

# List all users
Get-CsOnlineUser | Select DisplayName, UserPrincipalName

# View user details
Get-CsOnlineUser -Identity "usera@yourtenantname.onmicrosoft.com" | `
  Select DisplayName, LineUri, EnterpriseVoiceEnabled, VoiceRoutingPolicy

# View user license details
Get-CsOnlineUser -Identity "usera@yourtenantname.onmicrosoft.com" | `
  Select -ExpandProperty AssignedPlan

# Assign phone number to user
Set-CsPhoneNumberAssignment `
  -Identity "usera@yourtenantname.onmicrosoft.com" `
  -PhoneNumber "+15550101" `
  -PhoneNumberType DirectRouting

# Assign voice routing policy to user
Grant-CsOnlineVoiceRoutingPolicy `
  -Identity "usera@yourtenantname.onmicrosoft.com" `
  -PolicyName "LabVoicePolicy"

# Remove phone number from user
Remove-CsPhoneNumberAssignment `
  -Identity "usera@yourtenantname.onmicrosoft.com" `
  -PhoneNumber "+15550101" `
  -PhoneNumberType DirectRouting

# Check if user has correct license (must show MCOEV)
Get-CsOnlineUser -Identity "usera@yourtenantname.onmicrosoft.com" | `
  Select -ExpandProperty AssignedPlan | Where-Object {$_.Capability -eq "MCOEV"}


# ============================================================
# SECTION 7 — DOMAIN CHECKS
# ============================================================

# View all SIP domains in tenant
Get-CsOnlineSipDomain

# View tenant information
Get-CsTenant


# ============================================================
# SECTION 8 — VERIFICATION CHECKS
# ============================================================

# Full verification - check all users at once
$users = @(
  "usera@yourtenantname.onmicrosoft.com",
  "userb@yourtenantname.onmicrosoft.com"
)

foreach ($user in $users) {
  Get-CsOnlineUser -Identity $user | `
    Select DisplayName, LineUri, EnterpriseVoiceEnabled, VoiceRoutingPolicy
}

# Check SBC status
Get-CsOnlinePSTNGateway | Select Fqdn, Enabled, SipSignalingPort

# Check voice routes
Get-CsOnlineVoiceRoute | Select Identity, NumberPattern, OnlinePstnGatewayList, Priority

# Full health check - run all at once
Write-Host "=== SBC STATUS ===" -ForegroundColor Cyan
Get-CsOnlinePSTNGateway | Format-List Fqdn, Enabled, SipSignalingPort

Write-Host "=== PSTN USAGES ===" -ForegroundColor Cyan
Get-CsOnlinePstnUsage

Write-Host "=== VOICE ROUTES ===" -ForegroundColor Cyan
Get-CsOnlineVoiceRoute | Format-Table Identity, NumberPattern, Priority

Write-Host "=== VOICE ROUTING POLICIES ===" -ForegroundColor Cyan
Get-CsOnlineVoiceRoutingPolicy | Format-Table Identity, OnlinePstnUsages

Write-Host "=== USERS ===" -ForegroundColor Cyan
Get-CsOnlineUser | Select DisplayName, LineUri, EnterpriseVoiceEnabled, VoiceRoutingPolicy | Format-Table


# ============================================================
# SECTION 9 — CLEANUP COMMANDS
# ============================================================

# Complete cleanup - removes everything in correct order
# Step 1: Remove phone number assignments
Remove-CsPhoneNumberAssignment `
  -Identity "usera@yourtenantname.onmicrosoft.com" `
  -PhoneNumber "+15550101" `
  -PhoneNumberType DirectRouting

Remove-CsPhoneNumberAssignment `
  -Identity "userb@yourtenantname.onmicrosoft.com" `
  -PhoneNumber "+15550102" `
  -PhoneNumberType DirectRouting

# Step 2: Remove voice routes
Remove-CsOnlineVoiceRoute -Identity "Route-Ext101"
Remove-CsOnlineVoiceRoute -Identity "Route-Ext102"

# Step 3: Remove SBC
Remove-CsOnlinePSTNGateway -Identity "mylab-sbc.ddns.net"

# Step 4: Remove PSTN usage
Set-CsOnlinePstnUsage -Identity Global -Usage @{Remove="LabUsage"}

# Step 5: Remove voice routing policy
Remove-CsOnlineVoiceRoutingPolicy -Identity "LabVoicePolicy"


# ============================================================
# SECTION 10 — TROUBLESHOOTING COMMANDS
# ============================================================

# Test TLS connectivity from Windows CMD (not PowerShell):
# openssl s_client -connect mylab-sbc.ddns.net:5061 -tls1_2

# Test DNS resolution from Windows CMD:
# nslookup mylab-sbc.ddns.net 8.8.8.8
# nslookup -type=TXT _acme-challenge.mylab-sbc.ddns.net 8.8.8.8

# Check if MCOEV (Phone System) license is assigned
Get-CsOnlineUser | Select DisplayName, @{
  Name="HasPhoneSystem";
  Expression={($_.AssignedPlan | Where-Object {$_.Capability -eq "MCOEV"}).Count -gt 0}
}

# Find users without voice routing policy assigned
Get-CsOnlineUser | Where-Object {$_.VoiceRoutingPolicy -eq $null} | `
  Select DisplayName, UserPrincipalName

# Find users without phone numbers
Get-CsOnlineUser | Where-Object {$_.LineUri -eq $null} | `
  Select DisplayName, UserPrincipalName

# Check EnterpriseVoice status for all users
Get-CsOnlineUser | Select DisplayName, EnterpriseVoiceEnabled | Format-Table
