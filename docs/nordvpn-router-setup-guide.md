# 🔐 NordVPN Router-Level Configuration Guide

## ASUS ROG Rapture GT-AX11000 | Network: 192.168.50.0/24

**Complete guide for setting up NordVPN OpenVPN on your router to protect all network devices**

---

## 📊 **Current Network Status**

```yaml
Your Network:
  Router: ASUS ROG Rapture GT-AX11000
  Router IP: 192.168.50.1
  Subnet: 192.168.50.0/24

  IPv4 Configuration:
    Gateway: 192.168.50.1
    DNS: 1.1.1.1, 8.8.8.8, 192.168.50.1
    DHCP Range: 192.168.50.2 - 192.168.50.254

  IPv6 Configuration:
    Status: ✅ ENABLED (Link-local)
    Addresses:
      - fe80::f3f4:fa0e:38e0:8ae0%25 (Hyper-V)
      - fe80::1556:e7a8:ea8a:32fd%48 (WSL)
    Note: Link-local only (no global IPv6 from ISP yet)

Current Setup:
  ✅ PC: Ethernet connection (Killer E3100G 2.5Gbps)
  ✅ NordVPN: App-based with Meshnet
  ⚠️ Router VPN: Not configured (we'll fix this!)
```

---

## 🎯 **Why Router-Level VPN?**

### Current Setup (NordVPN App):

```yaml
Protection: ✅ Your PC only
  ❌ Other devices need individual VPN apps
  ❌ IoT devices can't use VPN
  ❌ Guest devices unprotected
```

### After Router VPN Setup:

```yaml
Protection: ✅ ALL devices automatically protected
  ✅ No app needed on each device
  ✅ IoT devices protected (smart TV, cameras, etc.)
  ✅ Guest network protected
  ✅ Better performance (router handles encryption once)
  ✅ Perfect for CPA firm (client data always secure)
```

---

## 📥 **Step 1: Get NordVPN OpenVPN Config Files**

### Option A: Download from NordVPN Website

```yaml
1. Visit: https://nordvpn.com/ovpn/

2. Select Server:
   Country: United States (recommended for best speed)
   Server: Any US server (e.g., us9999)
   Protocol: UDP (faster) or TCP (more reliable)

   Recommended Servers:
   - us9999.nordvpn.com.udp.ovpn (UDP - fastest)
   - us9999.nordvpn.com.tcp.ovpn (TCP - more stable)

3. Download:
   Click server → Download .ovpn file
   Save to: Downloads folder
```

### Option B: Download via PowerShell (Automated)

```powershell
# Create download directory
New-Item -Path "$env:USERPROFILE\Downloads\NordVPN-Configs" -ItemType Directory -Force

# Download multiple configs for backup
$servers = @("us9999", "us9998", "us9997")
foreach ($server in $servers) {
    $url = "https://downloads.nordcdn.com/configs/files/ovpn_udp/servers/$server.nordvpn.com.udp.ovpn"
    $output = "$env:USERPROFILE\Downloads\NordVPN-Configs\$server.udp.ovpn"
    Invoke-WebRequest -Uri $url -OutFile $output
    Write-Host "✅ Downloaded: $server.udp.ovpn" -ForegroundColor Green
}

Write-Host "`n📁 Configs saved to: $env:USERPROFILE\Downloads\NordVPN-Configs" -ForegroundColor Cyan
```

### Get Your NordVPN Service Credentials

**IMPORTANT**: You need your **service credentials**, not your account email/password!

```yaml
How to Get Service Credentials:
  1. Login to NordVPN account: https://my.nordaccount.com/
  2. Go to: Dashboard → Services → NordVPN
  3. Click: "Set up NordVPN manually"
  4. Click: "Show credentials"
  5. Copy:
     - Service Username (looks like: abc123XYZ456)
     - Service Password (random string)

  ⚠️ DO NOT use your NordVPN account email!
  ⚠️ Use the manual setup credentials only!
```

---

## 🔧 **Step 2: Configure ASUS Router**

### Access Router Admin Panel

```yaml
1. Open browser: http://192.168.50.1
2. Login:
  Username: admin
  Password: [your router password]
3. You should see: ASUSWRT dashboard
```

### Navigate to VPN Client

```yaml
Path: Advanced Settings → VPN → VPN Client

You should see:
  - List of VPN connections (currently empty)
  - "Add profile" button
```

### Add OpenVPN Profile

```yaml
Click "Add profile" and configure:

Basic Settings:
  VPN Type: OpenVPN
  Description: NordVPN-US-Router

  Get VPN account info automatically: ❌ NO

Configuration File:
  Click "Choose File"
  Select your downloaded .ovpn file
  Example: us9999.nordvpn.com.udp.ovpn

Username: [Your NordVPN service username]
Password: [Your NordVPN service password]

Advanced Settings:
  Accept DNS Configuration: ✅ YES
  Redirect Internet traffic through tunnel: ✅ YES (All traffic)

  Block routed clients if tunnel goes down:
    ✅ YES (Kill Switch - recommended for CPA compliance)

  Authentication only: ❌ NO

Optional Settings (can leave default):
  TLS Renegotiation Time: -1
  Connection retry: 0
  Verify server certificate: ❌ NO (NordVPN certs are valid)

Click: Upload → Apply

Wait 30-60 seconds for connection to establish
```

### Verify Connection Status

```yaml
In VPN Client page, you should see:

Connection Status:
  ✅ Connected (green check mark)
  Server: us9999.nordvpn.com
  Duration: 00:01:23 (counting up)

If you see:
  ❌ Connection Failed
  → Check username/password (must be service credentials!)
  → Try different server config file
  → Check "Troubleshooting" section below
```

---

## ✅ **Step 3: Test VPN Protection**

### Test 1: Check Your IP Address

```powershell
# From your PC (192.168.50.242)
# Open browser and visit:
https://nordvpn.com/what-is-my-ip/

Expected Result:
  ✅ Shows: NordVPN server location (e.g., United States)
  ✅ IP Address: NOT your real home IP
  ✅ ISP: NordVPN

If shows your real IP:
  ❌ VPN not working - see troubleshooting below
```

### Test 2: DNS Leak Test

```powershell
# Visit: https://www.dnsleaktest.com/
# Click "Extended test"

Expected Result:
  ✅ All DNS servers show NordVPN
  ✅ Location: Same as VPN server

If shows your ISP's DNS:
  ❌ DNS leak detected
  → Enable "Accept DNS Configuration" in router
  → Disable IPv6 on router (see below)
```

### Test 3: WebRTC Leak Test

```yaml
Visit: https://browserleaks.com/webrtc

Expected Result:
  ✅ Public IP: NordVPN server IP
  ✅ No local IP leaks

If shows local IP:
  ⚠️ Minor WebRTC leak (usually not critical)
  → Disable WebRTC in browser settings
```

### Test 4: Verify All Devices Protected

```yaml
Test from: ✅ Your PC (192.168.50.242)
  ✅ Your phone (connected to WiFi)
  ✅ Another device on network

All should show:
  - NordVPN IP address
  - NordVPN location
  - Protected status
```

---

## 🌐 **Step 4: Configure DNS Settings (Important!)**

### Router DNS Configuration

```yaml
Navigate to: WAN → Internet Connection → WAN DNS Setting

WAN DNS Settings:
  Connect to DNS Server automatically: ❌ NO

  DNS Server 1: 103.86.96.100 (NordVPN DNS)
  DNS Server 2: 103.86.99.100 (NordVPN DNS)

  Or use these (also NordVPN):
  DNS Server 1: 103.86.96.96
  DNS Server 2: 103.86.99.99

Why NordVPN DNS?
  ✅ No DNS leaks
  ✅ Prevents ISP tracking
  ✅ Required for full privacy
  ✅ CPA compliance (client data protection)

Click: Apply
```

### Alternative: Use Cloudflare DNS with WARP

```yaml
If you prefer Cloudflare:
  DNS Server 1: 1.1.1.1 (Cloudflare)
  DNS Server 2: 1.0.0.1 (Cloudflare)

Benefits: ✅ Faster DNS resolution
  ✅ Privacy-focused
  ✅ Malware blocking (if using 1.1.1.2)

Note: Slightly less private than NordVPN DNS
```

---

## 🔒 **Step 5: IPv6 Configuration (CRITICAL!)**

### Why Disable IPv6 on VPN?

```yaml
Problem:
  - Most VPN providers (including NordVPN) don't route IPv6
  - IPv6 traffic goes outside VPN tunnel
  - DNS leaks via IPv6
  - Real IP can leak via IPv6

Solution: Disable IPv6 on WAN or use IPv6 leak protection
```

### Option A: Disable IPv6 on Router (Recommended)

```yaml
Navigate to: IPv6 → Basic Config

IPv6 Settings:
  Connection Type: Disabled

Click: Apply

⚠️ This disables IPv6 for entire network
✅ Ensures no IPv6 leaks
✅ VPN protection guaranteed
```

### Option B: Enable IPv6 with NordVPN (If Supported)

```yaml
Check if your server supports IPv6:
  - Visit: https://nordvpn.com/features/ipv6/
  - Most servers DON'T support IPv6 yet

If supported:
  Configure router with IPv6 pass-through
  Test for leaks thoroughly

Not Recommended for CPA firm (risk of leaks)
```

### Current Status: IPv6 Link-Local Only

```yaml
Your Current IPv6: fe80::f3f4:fa0e:38e0:8ae0%25 (Link-local only)
  fe80::1556:e7a8:ea8a:32fd%48 (Link-local only)

Good News: ✅ Link-local IPv6 doesn't leak outside network
  ✅ No global IPv6 address from ISP
  ✅ Safe for VPN use

Action: Keep IPv6 disabled on WAN (or set to "Disabled")
  Link-local is fine for local network
```

---

## 🎛️ **Step 6: Advanced Router Settings**

### Enable Kill Switch (Recommended)

```yaml
Navigate to: VPN → VPN Client → Your Connection → Edit

Kill Switch Options: ✅ Block routed clients if tunnel goes down

What it does:
  - Blocks all internet if VPN disconnects
  - Prevents accidental leaks
  - Critical for CPA compliance

Trade-off:
  - Internet stops if VPN fails
  - Must manually reconnect VPN
  - Worth it for security
```

### VPN Policy Routing (Optional)

```yaml
Use Case: Some devices bypass VPN

Example:
  - Work PC: Use VPN
  - Smart TV: Bypass VPN (better Netflix performance)
  - IoT cameras: Use VPN (security)

Configuration:
  Navigate to: VPN Client → Edit → VPN Director

  Rules:
  Source IP       | VPN Routing
  192.168.50.242  | ✅ Use VPN (Your PC)
  192.168.50.100  | ❌ Bypass VPN (Smart TV)
  All Others      | ✅ Use VPN (default)

  Click: Apply
```

### QoS for VPN Traffic

```yaml
Navigate to: QoS → QoS Settings

Enable QoS: ✅ YES

Priority Rules:
  Highest: Microsoft Teams, Zoom (video conferencing)
  High: QuickBooks, Azure, Office 365
  Medium: Web browsing, email
  Low: Downloads, streaming

Why?
  - VPN adds latency
  - QoS ensures business apps stay fast
  - CPA work remains responsive
```

---

## 📊 **Network Performance Comparison**

### Before Router VPN:

```yaml
Speed Test (no VPN):
  Download: 500 Mbps
  Upload: 100 Mbps
  Latency: 10ms

DNS Resolution: 15ms
Connection: Direct to ISP
```

### After Router VPN (Expected):

```yaml
Speed Test (with VPN):
  Download: 450 Mbps (10% overhead)
  Upload: 90 Mbps (10% overhead)
  Latency: 25-40ms (added VPN hop)

DNS Resolution: 20-30ms
Connection: ISP → VPN → Internet

Note:
  - UDP protocol is faster than TCP
  - Nearby servers = better speed
  - 2.5Gbps Ethernet handles VPN easily
```

---

## 🔍 **Monitoring & Maintenance**

### Daily Checks (2 minutes)

```powershell
# Check VPN status from any device
# Visit: http://192.168.50.1
# Navigate to: VPN → VPN Client
# Verify: Status = Connected ✅

# Alternative: Quick IP check
# Visit: https://nordvpn.com/what-is-my-ip/
# Should show: NordVPN location
```

### Weekly Checks (5 minutes)

```yaml
1. Router VPN Status:
  - Connection uptime (should be days/weeks)
  - Check for disconnections

2. DNS Leak Test:
  - Visit: dnsleaktest.com
  - Run extended test
  - Verify: All NordVPN servers

3. Speed Test:
  - Visit: speedtest.net
  - Compare to expected speeds
  - If slow: Try different server
```

### Monthly Maintenance (15 minutes)

```yaml
1. Update Router Firmware: Administration → Firmware Upgrade
  Check for updates
  Apply if available

2. Rotate VPN Server: VPN Client → Edit
  Upload different server config
  Prevents server overload

3. Review Logs: System Log → VPN Client
  Check for errors or warnings

4. Speed Optimization: Try different servers
  Test UDP vs TCP
  Adjust QoS rules
```

---

## 🚨 **Troubleshooting Guide**

### Problem 1: VPN Won't Connect

```yaml
Symptoms:
  ❌ Connection Status: Failed
  ❌ Red X in VPN Client

Solutions:
  1. Verify Credentials:
     - Must use service username/password
     - NOT your NordVPN account email

  2. Check .ovpn File:
     - Try different server
     - Download fresh config

  3. Router Firewall:
     - Temporarily disable
     - Test connection
     - Re-enable after

  4. Reboot Router:
     - Administration → Reboot
     - Wait 2 minutes
     - Try again
```

### Problem 2: VPN Connects But No Internet

```yaml
Symptoms:
  ✅ VPN Status: Connected
  ❌ Can't browse web

Solutions:
  1. Check DNS Settings:
     - WAN → DNS Settings
     - Use NordVPN DNS (103.86.96.100)

  2. Disable IPv6:
     - IPv6 → Disable
     - Prevents conflicts

  3. Check Redirect Setting:
     - VPN Client → Edit
     - Redirect traffic: ✅ YES

  4. Flush DNS:
     Run on PC: ipconfig /flushdns
```

### Problem 3: Slow Speeds on VPN

```yaml
Symptoms: ✅ VPN Connected
  ⚠️ Very slow downloads/uploads

Solutions:
  1. Try Different Server:
    - Closer = faster
    - Less loaded = faster

  2. Switch UDP/TCP:
    - UDP is usually faster
    - TCP more stable

  3. Enable QoS:
    - Prioritize business traffic
    - Limit background downloads

  4. Check CPU Load:
    - ASUS GT-AX11000 is powerful
    - Should handle VPN easily
    - If maxed: reduce bandwidth
```

### Problem 4: DNS Leaks Detected

```yaml
Symptoms: 🔍 DNS leak test shows ISP servers
  ⚠️ Not fully protected

Solutions:
  1. Force NordVPN DNS:
    - WAN → DNS: 103.86.96.100
    - Disable automatic DNS

  2. Disable IPv6:
    - Common source of DNS leaks
    - Disable completely

  3. Check VPN Settings:
    - Accept DNS Configuration: ✅ YES
    - This is critical!

  4. Test Again:
    - Clear browser cache
    - Run extended DNS leak test
```

### Problem 5: Some Devices Not Protected

```yaml
Symptoms: ✅ PC shows VPN IP
  ❌ Phone shows real IP

Solutions:
  1. Check Connection:
    - Device connected to router WiFi?
    - Not using mobile data?

  2. Verify VPN Routing:
    - VPN Director settings
    - Ensure device not bypassed

  3. Restart Device:
    - Disconnect WiFi
    - Reconnect
    - Check IP again

  4. Check VPN Status:
    - Ensure VPN connected on router
    - Not just on individual devices
```

---

## 💡 **Pro Tips for CPA Firm**

### Security Best Practices

```yaml
✅ Always use Kill Switch
- Prevents accidental data leaks
- Critical for client confidentiality

✅ Use NordVPN DNS
- Prevents DNS tracking
- ISP can't see what you're accessing

✅ Enable router firewall
- Additional layer of protection
- Blocks malicious traffic

✅ Regular security audits
- Monthly DNS leak tests
- Check VPN connection logs
- Review router security settings
```

### Performance Optimization

```yaml
✅ Choose nearby servers
   - US East Coast for best speed
   - <30ms latency to server

✅ Enable QoS
   - Prioritize: QuickBooks, Azure, Teams
   - Limit: Streaming, downloads

✅ Use UDP protocol
   - Faster than TCP
   - Better for real-time apps

✅ Monitor bandwidth
   - Router has bandwidth monitor
   - Identify heavy users
   - Adjust QoS as needed
```

### Compliance Considerations

```yaml
✅ Document VPN setup
- Keep config files backed up
- Document server choices
- Log any changes

✅ Audit logs
- Router logs VPN connections
- Review monthly
- Keep for compliance

✅ Test regularly
- Weekly IP checks
- Monthly DNS leak tests
- Quarterly speed tests

✅ Backup configuration
- Export router settings
- Save .ovpn files
- Store in Azure Key Vault
```

---

## 📋 **Quick Reference Commands**

### PowerShell Network Diagnostics

```powershell
# Check your public IP (should show VPN)
Invoke-RestMethod -Uri "https://api.ipify.org?format=json"

# Test DNS resolution
nslookup microsoft.com

# Check active network adapters
Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object Name, InterfaceDescription, LinkSpeed

# Verify IPv6 status
Get-NetAdapterBinding -ComponentID ms_tcpip6

# Test VPN speed
# Install: Install-Module -Name SpeedTest
Test-SpeedTest

# Flush DNS cache
ipconfig /flushdns

# Renew DHCP lease
ipconfig /renew

# Check routing table
route print

# Test connectivity to router
Test-Connection 192.168.50.1 -Count 4
```

### Router Admin URLs

```yaml
Main Admin: http://192.168.50.1
VPN Settings: http://192.168.50.1/Advanced_VPN_Content.asp
Firewall: http://192.168.50.1/Advanced_Firewall_Content.asp
QoS: http://192.168.50.1/Advanced_QOSUserSpec_Content.asp
System Log: http://192.168.50.1/Main_LogStatus_Content.asp
```

### NordVPN Resources

```yaml
Account Dashboard: https://my.nordaccount.com/
Download Configs: https://nordvpn.com/ovpn/
Service Credentials: https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/
IP Check: https://nordvpn.com/what-is-my-ip/
Status Page: https://nordvpn.com/status/
Support: https://support.nordvpn.com/
```

---

## 🔄 **Migration from App to Router VPN**

### Before Migration Checklist

```yaml
✅ Backup current network config
✅ Download VPN config files
✅ Get service credentials
✅ Test on off-hours (less disruptive)
✅ Have backup internet (mobile hotspot)
✅ Notify users (if multi-user network)
```

### Migration Steps

```yaml
1. Test Period (Week 1):
  - Keep VPN apps running
  - Configure router VPN
  - Test both simultaneously
  - Verify protection on all devices

2. Transition (Week 2):
  - Disable VPN apps one by one
  - Confirm router VPN works
  - Monitor for issues

3. Full Cutover (Week 3):
  - Uninstall VPN apps (except Meshnet)
  - Router VPN only
  - Final testing

4. Optimization (Week 4):
  - Fine-tune QoS
  - Test different servers
  - Document final setup
```

### Rollback Plan

```yaml
If router VPN causes problems: 1. Disable router VPN
  VPN Client → Disconnect

  2. Re-enable VPN apps
  Install NordVPN app
  Connect to server

  3. Troubleshoot router
  Review logs
  Try different config
  Contact NordVPN support

  4. Retry when ready
  Test off-hours
  Smaller scope
```

---

## 📸 **Expected Screenshots Guide**

### Router VPN Client Page (Connected)

```
┌─────────────────────────────────────┐
│ VPN Client                          │
├─────────────────────────────────────┤
│ Connection Name: NordVPN-US-Router  │
│ Status: ✅ Connected                │
│ Server: us9999.nordvpn.com          │
│ Protocol: OpenVPN (UDP)             │
│ Duration: 05:23:15                  │
│ [Disconnect] [Edit] [Delete]        │
└─────────────────────────────────────┘
```

### IP Check (Protected)

```
┌─────────────────────────────────────┐
│ NordVPN What Is My IP               │
├─────────────────────────────────────┤
│ ✅ You are protected!               │
│                                     │
│ Your IP: 123.45.67.89               │
│ Location: United States             │
│ ISP: NordVPN                        │
│ Hostname: us9999.nordvpn.com        │
└─────────────────────────────────────┘
```

### DNS Leak Test (No Leaks)

```
┌─────────────────────────────────────┐
│ DNS Leak Test Results               │
├─────────────────────────────────────┤
│ ✅ No DNS leaks detected!           │
│                                     │
│ DNS Servers:                        │
│ 1. NordVPN (United States)          │
│ 2. NordVPN (United States)          │
│ 3. NordVPN (United States)          │
└─────────────────────────────────────┘
```

---

## ✅ **Final Verification Checklist**

```yaml
Router Configuration: ✅ VPN Client shows "Connected"
  ✅ Connection stable (>5 minutes)
  ✅ Kill Switch enabled
  ✅ DNS set to NordVPN servers
  ✅ IPv6 disabled (or leak-protected)
  ✅ QoS configured
  ✅ Firewall enabled

Protection Tests: ✅ IP check shows NordVPN
  ✅ DNS leak test passes
  ✅ WebRTC leak test passes
  ✅ All devices protected
  ✅ Speed acceptable (>80% baseline)

Documentation: ✅ Config files backed up
  ✅ Credentials secured (Azure Key Vault)
  ✅ Setup documented
  ✅ Troubleshooting steps ready

Ready for Production: ✅ Week of testing completed
  ✅ No issues found
  ✅ Users notified
  ✅ Rollback plan ready
```

---

## 🎉 **Success! What You've Accomplished**

```yaml
Network Security: ✅ Entire network protected by VPN
  ✅ All devices encrypted
  ✅ DNS leaks prevented
  ✅ Kill Switch active

Compliance: ✅ Client data always encrypted
  ✅ ISP can't track activity
  ✅ Audit trail in router logs
  ✅ CPA compliance maintained

Performance: ✅ Minimal speed impact
  ✅ QoS ensures business apps fast
  ✅ 2.5Gbps Ethernet fully utilized
  ✅ Multiple devices no problem

Convenience: ✅ No VPN app management
  ✅ New devices auto-protected
  ✅ One-time setup
  ✅ Always-on protection
```

---

<p align="center">
  <img src="https://img.shields.io/badge/Router-ASUS_GT--AX11000-success" alt="Router">
  <img src="https://img.shields.io/badge/VPN-NordVPN-blue" alt="VPN">
  <img src="https://img.shields.io/badge/Protocol-OpenVPN-orange" alt="Protocol">
  <img src="https://img.shields.io/badge/Security-Enterprise-green" alt="Security">
</p>

---

**Your network is now enterprise-grade secure! 🔒**

**Questions? Issues? Check the troubleshooting section or open an issue in the compliance-governance-test repo!**
