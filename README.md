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
│  │  SBC (t3.small)           │  │SIP TLS  │  │   Direct Routing (E5)     │  │
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

## Phase 2 — FQDN Setup with No-IP  (check -> NOIP DNS config.png)

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

## Phase 4 — Microsoft 365 Setup

### 4.1 Get Microsoft 365 E5 Trial

1. Go to **https://admin.microsoft.com → Billing → Purchase services**
2. Search **"Microsoft 365 E5"**
3. Click **"Start free trial"** (30 days, 25 licenses)
4. Confirm trial activation

> ⚠️ **Do NOT use M365 Business Standard** — it does not include Phone System (MCOEV).
> E5 includes Phone System built-in. No separate Teams Phone license needed.

### 4.2 Create Test Users (check -> MS Teams Active users.png)

1. Go to **Admin Center → Users → Active Users → Add a user**
2. Create two users:
   - `usera@yourtenantname.onmicrosoft.com`
   - `userb@yourtenantname.onmicrosoft.com`

### 4.3 Assign E5 License to Users

1. Go to **Users → Active Users → click user**
2. Click **Licenses and apps** tab
3. Check **Microsoft 365 E5**
4. Click **Save changes**
5. Repeat for second user

### 4.4 Add Domain to M365 (Check -> Adding Domain to 365.png)

1. Go to **Settings → Domains → Add Domain**
2. Enter `mylab-sbc.ddns.net`
3. Choose **TXT verification**  
4. Add the TXT record(refer -> NOIP DNS config.png) in No-IP (same process as Let's Encrypt) 
5. Click **Verify**

> ⚠️ You only need the TXT record verified. MX and CNAME errors for
> Exchange/autodiscover can be ignored — they are email-related only.

---

## Phase 5 — Teams Direct Routing via PowerShell

### 5.1 Install and Connect

```powershell
# Install Teams module
Install-Module -Name MicrosoftTeams -Force -AllowClobber

# Import module
Import-Module MicrosoftTeams

# Connect (use device auth if browser popup fails)
Connect-MicrosoftTeams -UseDeviceAuthentication
```

### 5.2 Register SBC

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

### 5.3 Create PSTN Usage

```powershell
Set-CsOnlinePstnUsage -Identity Global -Usage @{Add="LabUsage"}
```

### 5.4 Create Voice Routes

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

### 5.5 Create Voice Routing Policy

```powershell
New-CsOnlineVoiceRoutingPolicy `
  -Identity "LabVoicePolicy" `
  -OnlinePstnUsages "LabUsage"
```

### 5.6 Assign Numbers to Users

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

## Phase 6 — AudioCodes SBC Configuration

You can watch a youtube video for direct routing for MS teams. Link: https://www.youtube.com/watch?v=reUN9CNPVv4

### 6.1 Initial Setup Wizard

After first login, complete the Setup Wizard:

| Setting | Value |
|---|---|
| Hostname | `lab-sbc-01` |
| Time Zone | Your local timezone |
| NTP Server 1 | `pool.ntp.org` |
| NTP Server 2 | `time.google.com` |
| Web Interface | HTTPS |
| CLI Interface | SSH |

### 6.2 IP Network Interface

Since, we are using VPC to connect both FreePBX and SBC, no need to create for WAN network for MS Teams.  

Navigate to **IP Network → IP Interfaces**:

| Field | Value |
|---|---|
| IP Address | EC2 Private IP (e.g. `172.31.9.171`) |
| Subnet Mask | `255.255.240.0` |
| Default Gateway | VPC Gateway (e.g. `172.31.0.1`) |
| Primary DNS | `8.8.8.8` |
| Application Type | `OAMP + Media + Control` |

### 6.3 NAT Translation

Navigate to **IP Network → NAT Translation → Add**:

| Entry | Source Interface | Target IP | Source Ports |
|---|---|---|---|
| 1 | eth0 | `<ElasticIP of SBC>` | 7000-7999 (RTP) |
| 2 | eth0 | `<ElasticIP of SBC>` | 5061-5061 (SIP) |

### 6.4 Upload TLS Certificate (See step 3.5)

1. Go to **IP Network → Security → TLS Contexts → #0 [default]**
2. Click **"Change Certificate >>"**
3. Upload `mylab-sbc.ddns.net-key-nopass.pem` as **Private Key**
4. Upload `mylab-sbc.ddns.net-chain.pem` as **Certificate**
5. Click **Apply**
6. Click **"Certificate Information >>"** to verify:
   - CN = `mylab-sbc.ddns.net`
   - Issuer = `Let's Encrypt`

### 6.5 Transport Settings

Navigate to **Signaling & Media → SIP Definitions → Transport Settings**:

| Field | Value |
|---|---|
| SIP Transport Type | `TLS` |
| SIPS | `Enable` |
| SIP Destination Port | `5061` |
| SIP NAT Detection | `Enable` |

### 6.6 SIP Interface

Navigate to **Signaling & Media → CORE ENTITIES → SIP Interfaces**:

**For teams**: 

| Field | Value |
|---|---|
| Name | `Teams sip interface` |
| Network Interface | `eth0` |
| Application Type | `SBC` |
| UDP Port | `5060` |
| TCP Port | `5060` |
| TLS Port | `5061` |
| TLS Context Name | `default` |
| Topology Location | `Up` |

**For FreePBX**:

| Field | Value |
|---|---|
| Name | `FreePBX sip interface` |
| Network Interface | `eth0` |
| Application Type | `SBC` |
| UDP Port | `5060` |
| TCP Port | `5060` |
| TLS Port | `5061` |
| TLS Context Name | `default` |
| Topology Location | `Up` |

### 6.7 Media Realms

Navigate to **Signaling & Media → CORE ENTITIES → Proxy Sets**:

**Teams Media Realms**:

| Field | Value |
|---|---|
| Name | `Teams Media Realms` |
| Topology location | `UP` |
| IPv4 Interface Name | `eth0` |
| UDP Port Range Start | `7000` |
| Number Of Media Session Legs | `100` |

**FreePBX Media Realms**:

| Field | Value |
|---|---|
| Name | `FreePBX Media Realms` |
| Topology location | `Down` |
| IPv4 Interface Name | `eth0` |
| UDP Port Range Start | `8000` |
| Number Of Media Session Legs | `100` |

### 6.8 Proxy Sets

Navigate to **Signaling & Media → CORE ENTITIES → Proxy Sets**:

**Proxy Set #1 — Teams Proxyset**:

| Field | Value |
|---|---|
| Name | `Teams Proxyset` |
| SBC IPv4 SIP Interface | `Teams sip interface` |
| TLS Context Name | default |
| Proxy Address | `sip.pstnhub.microsoft.com:5061`, `sip2.pstnhub.microsoft.com:5061`, `sip3.pstnhub.microsoft.com:5061` |
| Proxy Priority | 1,2,3 respectively based on Proxy Address |
| Transport Type | `TLS` |
| Proxy Keep Alive | `Using OPTIONS` |
| Redundancy Mode | `Homing` |	
| Proxy Hot Swap Mode | `Enable` |	
| Proxy Load Balancing Method | `Random Weights` |
| TLS Remote Subject Name | `sip.pstnhub.microsoft.com` |

**Proxy Set #2 — FreePBX Proxyset**:

| Field | Value |
|---|---|
| Name | `FreePBX Proxyset` |
| SBC IPv4 SIP Interface | `FreePBX SIP Interface` |
| Proxy Address | `172.31.2.162:5060` |
| Proxy Priority | 0 |
| Transport Type | `UDP` |
| Proxy Keep Alive | `Using OPTIONS` |
| Proxy Hot Swap Mode | `Disable` |	
| Proxy Load Balancing Method | `Disable` |

### 6.9 IP Groups

Navigate to **Signaling & Media → CORE ENTITIES → IP Groups**:

**IP Group #1 — Teams IP Group**:

| Field | Value |
|---|---|
| Name | `Teams IP Group` |
| Topology location | `UP` |
| Type | `Server` |
| Proxy Set | `Teams Proxyset` |
| IP Profile | **`Teams Teams IP Profile`** ← First do Ip Profile section before doing this! | 
| Media Realm | `Teams Media Realms` |
| SIP Group Name | `mylab-sbc.ddns.net` |
| Local Host Name | `mylab-sbc.ddns.net` |
| Always Use Src Address | `Yes` |
| Teams Direct Routing Mode | **`Enable`** ← Critical! |
| Teams Local Media Optimization Initial Behavior | `Internal` |
| Outbound Message Manipulation | `4` |

**IP Group #2 — FreePBX IP Group**:

| Field | Value |
|---|---|
| Name | `FreePBX IP Group` |
| Topology location | `Down` |
| Type | `Server` |
| Proxy Set | `FreePBX proxyset` |
| IP Profile | **`FreePBX Teams IP Profile`** ← First do Ip Profile section before doing this! | 
| Media Realm | `FreePBX Media Realms` |
| SIP Group Name | `mylab-sbc.ddns.net` |
| Local Host Name | `mylab-sbc.ddns.net` |
| Always Use Src Address | `No` |
| Teams Direct Routing Mode | `Disable` |
| Teams Local Media Optimization Initial Behavior | `DirectMedia` |

### 6.10 IP Profiles

Navigate to **Signaling & Media → CODERS & PROFILES → IP Profiles**:

**IP Profile #1 — Teams IP Profile**:

| Field | Value |
|---|---|
| Name | `Teams IP Profile` |
| SBC Media Security Mode | `Secured` |
| Remote Early Media RTP Detection Mode	 | `By Media` |
| Extension Coders Group | **`AudioCodersGroups_0`** ← First do Coders Settings section before doing this!|
| ICE Mode| `Lite` | 
| SIP UPDATE Support | `Not Supported` |
| Remote re-INVITE | `Supported only with SDP` |
| Remote Delayed Offer Support | `Not Supported` |
| Max Call Duration [min] | `0` |

**IP Profile #2 — FreePBX IP Profile**:

| Field | Value |
|---|---|
| Name | `FreePBX IP Profile` |
| SBC Media Security Mode | `Not Secured` |
| Remote Early Media RTP Detection Mode	 | `By Signaling` |
| ICE Mode| `Disabled` | 
| P-Asserted-Identity Header Mode	 | `Add` |
| SIP UPDATE Support | `Supported` |
| Remote re-INVITE | `Supported` |
| Remote Delayed Offer Support | `Supported` |
| Max Call Duration [min] | `60` |
| Remote REFER Mode | `Handle Locally` |
| Remote Replaces Mode | `Handle Locally` |
| Remote 3xx Mode | `Handle Locally` |

### 6.11 Coders Groups

Navigate to **Signaling & Media → CODERS & PROFILES → Coders Groups**:

**Select which codecs are supported, here its G711 ulaw and alaw**

### 6.12 Classifications

Navigate to **Signaling & Media → SBC → Classification**:

**Classification #1 — Teams-Classification**:

| Field | Value |
|---|---|
| Name | `Teams-Classification` |
| Source SIP Interface | `Teams sip Interface` |
| Source IP Address	 | `52.114.*.*` |
| Source Transport Type | `TLS` | 
| Destination Host	 | `mylab-sbc.ddns.net` |
| Message Condition | `Teams-contact` |
| TLS Remote Subject Name | `*.pstnhub.microsoft.com` |
| Source IP Group | `Teams IP Group` |

**Classification #2 — FreePBX-Classification**:

| Field | Value |
|---|---|
| Name | `FreePBX-Classification` |
| Source SIP Interface | `FreePBX SIP Interface` |
| Source IP Address	 | `172.31.2.162` |
| Source Transport Type | `Any` | 
| Source IP Group | `FreePBX IP Group` |

### 6.13 IP-to-IP Routing

Navigate to **Signaling & Media → SBC → Routing → IP-to-IP Routing**:

**Terminate Options:**

| Field | Value |
|---|---|
| Name | `Terminate Options` |
| Source IP Group | `Any` |
| Request Type | `OPTIONS` |
| ReRoute IP Group | `Any` | 
| Destination Type | `Dest Address` |
| Destination Address | `internal` |

**Teams Refer:**

| Field | Value |
|---|---|
| Name | `Teams refer` |
| Source IP Group | `Any` |
| Call Trigger | `REFER` |
| ReRoute IP Group | `Any` | 
| Destination Type | `Request URI` |
| Destination IP Group | `Teams IP Group` |

**Teams to FreePBX:**

| Field | Value |
|---|---|
| Name | `Teams to FreePBX` |
| Source IP Group | `Teams IP Group` |
| Request Type | `INVITE` |
| ReRoute IP Group | `Any` | 
| Destination Type | `IP Group` |
| Destination IP Group | `Teams IP Group` |

**FreePBX to teams:**

| Field | Value |
|---|---|
| Name | `FreePBX to teams` |
| Source IP Group | `FreePBX IP Group` |
| Request Type | `INVITE` |
| ReRoute IP Group | `Any` | 
| Destination Type | `IP Group` |
| Destination IP Group | `Teams IP Group` |

### 6.14 Message Manipulation

Navigate to **Signaling & Media → MESSAGE MANIPULATION → Message Manipulation**:

**Remove PAI:**

| Field | Value |
|---|---|
| Name | `Remove PAI` |
| Manipulation Set ID | `1` |
| Row Role | `Use Current Condition` |
| Action Subject | `Header.P-Asserted-Identity` | 
| Action Type | `Remove` |

**Change RURI host to FreePBX:**

| Field | Value |
|---|---|
| Name | `Change RURI host to FreePBX` |
| Manipulation Set ID | `4` |
| Row Role | `Use Current Condition` |
| Action Subject | `Header.Request-URI.URL.Host` | 
| Action Type | `Modify` |
| Action Value | `Param.Message.Address.Dst.IP` |
| Message Type | `Any.Request` |

**Remove Privacy Header:**

| Field | Value |
|---|---|
| Name | `Remove Privacy Header` |
| Manipulation Set ID | `4` |
| Row Role | `Use Current Condition` |
| Action Subject | `Header.Privacy` | 
| Action Type | `Remove` |
| Condition | `Header.Privacy exists and Header.from.URL !contains 'anonymous'` |

**Remove HistoryInfo:**

| Field | Value |
|---|---|
| Name | `Remove HistoryInfo` |
| Manipulation Set ID | `4` |
| Row Role | `Use Current Condition` |
| Action Subject | `Header.History-Info.1` | 
| Action Type | `Remove` |
| Condition | `Header.History-Info.1 exists` |

### 6.15 Message Conditions

Navigate to **Signaling & Media → MESSAGE MANIPULATION → Message Conditions**:

| Field | Value |
|---|---|
| Name | `Teams-contact` |
| Condition | `Header.Contact.URL.Host contains 'pstnhub.microsoft.com'` |

### 6.16 Media Security

Navigate to **Signaling & Media → Media → Media Security**:

| Field | Value |
|---|---|
| Media Security | `Enable` |
| Media Security Behavior | `Mandatory` |

### 6.17 Manipulation

Navigate to **Signaling & Media → SBC → Manipulation → Inbound Manipulation**:

| Field | Value |
|---|---|
| Name | `Teams to FreePBX` |
| Source IP Group | `Teams IP Group` |
| Manipulated Item | `Destination` |
| Remove From Left | `2` |

Navigate to **Signaling & Media → SBC → Manipulation → Outbound Manipulation**:

| Field | Value |
|---|---|
| Name | `Teams to FreePBX` |
| Source IP Group | `Teams IP Group` |
| Destination IP Group | `FreePBX IP Group` |
| ReRoute IP Group | `Any` |
| Manipulated Item | `Destination URI` |
| Remove From Left | `2` |

### 6.18 Save Configuration

> ⚠️ AudioCodes does NOT auto-save. Always click **Save** (top right) after changes.
> The Save button turns orange when there are unsaved changes.
> Check the Topology view and see if the configuration is properly arranged for both Teams and FreePBX.
> Once the FreePBX and MS Teams are configured the IP Group server should show 'Green', which indicates the OPTIONS and its response 200 OK is going to and fro from both direct on each servers.

---

## Phase 7 — FreePBX configuration (For FreePBX Setup refer the link: https://github.com/heyiamanoop-dev/FreePBX-16-installation-on-AWS-EC2-instance)

> ⚠️ Use FreePBX 16 with Asterisk 18 with Macros, v20 doesn't support macros so it need to be downgraded to v18.
> How to downgrade from V20 to v18 is provided in the documents section in FreePBX setup.

### Prerequisites

1. Login to FreePBX Admin UI → Admin → Module Admin
2. Ensure these are installed and enabled:
3. • SIP Settings ✅ 
   • Trunks ✅ 
   • Inbound Routes ✅ 
   • Outbound Routes ✅ 
   • Extensions ✅ 
4. After making changes in each page, Submit and Apply config.

### 7.1 Asterisk SIP Settings

Go to **Settings → Asterisk SIP Settings → General Settings**:

| Field | Value |
|---|---|
| External Address | FreePBX Elastic IP (if public) or leave if internal |
| Local Networks | Your AWS VPC subnet e.g. 172.31.0.0/16 |

Then, **SIP Settings[chan_pjsip] -> Under 0.0.0.0 (udp)**:

| Field | Value |
|---|---|
| Port to Listen On | `5060` |
| Domain the transport comes from | `mylab-sbc.ddns.net` - FQDN of SBC|
| Local network | `172.31.0.0/16` |

Submit and Apply config.

### 7.2 Add Trunk

Go to **Connectivity → Trunks → Add Trunk → Add SIP (chan_pjsip) Trunk **:

| Field | Value |
|---|---|
| Trunk Name | `AudioCodes-SBC` |

Then, **pjsip settings -> General**:

| Field | Value |
|---|---|
| SIP Server | `172.31.9.171` - IP of SBC|
| SIP Server Port | `5066` |
| Context | `from-pstn` |
| Transport | `0.0.0.0-udp` |

Then, **pjsip settings -> Advanced**:

| Field | Value |
|---|---|
| From Domain | `172.31.9.171` - IP of SBC|
| Direct Media | YES |
| Rewrite Contact | YES |
| Media Encryption | `None` |

Submit and Apply config.

### 7.3 Create Extensions (for Testing)

Go to **Applications → Extensions → Add Extensions → Add PJSIP Extension → General**:

| Field | Value |
|---|---|
| User Extensiom | `101`|
| Display Name | `Teamsuser1`|
| Secret | Password for Microsip softphone |
| Rewrite Contact | YES |
| Media Encryption | `None` |

Then, **PJSIP Extension -> Advanced**:

| Field | Value |
|---|---|
| Transport | `0.0.0.0-udp`|
| Dial | `PJSIP/101` |
| Rewrite Contact | YES |
| Force rport | YES |
| Media Encryption | `None` |
| Direct Media | No |

Do the same for another extension with Display Name : Teamsuser2 with user extension 102, Then Submit and Apply config.

### 7.4 Create Inbound route

Go to **Connectivity → Inbound route → Add Inbound route →  General**:

| Field | Value |
|---|---|
| Description | `From-SBC`|
| DID Number | `+15550101` - **check the DID number in MS Teams Admin page → Users → Manage Users or Leave Blank to accept all** |
| Set Destination  | Extensions and 101 Teamsuser1 |

Submit and Apply config.

### 7.5 Create Outbound route

Go to **Connectivity → Outbound route → Add Outbound route →  Route Settings**:

| Field | Value |
|---|---|
| Route Name | `To-Teams-via-SBC`|
| Trunk Sequence for Matched Routes | `AudioCodesSBC` |

Then, **Dial Patterns**:

Add below patterns 

| Pattern | Description |
|---|---|
| +NXXXXXXXXXXXX | 11-digit E.164 with + |
| 1NXXXXXXXXXX | 11-digit with country code |
| +X. | Any E.164 with + |
| NXXXXXXXXXX | 10-digit US |

Submit and Apply config. Once the configuration is changed then reload the Asterisk using command:
```bash
sudo fwconsole reload `
```

---
## Phase 8 — Verification and Testing

### 8.1 Verify SBC Connectivity

Check Teams Admin Center:
1. Go to **https://admin.teams.microsoft.com**
2. Navigate to **Voice → Direct Routing**
3. Verify SBC shows:
   - TLS Connectivity: **Active**
   - SIP Options: **Active**

Check AudioCodes:
1. Go to **Monitor → VoIP Status → Proxy Sets Status**
2. Verify both Teams and freePBX proxy shows:
   - Status: **ONLINE**
   - Success Count: **increasing**
   - Failure Count: **0**

### 8.2 Test Call - See [Test call Between MS Teams and freePBX.pdf](https://github.com/user-attachments/files/26834074/Test.call.Between.MS.Teams.and.freePBX.pdf)

1. Open Microsip as Extension 101
2. Go to **Calls → Dial Pad**
3. Dial `+15550101`
4. Teamsuser1 should receive the incoming call in Teams

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

### Change Password using Cli
1. Login to SBC using putty with EC2 instance Public IP
2. Enter 'enable' mode
```
Mediant SW> enable
Password:
```
3. Enter password as 'Admin'
4. Enter configure system
```
Mediant SW# configure system

Mediant SW(config-system)# 
```
5. then enter User admin
```
Mediant SW(config-system)# user Admin
```
Configure existing user Admin
```
Mediant SW(user-Admin)# 
```
6. Type password command to add new password
```
Mediant SW(user-Admin)# Password
```
7. Enter new password and then enter, it will save new password. Now login using 'Admin' as username with new password.

------------------------------------------------

---

## PowerShell Commands Reference

See [teams-commands.ps1](teams-commands.ps1) for all commands.
