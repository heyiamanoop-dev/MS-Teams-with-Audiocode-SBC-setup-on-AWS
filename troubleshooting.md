# Troubleshooting Guide

## Common Errors and Fixes

---

### 1. AudioCodes Login Fails

**Symptom**: Invalid username/password on web UI

**Fix**: On AWS Marketplace AMIs, default password is the EC2 Instance ID
- Username: Admin
- Password: i-0xxxxxxxxxxxxxxxxx (your instance ID from AWS Console)

---

### 2. TLS Connectivity Inactive in Teams Admin Center

**Checklist**:
- [ ] Port 5061 TCP open in AWS Security Group (source 0.0.0.0/0)
- [ ] TLS certificate uploaded to AudioCodes TLS Contexts
- [ ] Certificate CN matches FQDN (mylab-sbc.ddns.net)
- [ ] SIP Interface Topology Location = Up
- [ ] IP Group #2 Teams Direct Routing Mode = Enable
- [ ] Proxy Set #2 Keep Alive = Using OPTIONS
- [ ] NAT Translation entry exists (eth0 → Elastic IP)
- [ ] All 3 Microsoft proxy FQDNs added to Proxy Set #2

**Test TLS**:
```cmd
openssl s_client -connect mylab-sbc.ddns.net:5061 -tls1_2
```
Should show CONNECTED and correct certificate.

---

### 3. SBC Watchdog Crashes

**Symptom in Message Log**:
```
SWWD: Block Task DSPD Ticks 5 (144ms)
SoftWatchdogThread() freezed for 2 ticks
```

**Cause**: t3.small has only 2GB RAM — insufficient for AudioCodes

**Fix**: Change instance type in AWS Console:
- Stop instance
- Actions → Instance settings → Change instance type
- Select m7i-flex.large (8GB) or c7i-flex.large
- Start instance

**Supported instance types for this AMI**:
- Versions < 7.20CO.258.034: r4, c4, t2 families
- Newer versions: m7i-flex.large, c7i-flex.large

---

### 4. License Error When Assigning Phone Numbers

**Error**:
```
User lacks appropriate licenses to assign a DirectRouting number
```

**Fix**: User needs Phone System license (MCOEV)
- Assign Microsoft 365 E5 license (includes Phone System)
- Wait 2-3 minutes after license assignment
- Verify: Get-CsOnlineUser | Select DisplayName, AssignedPlan

---

### 5. SBC Domain Not Accepted in Teams

**Error**:
```
Can not use the "domain" as it was not configured for this tenant
```

**Fix**:
1. Go to M365 Admin Center → Settings → Domains
2. Add mylab-sbc.ddns.net
3. Verify with TXT record in No-IP
4. Only TXT verification required — ignore MX/CNAME errors

---

### 6. win-acme DNS Challenge Fails

**Symptom**: Non-existent domain when verifying TXT record

**Fixes**:
- No-IP free doesn't support TXT records → upgrade to Enhanced DNS
- Wait 2-3 minutes after adding TXT record for propagation
- Verify: nslookup -type=TXT _acme-challenge.mylab-sbc.ddns.net 8.8.8.8

---

### 7. PowerShell Module Won't Load

**Error**:
```
The module could not be loaded
```

**Fix**:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
Import-Module MicrosoftTeams
Connect-MicrosoftTeams -UseDeviceAuthentication
```

---

### 8. Connect-MicrosoftTeams Browser Timeout

**Fix**: Use device authentication instead:
```powershell
Connect-MicrosoftTeams -UseDeviceAuthentication
```
Go to https://microsoft.com/devicelogin → enter the code shown

---

### 9. Proxy Sets Show 0 Success Count

**Cause**: Keep Alive disabled — SBC not sending OPTIONS to Microsoft

**Fix**:
1. Proxy Sets → #2 [ITSP] → Edit
2. Proxy Keep Alive → Using OPTIONS
3. Proxy Keep Alive Time → 60
4. Apply → Save to Flash
5. Wait 60 seconds → check Proxy Sets Status again

---

### 10. Duplicate SBC Entries in Teams Admin Center

**Fix**:
```powershell
Get-CsOnlinePSTNGateway | Format-List Fqdn, Identity
Remove-CsOnlineVoiceRoute -Identity "Route-Ext101"
Remove-CsOnlineVoiceRoute -Identity "Route-Ext102"
Remove-CsOnlinePSTNGateway -Identity "duplicate-entry-fqdn"
```

---

## Health Check Checklist

Run this PowerShell script for complete status:

```powershell
Write-Host "=== SBC ===" -ForegroundColor Green
Get-CsOnlinePSTNGateway | Format-List Fqdn, Enabled, SipSignalingPort

Write-Host "=== VOICE ROUTES ===" -ForegroundColor Green
Get-CsOnlineVoiceRoute | Format-Table Identity, NumberPattern, Priority

Write-Host "=== USERS ===" -ForegroundColor Green
Get-CsOnlineUser | Select DisplayName, LineUri, EnterpriseVoiceEnabled, VoiceRoutingPolicy | Format-Table
```

Expected healthy output:
- SBC: Enabled = True
- Voice Routes: 2 routes with correct patterns
- Users: LineUri = tel:+1555xxxx, EnterpriseVoiceEnabled = True, VoiceRoutingPolicy = LabVoicePolicy
