# TLS Certificate Setup Guide

## Overview
Microsoft Teams Direct Routing requires a publicly trusted TLS certificate
on port 5061. Self-signed certificates will NOT work.

## Tools Required
- win-acme (Let's Encrypt client for Windows)
- OpenSSL for Windows
- No-IP Enhanced DNS account (supports TXT records)

## Step 1 — Domain Setup (No-IP)

1. Sign up at https://noip.com
2. Create hostname: mylab-sbc → domain: .ddns.net
3. Set A record to your AWS Elastic IP
4. Upgrade to Enhanced Dynamic DNS for TXT record support

## Step 2 — Get Certificate (win-acme)

Download: https://github.com/win-acme/win-acme/releases

Run as Administrator:
```cmd
cd C:\win-acme
wacs.exe
```

Menu selections:
```
M → 2 → mylab-sbc.ddns.net → 4 → 6 → 2 → 2
Path: C:\Users\<user>\Desktop
Password: 1 (None — required for AudioCodes!)
5 → 1
```

## Step 3 — Add DNS TXT Record

When win-acme shows the TXT challenge:
1. Go to No-IP → DNS Records → Manage DNS Records
2. Select second radio button (subdomain)
3. Type: _acme-challenge
4. Data: paste the random string from win-acme
5. Save

Verify:
```cmd
nslookup -type=TXT _acme-challenge.mylab-sbc.ddns.net 8.8.8.8
```

Press Enter in win-acme when TXT appears.

## Step 4 — Remove Password from Key

IMPORTANT: AudioCodes cannot use password-protected keys.

```cmd
cd C:\Users\<user>\Desktop
openssl rsa -in "mylab-sbc.ddns.net-key.pem" -out "mylab-sbc.ddns.net-key-nopass.pem"
```

## Step 5 — Upload to AudioCodes

1. Login to AudioCodes web UI
2. IP Network → Security → TLS Contexts → #0 [default]
3. Click "Change Certificate >>"
4. Upload mylab-sbc.ddns.net-key-nopass.pem as Private Key
5. Upload mylab-sbc.ddns.net-chain.pem as Certificate
6. Apply → Save to Flash

## Step 6 — Verify Certificate

Click "Certificate Information >>" and confirm:
- CN = mylab-sbc.ddns.net
- Issuer = Let's Encrypt (R12)
- Valid Until = ~90 days from issue date

## Renewal

Let's Encrypt certificates expire after 90 days.
Re-run win-acme and repeat Steps 2-5.

## Verify TLS from Command Line

```cmd
openssl s_client -connect mylab-sbc.ddns.net:5061 -tls1_2
```

Expected:
- CONNECTED
- Certificate CN = mylab-sbc.ddns.net
- Protocol: TLSv1.2 or TLSv1.3
