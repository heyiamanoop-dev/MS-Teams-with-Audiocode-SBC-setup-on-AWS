# AudioCodes Mediant VE SBC — Configuration Reference

## Quick Settings Summary

### Transport Settings
| Setting | Value |
|---|---|
| SIP Transport Type | TLS |
| SIPS | Enable |
| SIP Destination Port | 5061 |
| SIP NAT Detection | Enable |
| Remove SIPS from Non-Secured Transport | Enable |

### Media Security
| Setting | Value |
|---|---|
| Media Security | Enable |
| Media Security Behavior | Mandatory |
| Offered SRTP Cipher Suites | All |

### SIP Interface
| Setting | Value |
|---|---|
| Network Interface | eth0 |
| Application Type | SBC |
| UDP Port | 5060 |
| TCP Port | 5060 |
| TLS Port | 5061 |
| TLS Context Name | default |
| Topology Location | Up |

### Proxy Set — ITSP (Teams)
| Setting | Value |
|---|---|
| Name | ITSP |
| Proxy Keep Alive | Using OPTIONS |
| Proxy Keep Alive Time | 60 |
| Redundancy Mode | Homing |
| Proxy Hot Swap | Enable |
| TLS Context Name | default |

### Microsoft Teams Proxy Addresses
| Priority | Address | Port | Transport |
|---|---|---|---|
| 1 | sip.pstnhub.microsoft.com | 5061 | TLS |
| 2 | sip2.pstnhub.microsoft.com | 5061 | TLS |
| 3 | sip3.pstnhub.microsoft.com | 5061 | TLS |

### IP Group — ITSP (Teams)
| Setting | Value |
|---|---|
| Name | ITSP |
| Type | Server |
| Proxy Set | ITSP |
| SIP Group Name | mylab-sbc.ddns.net |
| Teams Direct Routing Mode | Enable |
| Teams Local Media Optimization | None |
| Classify by Proxy Set | Enable |
| Media TLS Context | default |

## Monitoring

### Check SBC Status
Monitor → VoIP Status → Proxy Sets Status

Expected healthy state:
- Status: ONLINE
- Success Count: Increasing every 60 seconds
- Failure Count: 0

### Check SIP Interface
Monitor → VoIP Status → SIP Interfaces

### Message Log
Troubleshoot → Message Log → Start Logging

Look for:
- OPTIONS from 52.114.x.x — Microsoft pinging SBC ✓
- 200 OK responses — SBC responding correctly ✓
- TLS handshake messages ✓

## Common Issues

### Watchdog Crash
Symptoms in Message Log:
```
SWWD: Block Task DSPD
SoftWatchdogThread() freezed
```
Cause: Insufficient RAM (t3.small = 2GB only)
Fix: Upgrade to m7i-flex.large (8GB) or c7i-flex.large

### TLS Not Connecting
1. Check Topology Location = Up on SIP Interface
2. Check Teams Direct Routing Mode = Enable on IP Group #2
3. Check Keep Alive = Using OPTIONS on Proxy Set #2
4. Check NAT Translation entries exist for Elastic IP
5. Check port 5061 open in AWS Security Group

### No SIP Traffic
1. Check Proxy Set #2 has all 3 Microsoft FQDNs
2. Check Keep Alive is enabled
3. Do graceful restart after config changes
