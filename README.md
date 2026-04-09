# Microsoft Teams Direct Routing Lab with AudioCodes Mediant SBC

A complete step-by-step lab guide for migrating company extensions to Microsoft Teams using AudioCodes Mediant VE SBC hosted on AWS.

---

## Architecture

```
┌─────────────────────────────────┐         ┌─────────────────────────────────┐
│         AWS Cloud (EC2)         │         │    Microsoft 365 (Free Trial)   │
│                                 │         │                                 │
│  ┌───────────────────────────┐  │         │  ┌───────────────────────────┐  │
│  │  AudioCodes Mediant VE    │  │◄───────►│  │     Microsoft Teams       │  │
│  │  SBC (m7i-flex.large)     │  │SIP TLS  │  │   Direct Routing (E5)    │  │
│  │  mylab-sbc.ddns.net       │  │Port 5061│  │                           │  │
│  └───────────────────────────┘  │         │  └───────────────────────────┘  │
│         Elastic IP              │         │                                 │
│         + TLS Certificate       │         │  User A: +15550101              │
│                                 │         │  User B: +15550102              │
│  ┌───────────────────────────┐  │         └─────────────────────────────────┘
│  │      FreePBX (Optional)   │  │
│  │      Internal Extensions  │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
              │
              ▼
    PSTN / SIP Trunk (Optional)
```

---

## Prerequisites

### Accounts Required
| Service | Type | Cost |
|---|---|---|
| AWS Account | Free tier + payment method for EC2 | ~$0.05-0.07/hr when running |
| Microsoft 365 | E5 Trial (30 days free) | Free |
| No-IP Enhanced | Dynamic DNS with TXT record support | $2.39/month |
| AudioCodes Mediant VE | AWS Marketplace AMI (BYOL trial) | Free trial |

### Software Required (Windows PC)
- **win-acme** v2.2.9+ — Let's Encrypt client for Windows
- **OpenSSL for Windows** — Certificate management
- **Microsoft Teams PowerShell Module** — Direct Routing configuration
- **Microsoft Teams App** — For testing calls

### Network Requirements
| Port | Protocol | Direction | Purpose |
|---|---|---|---|
| 5061 | TCP | Inbound/Outbound | SIP TLS (Teams Direct Routing) |
| 5060 | TCP/UDP | Inbound/Outbound | SIP (Internal/FreePBX) |
| 7000-7999 | UDP | Inbound/Outbound | RTP Media |
| 443 | TCP | Inbound | HTTPS Management |
| 22 | TCP | Inbound | SSH Management |
| 80 | TCP | Inbound | HTTP (temporary for cert validation only) |

---

## Phase 1 — AWS Infrastructure Setup

### 1.1 Launch AudioCodes Mediant VE SBC on EC2

1. Login to **AWS Console → EC2 → Launch Instance**
2. Click **Browse more AMIs → AWS Marketplace AMIs**
3. Search **"AudioCodes Mediant"**
4. Select **Mediant VE Session Border Controller (SBC)**
5. Select instance type:
   > ⚠️ **IMPORTANT**: This AMI supports specific instance types only.
   > Versions prior to 7.20CO.258.034 support **r4 / c4 / t2** instance types.
   > For newer versions use **m7i-flex.large** (8GB RAM) or **c7i-flex.large**.
   > **DO NOT use t3.small** — it has only 2GB RAM and causes watchdog crashes.

   **Recommended**: `m7i-flex.large` (2 vCPU, 8GB RAM, ~$0.06/hr)

6. Configure Security Group — add these inbound rules:

| Type | Port | Protocol | Source |
|---|---|---|---|
| Custom TCP | 5061 | TCP | 0.0.0.0/0 |
| Custom TCP | 5060 | TCP | 0.0.0.0/0 |
| Custom UDP | 5060 | UDP | 0.0.0.0/0 |
| Custom UDP | 7000-7999 | UDP | 0.0.0.0/0 |
| HTTPS | 443 | TCP | 0.0.0.0/0 |
| SSH | 22 | TCP | Your IP |
| HTTP | 80 | TCP | 0.0.0.0/0 |

7. **Assign Elastic IP**:
   - Go to **EC2 → Elastic IPs → Allocate Elastic IP**
   - Click **Associate** → select your SBC instance
   - Note the Elastic IP (e.g. `16.16.71.168`) — used throughout

### 1.2 Login to AudioCodes Web UI

1. Open browser → `https://<ElasticIP>`
2. Accept the certificate warning
3. **Default credentials on AWS**:
   - Username: `Admin`
   - Password: **your EC2 Instance ID** (e.g. `i-0cb0d7162775b1111`)
4. Change password immediately after login

---

## Phase 2 — FQDN Setup with No-IP

### 2.1 Create No-IP Account and Hostname

1. Go to **https://noip.com** → Sign up
2. Navigate to **DDNS & Remote Access → DNS Records**
3. Click **Create Hostname**
4. Enter hostname: `mylab-sbc` → domain: `.ddns.net`
5. Set IP to your **Elastic IP**
6. Your FQDN: `mylab-sbc.ddns.net`

> ⚠️ Free No-IP accounts do NOT support TXT records.
> You need **Enhanced Dynamic DNS** ($2.39/month) for TXT record support
> which is required for Let's Encrypt DNS validation.

### 2.2 Verify DNS Resolution

```cmd
nslookup mylab-sbc.ddns.net 8.8.8.8
```

Expected output:
```
Name: mylab-sbc.ddns.net
Address: 16.16.71.168
```

---

## Phase 3 — TLS Certificate with Let's Encrypt (win-acme)

### 3.1 Install win-acme

1. Go to **https://github.com/win-acme/win-acme/releases**
2. Download `win-acme.v2.x.x.x.x64.pluggable.zip`
3. Extract to `C:\win-acme\`

### 3.2 Get Certificate

Open Command Prompt as Administrator:

```cmd
cd C:\win-acme
wacs.exe
```

Follow the menu selections:
```
Please choose from the menu: M          (Full options)
How shall we determine the domain(s): 2  (Manual input)
Host: mylab-sbc.ddns.net
Split certificates: 4                   (Single certificate)
How would you like prove ownership: 6   (DNS manual)
What kind of private key: 2             (RSA)
How would you like to store: 2          (PEM encoded files)
File path: C:\Users\<username>\Desktop
Password for private key: 1             (None - IMPORTANT for AudioCodes!)
Additional store steps: 5               (No)
Installation steps: 1                   (None)
```

### 3.3 Add DNS TXT Record in No-IP

When win-acme pauses and shows:
```
Please create a TXT record:
Name:  _acme-challenge.mylab-sbc.ddns.net
Value: <randomstring>
```

1. Go to **No-IP → DNS Records → Manage DNS Records**
2. Select the **second radio button** (subdomain entry)
3. Type `_acme-challenge` in the text box
4. Paste the random value in **Data** field
5. Click **Save**

Verify in new Command Prompt window:
```cmd
nslookup -type=TXT _acme-challenge.mylab-sbc.ddns.net 8.8.8.8
```

When the TXT value appears → go back to win-acme → press **Enter**

### 3.4 Remove Password from Private Key

```cmd
cd C:\Users\<username>\Desktop
openssl rsa -in "mylab-sbc.ddns.net-key.pem" -out "mylab-sbc.ddns.net-key-nopass.pem"
```

> ⚠️ AudioCodes cannot use password-protected private keys.
> Always use the `-nopass` version when uploading.

### 3.5 Certificate Files

After successful generation, you will have:

| File | Purpose |
|---|---|
| `mylab-sbc.ddns.net-chain.pem` | Full certificate chain → upload to AudioCodes |
| `mylab-sbc.ddns.net-key-nopass.pem` | Private key (no password) → upload to AudioCodes |

---

## Phase 4 — AudioCodes SBC Configuration

### 4.1 Initial Setup Wizard

After first login, complete the Setup Wizard:

| Setting | Value |
|---|---|
| Hostname | `lab-sbc-01` |
| Time Zone | Your local timezone |
| NTP Server 1 | `pool.ntp.org` |
| NTP Server 2 | `time.google.com` |
| Web Interface | HTTPS |
| CLI Interface | SSH |

### 4.2 IP Network Interface

Navigate to **IP Network → IP Interfaces**:

| Field | Value |
|---|---|
| IP Address | EC2 Private IP (e.g. `172.31.9.171`) |
| Subnet Mask | `255.255.240.0` |
| Default Gateway | VPC Gateway (e.g. `172.31.0.1`) |
| Primary DNS | `8.8.8.8` |
| Application Type | `OAMP + Media + Control` |

### 4.3 NAT Translation

Navigate to **IP Network → NAT Translation → Add**:

| Entry | Source Interface | Target IP | Source Ports |
|---|---|---|---|
| 1 | eth0 | `<ElasticIP>` | 7000-7999 (RTP) |
| 2 | eth0 | `<ElasticIP>` | 5061-5061 (SIP) |

### 4.4 Upload TLS Certificate

1. Go to **IP Network → Security → TLS Contexts → #0 [default]**
2. Click **"Change Certificate >>"**
3. Upload `mylab-sbc.ddns.net-key-nopass.pem` as **Private Key**
4. Upload `mylab-sbc.ddns.net-chain.pem` as **Certificate**
5. Click **Apply**
6. Click **"Certificate Information >>"** to verify:
   - CN = `mylab-sbc.ddns.net`
   - Issuer = `Let's Encrypt`

### 4.5 Transport Settings

Navigate to **Signaling & Media → SIP Definitions → Transport Settings**:

| Field | Value |
|---|---|
| SIP Transport Type | `TLS` |
| SIPS | `Enable` |
| SIP Destination Port | `5061` |
| SIP NAT Detection | `Enable` |

### 4.6 SIP Interface

Navigate to **Signaling & Media → SIP Definitions → SIP Interfaces**:

| Field | Value |
|---|---|
| Network Interface | `eth0` |
| Application Type | `SBC` |
| UDP Port | `5060` |
| TCP Port | `5060` |
| TLS Port | `5061` |
| TLS Context Name | `default` |
| Topology Location | `Up` |

### 4.7 Proxy Sets

Navigate to **Signaling & Media → SBC → Proxy Sets**:

**Proxy Set #1 — IP-PBX (FreePBX/Internal)**:

| Field | Value |
|---|---|
| Name | `IP-PBX` |
| SBC IPv4 SIP Interface | `sipInterface1` |
| Proxy Address | FreePBX private IP:5060 |
| Transport Type | `UDP` |
| Keep Alive | `Disable` |

**Proxy Set #2 — ITSP (Microsoft Teams)**:

| Field | Value |
|---|---|
| Name | `ITSP` |
| SBC IPv4 SIP Interface | `sipInterface1` |
| Proxy Keep Alive | `Using OPTIONS` |
| Proxy Keep Alive Time | `60` |
| Redundancy Mode | `Homing` |
| Proxy Hot Swap | `Enable` |

Proxy Addresses for ITSP:
| Address | Port | Transport |
|---|---|---|
| `sip.pstnhub.microsoft.com` | `5061` | `TLS` |
| `sip2.pstnhub.microsoft.com` | `5061` | `TLS` |
| `sip3.pstnhub.microsoft.com` | `5061` | `TLS` |

### 4.8 IP Groups

Navigate to **Signaling & Media → SBC → IP Groups**:

**IP Group #1 — IP-PBX**:

| Field | Value |
|---|---|
| Name | `IP-PBX` |
| Type | `Server` |
| Proxy Set | `IP-PBX` |
| Media Realm | `IP-PBX` |
| Teams Direct Routing Mode | `Disable` |

**IP Group #2 — ITSP (Teams)**:

| Field | Value |
|---|---|
| Name | `ITSP` |
| Type | `Server` |
| Proxy Set | `ITSP` |
| SIP Group Name | `mylab-sbc.ddns.net` |
| Teams Direct Routing Mode | **`Enable`** ← Critical! |
| Teams Local Media Optimization | `None` |
| Media Bypass | `Disable` |

### 4.9 IP-to-IP Routing

Navigate to **Signaling & Media → SBC → Routing → IP-to-IP Routing**:

| Index | Name | Source IP Group | Destination IP Group |
|---|---|---|---|
| 10 | `IP-PBX → ITSP` | `IP-PBX` | `ITSP` |
| 20 | `ITSP → IP-PBX` | `ITSP` | `IP-PBX` |

### 4.10 Media Security

Navigate to **Signaling & Media → Media → Media Security**:

| Field | Value |
|---|---|
| Media Security | `Enable` |
| Media Security Behavior | `Mandatory` |

### 4.11 Save Configuration

> ⚠️ AudioCodes does NOT auto-save. Always click **Save** (top right) after changes.
> The Save button turns orange when there are unsaved changes.

---

## Phase 5 — Microsoft 365 Setup

### 5.1 Get Microsoft 365 E5 Trial

1. Go to **https://admin.microsoft.com → Billing → Purchase services**
2. Search **"Microsoft 365 E5"**
3. Click **"Start free trial"** (30 days, 25 licenses)
4. Confirm trial activation

> ⚠️ **Do NOT use M365 Business Standard** — it does not include Phone System (MCOEV).
> E5 includes Phone System built-in. No separate Teams Phone license needed.

### 5.2 Create Test Users

1. Go to **Admin Center → Users → Active Users → Add a user**
2. Create two users:
   - `usera@yourtenantname.onmicrosoft.com`
   - `userb@yourtenantname.onmicrosoft.com`

### 5.3 Assign E5 License to Users

1. Go to **Users → Active Users → click user**
2. Click **Licenses and apps** tab
3. Check **Microsoft 365 E5**
4. Click **Save changes**
5. Repeat for second user

### 5.4 Add Domain to M365

1. Go to **Settings → Domains → Add Domain**
2. Enter `mylab-sbc.ddns.net`
3. Choose **TXT verification**
4. Add the TXT record in No-IP (same process as Let's Encrypt)
5. Click **Verify**

> ⚠️ You only need the TXT record verified. MX and CNAME errors for
> Exchange/autodiscover can be ignored — they are email-related only.

---

## Phase 6 — Teams Direct Routing via PowerShell

### 6.1 Install and Connect

```powershell
# Install Teams module
Install-Module -Name MicrosoftTeams -Force -AllowClobber

# Import module
Import-Module MicrosoftTeams

# Connect (use device auth if browser popup fails)
Connect-MicrosoftTeams -UseDeviceAuthentication
```

### 6.2 Register SBC

```powershell
New-CsOnlinePSTNGateway `
  -Fqdn "mylab-sbc.ddns.net" `
  -SipSignalingPort 5061 `
  -ForwardCallHistory $true `
  -ForwardPai $true `
  -SendSipOptions $true `
  -MaxConcurrentSessions 10 `
  -Enabled $true `
  -MediaBypass $false
```

### 6.3 Create PSTN Usage

```powershell
Set-CsOnlinePstnUsage -Identity Global -Usage @{Add="LabUsage"}
```

### 6.4 Create Voice Routes

```powershell
# Route for extension 101
New-CsOnlineVoiceRoute `
  -Identity "Route-Ext101" `
  -NumberPattern "^\+15550101$" `
  -OnlinePstnGatewayList "mylab-sbc.ddns.net" `
  -Priority 1 `
  -OnlinePstnUsages "LabUsage"

# Route for extension 102
New-CsOnlineVoiceRoute `
  -Identity "Route-Ext102" `
  -NumberPattern "^\+15550102$" `
  -OnlinePstnGatewayList "mylab-sbc.ddns.net" `
  -Priority 2 `
  -OnlinePstnUsages "LabUsage"
```

### 6.5 Create Voice Routing Policy

```powershell
New-CsOnlineVoiceRoutingPolicy `
  -Identity "LabVoicePolicy" `
  -OnlinePstnUsages "LabUsage"
```

### 6.6 Assign Numbers to Users

```powershell
# User A
Set-CsPhoneNumberAssignment `
  -Identity "usera@yourtenantname.onmicrosoft.com" `
  -PhoneNumber "+15550101" `
  -PhoneNumberType DirectRouting

Grant-CsOnlineVoiceRoutingPolicy `
  -Identity "usera@yourtenantname.onmicrosoft.com" `
  -PolicyName "LabVoicePolicy"

# User B
Set-CsPhoneNumberAssignment `
  -Identity "userb@yourtenantname.onmicrosoft.com" `
  -PhoneNumber "+15550102" `
  -PhoneNumberType DirectRouting

Grant-CsOnlineVoiceRoutingPolicy `
  -Identity "userb@yourtenantname.onmicrosoft.com" `
  -PolicyName "LabVoicePolicy"
```

---

## Phase 7 — Verification and Testing

### 7.1 Verify SBC Connectivity

Check Teams Admin Center:
1. Go to **https://admin.teams.microsoft.com**
2. Navigate to **Voice → Direct Routing**
3. Verify SBC shows:
   - TLS Connectivity: **Active**
   - SIP Options: **Active**

Check AudioCodes:
1. Go to **Monitor → VoIP Status → Proxy Sets Status**
2. Verify ITSP proxy shows:
   - Status: **ONLINE**
   - Success Count: **increasing**
   - Failure Count: **0**

### 7.2 Test Call

1. Open Teams as User A
2. Go to **Calls → Dial Pad**
3. Dial `+15550102`
4. User B should receive the incoming call

---

## Troubleshooting

### TLS Connectivity Inactive

| Check | Action |
|---|---|
| Port 5061 open in AWS Security Group | Add inbound TCP 5061 rule |
| TLS certificate uploaded correctly | Check Certificate Information in TLS Contexts |
| Topology Location = Up | Edit SIP Interface → set Topology Location to Up |
| Teams Direct Routing Mode enabled | Edit IP Group #2 → set Teams Direct Routing Mode to Enable |
| Keep Alive enabled on Proxy Set | Edit Proxy Set #2 → set Keep Alive to Using OPTIONS |
| NAT Translation configured | Add eth0 → Elastic IP mapping |

### SBC Watchdog Crashes

Symptom: `SWWD: Block Task` or `SoftWatchdogThread() freezed` in message log

Cause: Insufficient RAM (t3.small has only 2GB)

Fix: Use supported instance type with minimum 4GB RAM:
- `m7i-flex.large` (8GB) — recommended
- `c7i-flex.large` (4GB)
- `t2.medium` (4GB) if available in your region

### License Error When Assigning Numbers

Error: `User lacks appropriate licenses to assign a DirectRouting number`

Fix: Assign Microsoft 365 E5 license to the user (not Business Standard)

### Domain Verification Failed

Error: `Can not use the domain as it was not configured for this tenant`

Fix: Add the domain to M365 Admin Center → Settings → Domains and verify with TXT record

---

## PowerShell Commands Reference

See [scripts/teams-commands.ps1](scripts/teams-commands.ps1) for all commands.
