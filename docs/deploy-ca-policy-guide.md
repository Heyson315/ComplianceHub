# 🚀 PowerShell Deployment Script Guide
**Automated CA Policy Deployment via Microsoft Graph API**

![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell)
![Graph API](https://img.shields.io/badge/Microsoft_Graph-API-0078D4?logo=microsoft)
![Automation](https://img.shields.io/badge/Automation-Ready-success)

---

## 📋 **What This Script Does**

The `deploy-ca-policy.ps1` script automates the deployment of Conditional Access policies from your YAML templates to your Azure tenant.

### **Features:**

✅ **Reads YAML templates** (no manual JSON creation!)  
✅ **Converts to Graph API format** automatically  
✅ **Authenticates to Microsoft Graph** with proper scopes  
✅ **Creates or updates** policies intelligently  
✅ **Validates deployment** automatically  
✅ **WhatIf mode** for safe testing  
✅ **Report-only mode** for phased rollout  
✅ **Exports deployed policy** JSON for records  

---

## 🎯 **Quick Start**

### **1. Install Prerequisites:**

```powershell
# PowerShell 7+ (check version)
$PSVersionTable.PSVersion  # Should be 7.0+

# Install required modules
Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Force
Install-Module -Name Microsoft.Graph.Identity.SignIns -Scope CurrentUser -Force
Install-Module -Name powershell-yaml -Scope CurrentUser -Force
```

---

### **2. Test with WhatIf (Safe!):**

```powershell
cd E:\source\Heyson315\compliance-governance-test

# Preview what would happen (no changes made)
.\deploy-ca-policy.ps1 `
    -PolicyFile "docs/policies/conditional-access-solo-cpa-custom.yaml" `
    -WhatIf
```

**Expected Output:**
```
🚀 Conditional Access Policy Deployment Tool
   Automated deployment via Microsoft Graph API

================================================================================
  1️⃣  Checking Prerequisites
================================================================================

  ✅ PowerShell Version: 7.4.0
  ✅ Microsoft.Graph.Authentication installed (v2.10.0)
  ✅ Microsoft.Graph.Identity.SignIns installed (v2.10.0)
  ✅ powershell-yaml installed

================================================================================
  2️⃣  Connecting to Microsoft Graph
================================================================================

  ℹ️  Not connected, initiating authentication...
  [Browser window opens for authentication]
  ✅ Connected to tenant: 12345678-1234-1234-1234-123456789012
  ℹ️  Account: hassan@yourtenant.onmicrosoft.com
  ✅ All required permissions granted

================================================================================
  3️⃣  Reading Policy Template
================================================================================

  ℹ️  Reading file: docs/policies/conditional-access-solo-cpa-custom.yaml
  ✅ Parsed YAML successfully
  ℹ️  Policy Name: CA-Solo-CPA-Client-Collaboration
  ℹ️  Display Name: Solo CPA Firm - Client Collaboration & Accounting Software

================================================================================
  4️⃣  Converting to Graph API Format
================================================================================

  ℹ️  Converting YAML to Graph API JSON...
  ✅ Conversion successful
  ℹ️  Policy will be deployed as: enabledForReportingButNotEnforced

================================================================================
  5️⃣  Deploying Policy
================================================================================

  ℹ️  WHATIF: Would create new policy 'Solo CPA Firm - Client Collaboration & Accounting Software'

================================================================================
  ✅ WhatIf Complete
================================================================================

  No changes were made (WhatIf mode)
  Run without -WhatIf to deploy
```

---

### **3. Deploy in Report-Only Mode (Safe!):**

```powershell
# Deploy policy in report-only mode (Phase 1)
.\deploy-ca-policy.ps1 `
    -PolicyFile "docs/policies/conditional-access-solo-cpa-custom.yaml" `
    -ReportOnly
```

This creates the policy but **doesn't enforce it** - just logs what would happen!

---

### **4. Deploy for Real (Production):**

```powershell
# Deploy policy in enforcement mode
.\deploy-ca-policy.ps1 `
    -PolicyFile "docs/policies/conditional-access-solo-cpa-custom.yaml" `
    -Force
```

**⚠️ Warning:** This will enforce the policy immediately! Use `-ReportOnly` first!

---

## 📊 **Command Examples**

### **Example 1: Deploy Standard Policy (P1)**

```powershell
.\deploy-ca-policy.ps1 `
    -PolicyFile "docs/policies/conditional-access-mfa-external.yaml" `
    -ReportOnly
```

---

### **Example 2: Deploy E5-Enhanced Policy**

```powershell
.\deploy-ca-policy.ps1 `
    -PolicyFile "docs/policies/conditional-access-mfa-external-e5-enhanced.yaml" `
    -ReportOnly
```

---

### **Example 3: Deploy Solo CPA Custom Policy**

```powershell
# Phase 1: Report-only (2 weeks)
.\deploy-ca-policy.ps1 `
    -PolicyFile "docs/policies/conditional-access-solo-cpa-custom.yaml" `
    -ReportOnly

# Phase 2: Enable for production (after testing)
.\deploy-ca-policy.ps1 `
    -PolicyFile "docs/policies/conditional-access-solo-cpa-custom.yaml" `
    -Force
```

---

### **Example 4: Update Existing Policy**

```powershell
# The script detects existing policies and prompts for update
.\deploy-ca-policy.ps1 `
    -PolicyFile "docs/policies/conditional-access-solo-cpa-custom.yaml" `
    -Force  # Skip confirmation
```

---

## 🔐 **Required Permissions**

### **Microsoft Graph Permissions:**

The script requires the following **delegated permissions**:

| Permission | Reason |
|------------|--------|
| `Policy.ReadWrite.ConditionalAccess` | Create/update CA policies |
| `Policy.Read.All` | Read existing policies |
| `Directory.Read.All` | Read user/group information |
| `Application.Read.All` | Read app registrations (optional) |

### **Azure AD Roles:**

You need **one of** these roles:

- **Global Administrator** (full access)
- **Conditional Access Administrator** (recommended for this task)
- **Security Administrator** (can manage CA policies)

---

## 🧪 **Testing Workflow**

### **Step 1: WhatIf Mode (No Changes)**

```powershell
.\deploy-ca-policy.ps1 `
    -PolicyFile "docs/policies/conditional-access-solo-cpa-custom.yaml" `
    -WhatIf
```

**✅ Safe:** No changes made, just previews what would happen

---

### **Step 2: Report-Only Mode (Logs Only)**

```powershell
.\deploy-ca-policy.ps1 `
    -PolicyFile "docs/policies/conditional-access-solo-cpa-custom.yaml" `
    -ReportOnly
```

**✅ Safe:** Policy created but not enforced (logs what would happen)

**Monitor for 1-2 weeks:**
- Go to: Entra admin center → Protection → Conditional Access → Insights
- Review: Which users/sign-ins would be affected
- Check: Any false positives or issues

---

### **Step 3: Enable Policy (Production)**

```powershell
# Update policy to enabled state
.\deploy-ca-policy.ps1 `
    -PolicyFile "docs/policies/conditional-access-solo-cpa-custom.yaml" `
    -Force
```

**⚠️ Warning:** This enforces the policy! Monitor closely for first week.

---

## 🛠️ **Troubleshooting**

### **Issue 1: "powershell-yaml not installed"**

```powershell
# Install the module
Install-Module -Name powershell-yaml -Scope CurrentUser -Force

# Or let the script install it for you (it will prompt)
```

---

### **Issue 2: "Insufficient permissions"**

```yaml
Error: "Insufficient privileges to complete the operation"

Solution:
1. Ensure you have Conditional Access Administrator role
2. Re-authenticate with correct permissions:
   Disconnect-MgGraph
   Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess", "Policy.Read.All"
3. Grant admin consent if prompted
```

---

### **Issue 3: "Policy already exists"**

```yaml
Behavior: Script detects existing policy with same name

Options:
1. Update existing policy (script prompts: "Update existing policy? (Y/N)")
2. Use -Force to skip prompt
3. Rename policy in YAML template (change display_name)
```

---

### **Issue 4: "YAML parsing failed"**

```yaml
Error: "Policy template missing 'name' field"

Solution:
1. Verify YAML syntax (no tabs, proper indentation)
2. Ensure 'name' and 'display_name' fields exist
3. Use online YAML validator: http://www.yamllint.com/
4. Check template examples in docs/policies/
```

---

## 📄 **Exported Policy JSON**

After successful deployment, the script exports the policy JSON:

```
deployed-policy-{policyId}-{timestamp}.json
```

**Example:**
```
deployed-policy-a1b2c3d4-1234-5678-9abc-def012345678-20250118-143022.json
```

**Use this for:**
- Version control (commit to Git)
- Audit trail
- Rollback (if needed)
- Documentation

---

## 🔄 **Rollback Procedure**

If you need to revert a policy deployment:

### **Option 1: Delete Policy**

```powershell
# Connect to Graph
Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess"

# Get policy ID
$policy = Get-MgIdentityConditionalAccessPolicy -Filter "displayName eq 'Solo CPA Firm - Client Collaboration & Accounting Software'"

# Delete policy
Remove-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -Confirm
```

---

### **Option 2: Disable Policy**

```powershell
# Set policy to disabled state
Update-MgIdentityConditionalAccessPolicy `
    -ConditionalAccessPolicyId $policy.Id `
    -State "disabled"
```

---

### **Option 3: Restore from JSON**

```powershell
# Read exported JSON
$policyJson = Get-Content "deployed-policy-{id}-{timestamp}.json" | ConvertFrom-Json

# Restore policy
Update-MgIdentityConditionalAccessPolicy `
    -ConditionalAccessPolicyId $policyJson.Id `
    -BodyParameter $policyJson
```

---

## 🎯 **Best Practices**

### **1. Always Test First**

```powershell
# ALWAYS run with -WhatIf first
.\deploy-ca-policy.ps1 -PolicyFile {file} -WhatIf

# THEN deploy in report-only mode
.\deploy-ca-policy.ps1 -PolicyFile {file} -ReportOnly

# FINALLY enable after 1-2 weeks of monitoring
.\deploy-ca-policy.ps1 -PolicyFile {file} -Force
```

---

### **2. Export and Version Control**

```powershell
# After deployment, commit exported JSON to Git
git add deployed-policy-*.json
git commit -m "feat: Deploy Solo CPA custom CA policy"
git push
```

---

### **3. Monitor After Deployment**

```yaml
Daily (first week):
  - Check sign-in logs for blocked users
  - Review CA insights for unexpected impacts

Weekly (first month):
  - Export CA policy JSON (version control)
  - Review MFA enrollment status
  - Check risk detections (Identity Protection)

Monthly (ongoing):
  - Full policy review
  - Update YAML template if needed
  - Re-deploy with script
```

---

### **4. Document Customizations**

```yaml
# In your YAML template, add metadata:
metadata:
  deployed_by: "hassan@yourtenant.onmicrosoft.com"
  deployed_date: "2025-01-18"
  last_modified: "2025-01-18"
  version: "1.0"
  notes: "Initial deployment for solo CPA firm"
```

---

## 📊 **Script Parameters Reference**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-PolicyFile` | String | Yes | Path to YAML policy template |
| `-TenantId` | String | No | Azure tenant ID (auto-detected) |
| `-WhatIf` | Switch | No | Preview changes without deploying |
| `-ReportOnly` | Switch | No | Deploy in report-only mode |
| `-Force` | Switch | No | Skip confirmation prompts |

---

## 🌟 **Advanced Usage**

### **Deploy Multiple Policies (Batch)**

```powershell
# Create a batch deployment script
$policies = @(
    "docs/policies/conditional-access-mfa-external.yaml",
    "docs/policies/conditional-access-solo-cpa-custom.yaml"
)

foreach ($policy in $policies) {
    Write-Host "Deploying $policy..." -ForegroundColor Cyan
    .\deploy-ca-policy.ps1 -PolicyFile $policy -ReportOnly -Force
    Start-Sleep -Seconds 5  # Avoid rate limiting
}
```

---

### **Scheduled Deployment (CI/CD)**

```yaml
# GitHub Actions workflow
name: Deploy CA Policies

on:
  push:
    branches: [master]
    paths: ['docs/policies/*.yaml']

jobs:
  deploy:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy policies
        shell: pwsh
        run: |
          .\deploy-ca-policy.ps1 `
            -PolicyFile "docs/policies/conditional-access-solo-cpa-custom.yaml" `
            -Force
        env:
          AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
```

---

## 📞 **Support**

| Issue | Resource |
|-------|----------|
| **Script errors** | Check error message, run with `-Verbose` |
| **Graph API issues** | [Graph API Docs](https://learn.microsoft.com/graph/api/conditionalaccesspolicy-post) |
| **YAML syntax** | [YAML Validator](http://www.yamllint.com/) |
| **CA policy help** | [Solo CPA Custom Policy Deployment](solo-cpa-custom-policy-deployment.md) |
| **General questions** | Open issue on GitHub |

---

## 🎉 **Summary**

```yaml
What You Can Do:
  ✅ Deploy CA policies from YAML templates
  ✅ Test safely with WhatIf mode
  ✅ Phased rollout with Report-Only mode
  ✅ Update existing policies
  ✅ Export policies for version control
  ✅ Rollback if needed

Time Saved:
  Manual Deployment: 30-45 minutes per policy
  Automated: <5 minutes per policy
  Savings: 25-40 minutes per policy
  
  For 3 policies: 75-120 minutes saved!
```

---

<p align="center">
  <strong>Automate Your CA Policy Deployments! 🚀</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell" alt="PowerShell">
  <img src="https://img.shields.io/badge/Microsoft_Graph-API-0078D4?logo=microsoft" alt="Graph API">
  <img src="https://img.shields.io/badge/Automation-Ready-success" alt="Ready">
</p>
