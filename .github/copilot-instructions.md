````instructions

# Copilot Instructions for compliance-governance-test

## Project Overview
- **Purpose**: Lean tech roadmap and testing framework for AI & compliance projects. Provides PowerShell-based automation for Azure policy deployment, M365 E5 configuration, cross-tenant collaboration, and compliance monitoring for CPA firm environments.
- **Primary Use Cases**: Conditional Access policy deployment, cost monitoring, cross-tenant identity synchronization, SOX/GDPR/HIPAA compliance testing, E5 feature optimization
- **Architecture**: PowerShell automation scripts + Azure policy templates + GitHub Actions CI/CD
- **Tech Stack**:
  - PowerShell 5.1+ for Azure/M365 automation
  - Azure CLI for resource management
  - Microsoft Graph PowerShell SDK for identity/policy operations
  - GitHub Actions for automated compliance audits
  - YAML-based policy templates for version control
- **Key Directories**:
  - `docs/`: Comprehensive guides (cross-tenant collaboration, E5 optimization, conditional access policies)
  - `docs/policies/`: YAML templates for Conditional Access policies (MFA, device compliance, risk-based)
  - `docs/cross-tenant-access/`: Partner tenant configuration templates
  - `docs/cross-tenant-sync/`: B2B user lifecycle automation
  - `.github/workflows/`: CI/CD pipelines and automated audit schedules
  - Root scripts: PowerShell automation for deployment and monitoring

## Architecture & Data Flow
- **Policy Deployment**: YAML templates → PowerShell scripts → Azure Conditional Access → Validation → Documentation
- **Cost Monitoring**: `monitor-azure-costs.ps1` → Azure Cost Management API → Alert thresholds → Email notifications
- **Cross-Tenant Setup**: Partner config → B2B invitations → Identity sync → Access policies → Audit logs
- **Compliance Testing**: Policy templates → Deployment scripts → Validation checks → Compliance mapping → Reports

## Key Scripts & Usage

### **Cost Monitoring** (`monitor-azure-costs.ps1`)
```powershell
# Run weekly cost analysis
.\monitor-azure-costs.ps1 -Verbose

# Export detailed report
.\monitor-azure-costs.ps1 -ExportReport

# Set up email alerts
.\monitor-azure-costs.ps1 -AlertEmail "your-email@example.com"
```

### **Conditional Access Deployment** (`deploy-ca-policy.ps1`)
```powershell
# Deploy MFA policy for external users
.\deploy-ca-policy.ps1 -PolicyFile "docs/policies/conditional-access-mfa-external.yaml"

# Deploy E5-enhanced risk-based policy
.\deploy-ca-policy.ps1 -PolicyFile "docs/policies/conditional-access-mfa-external-e5-enhanced.yaml"

# Deploy custom solo CPA policy (includes QuickBooks/D365 integration)
.\deploy-ca-policy.ps1 -PolicyFile "docs/policies/conditional-access-solo-cpa-custom.yaml"

# Test mode (validate without deploying)
.\deploy-ca-policy.ps1 -PolicyFile "policy.yaml" -WhatIf
```

### **E5 Tenant Validation** (`validate-cpa-tenant-e5.ps1`)
```powershell
# Validate M365 E5 license assignments and features
.\validate-cpa-tenant-e5.ps1

# Export validation report
.\validate-cpa-tenant-e5.ps1 -ExportReport
```

### **Remote Desktop via Key Vault** (`connect-rdp-keyvault.ps1`)
```powershell
# Connect to VM using credentials from Azure Key Vault
.\connect-rdp-keyvault.ps1 -VaultName "cpa-keyvault" -VMName "audit-workstation"
```

### **GitHub Remote Setup** (`setup-github-remote.ps1`)
```powershell
# Configure GitHub remote for repository
.\setup-github-remote.ps1 -RepoUrl "https://github.com/Heyson315/compliance-governance-test.git"
```

### **Workspace Health Check** (`workspace-health-check.ps1`)
```powershell
# Run comprehensive workspace health validation
.\workspace-health-check.ps1 -Verbose
```

## Conditional Access Policy Templates

### **Available Policies** (in `docs/policies/`)
1. **`conditional-access-mfa-external.yaml`** - Basic MFA enforcement for external/guest users
2. **`conditional-access-mfa-external-e5-enhanced.yaml`** - Risk-based CA with device compliance (requires E5)
3. **`conditional-access-solo-cpa-custom.yaml`** - Custom policy for solo CPA firms (includes QuickBooks, Dynamics 365 integration)

### **Policy Structure** (YAML format)
```yaml
displayName: "Policy Name"
state: "enabledForReportingButNotEnforced"  # or "enabled"
conditions:
  users:
    includeUsers: ["All"]
    excludeGroups: ["Emergency-Access-Group"]
  applications:
    includeApplications: ["All"]
  locations:
    includeLocations: ["All"]
    excludeLocations: ["AllTrusted"]
grantControls:
  operator: "OR"
  builtInControls: ["mfa"]
```

### **Deployment Best Practices**
- Always test in report-only mode first: `state: "enabledForReportingButNotEnforced"`
- Exclude emergency access accounts: `excludeGroups: ["Emergency-Access-Group"]`
- Use `deploy-ca-policy.ps1` for validation before applying to production
- Document all policy changes in COMPLIANCE-MAPPING.md
- Monitor Conditional Access logs in Azure AD for 7 days before full enforcement

## Cross-Tenant Collaboration

### **Setup Workflow**
1. **Configure Trust Settings** (`docs/cross-tenant-access/partner-tenant-config.yaml`)
   - Define partner tenant relationships
   - Set B2B collaboration policies
   - Configure MFA trust settings

2. **Enable Identity Sync** (`docs/cross-tenant-sync/source-to-target.yaml`)
   - Automate B2B user provisioning
   - Sync user attributes
   - Manage lifecycle (create/update/delete)

3. **Apply Access Policies**
   - Deploy Conditional Access for external users
   - Enforce MFA for partner access
   - Monitor sign-in logs

### **Key Documentation**
- **[Cross-Tenant Collaboration Guide](docs/cross-tenant-collab.md)** - Complete setup instructions
- **[E5 Optimization Guide](docs/e5-optimization-guide.md)** - Maximize E5 features for multi-tenant scenarios
- **[Solo CPA Testing Guide](docs/solo-cpa-testing-guide.md)** - Testing playground for CPA practitioners

## Compliance Mapping

### **Supported Standards** (`COMPLIANCE-MAPPING.md`)
- **SOX** (Sarbanes-Oxley): Audit controls, financial data protection, access logging
- **GDPR**: Data protection, privacy controls, data residency, breach notification
- **HIPAA**: Healthcare data protection (if applicable to CPA clients)
- **NIST**: Cybersecurity framework alignment
- **AICPA**: CPA-specific audit standards and data security requirements

### **Compliance Documentation Pattern**
For each policy/control, document:
1. **Standard Requirement** - What the regulation requires
2. **Azure Implementation** - How it's implemented (CA policy, DLP, encryption)
3. **Audit Evidence** - How to prove compliance (logs, reports, screenshots)
4. **Testing Procedure** - How to validate the control
5. **Responsible Party** - Who maintains the control

## Project Conventions

### **PowerShell Scripts**
- Use approved verbs: `New-`, `Set-`, `Get-`, `Deploy-`, `Validate-`, `Test-`, `Connect-`, `Invoke-`
- Always support `-WhatIf` for destructive operations (use `[CmdletBinding(SupportsShouldProcess)]`)
- Return structured objects (PSCustomObject) not strings for pipeline compatibility
- Log to both console and file for audit trail
- Handle errors gracefully with try/catch and informative messages
- Support `-Verbose` for detailed output (use `Write-Verbose` not `Write-Host` for verbose messages)
- Color-coded output: Green (✅ success), Red (❌ error), Yellow (⚠️ warning), Cyan (🔍 info)
- Always validate prerequisites: Check module availability before Import-Module (example in validate-cpa-tenant-e5.ps1)
- Script parameters should validate: Use `[ValidateScript({ Test-Path $_ })]` for file paths
- Always include comprehensive comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`, `.NOTES`)

### **YAML Policy Templates**
- Use consistent naming: `conditional-access-<purpose>-<variant>.yaml`
- Always include comments explaining each section
- Provide both report-only and enforced versions
- Document required licenses (E3, E5, etc.)
- Include deployment instructions in file header
- **Structure pattern** (see conditional-access-mfa-external-e5-enhanced.yaml):
  ```yaml
  name: CA-Policy-Short-Name
  display_name: "Human Readable Policy Name"
  description: |
    Multi-line description with:
    - Feature list
    - License requirements
  state: enabledForReportingButNotEnforced  # CRITICAL: Test in report mode first!
  assignments:
    users:
      include: [GuestsOrExternalUsers]
      exclude: [emergency_access_accounts]  # ALWAYS exclude break-glass
    cloud_apps:
      include: [app-guids]  # Use GUIDs not names for stability
  conditions:
    sign_in_risk_levels: [high, medium]  # E5 feature
    user_risk_levels: [high]             # E5 feature
  grant_controls:
    operator: AND  # Require ALL conditions
    built_in_controls: [mfa, compliantDevice]
  session_controls:
    sign_in_frequency:
      value: 4
      type: hours
  ```
- **App GUIDs reference** (commonly used):
  - SharePoint: `00000003-0000-0ff1-ce00-000000000000`
  - Teams: `cc15fd57-2c6c-4117-a88c-83b1d56b4bbe`
  - Exchange: `00000002-0000-0ff1-ce00-000000000000`
- **CRITICAL**: Never commit policies with `state: enabled` without testing in report mode first

### **GitHub Actions Workflows**
- Schedule compliance audits: Monthly on 1st day
- Run security scans on every PR
- Validate YAML syntax before deployment
- Store secrets in GitHub Secrets (never commit credentials)
- Send notifications to Teams/Slack on failures
- **Workflow structure** (see `.github/workflows/ci.yml`):
  - Use Ubuntu runners for YAML/security validation
  - Use Windows runners for PowerShell script validation
  - Always include `continue-on-error: true` for non-blocking warnings (yamllint relaxed mode)
  - Use PSScriptAnalyzer for PowerShell linting: `Invoke-ScriptAnalyzer -Path $script.FullName -Severity Warning`
  - Security scanning: Trivy for filesystem, TruffleHog for secrets
  - Generate GITHUB_STEP_SUMMARY for CI results visibility

### **Documentation Standards**
- Use Markdown for all documentation
- Include mermaid diagrams for complex workflows
- Provide both CLI commands and Azure Portal steps
- Link to official Microsoft documentation
- Keep README.md updated with current status

## Microsoft 365 E5 Features

### **Conditional Access**
- Risk-based authentication (Identity Protection)
- Device compliance enforcement (Intune integration)
- Session controls (Cloud App Security)
- Authentication context for sensitive apps

### **Identity Protection**
- Sign-in risk detection
- User risk detection
- Automated remediation (force password reset, block access)
- Risk-based Conditional Access

### **Privileged Identity Management (PIM)**
- Just-in-time admin access
- Time-bound role assignments
- Approval workflows for privileged roles
- Access reviews

### **Azure Defender for IoT**
- Device monitoring and alerts
- Commitment-based pricing tiers

## Azure Cost Management

### **Monitoring Strategy**
- Run `monitor-azure-costs.ps1` weekly
- Set budget alerts at 80% and 100% thresholds
- Tag resources by project/client for cost allocation
- Review Cost Analysis dashboard monthly
- Optimize pay-as-you-go to reserved instances for stable workloads
- **Cost phases** (from PROJECT-STATUS.md):
  - Phase 1 (current): $0-10/month target, currently $0/month ✅
  - Phase 2: $10-50/month (not started)
  - Phase 3: $50-150/month (not started)
- **Alert configuration**:
  ```powershell
  # Phase 1 thresholds
  WARNING at $5/month
  CRITICAL at $10/month
  # Script supports email alerts: -AlertEmail "your-email@example.com"
  ```

### **Cost Optimization Tips**
- Use Azure Hybrid Benefit for Windows licenses
- Right-size VMs based on actual usage
- Shut down non-production VMs during off-hours
- Use spot instances for batch processing
- Archive old storage to Cool/Archive tiers

## GitHub Actions CI/CD

### **Automated Workflows** (`.github/workflows/`)
- **CI/CD Pipeline** - Runs on every commit (syntax validation, security scans)
- **Monthly Security Audit** - Scheduled compliance checks
- **CodeQL Analysis** - Code security scanning
- **Dependency Review** - Vulnerability scanning for dependencies
- **Dependabot** - Automated dependency updates

### **Adding New Workflows**
1. Create YAML file in `.github/workflows/`
2. Define trigger (push, PR, schedule)
3. Set up authentication (use GitHub Secrets)
4. Run validation/deployment steps
5. Send notifications on completion/failure

## Development Workflow

### **Setup**
```powershell
# Clone repository
git clone https://github.com/Heyson315/compliance-governance-test.git
cd compliance-governance-test

# Install required PowerShell modules
Install-Module -Name Az -Scope CurrentUser
Install-Module -Name Microsoft.Graph -Scope CurrentUser

# Authenticate to Azure
Connect-AzAccount

# Authenticate to Microsoft Graph
Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess", "Directory.ReadWrite.All"
```

### **Testing Policies**
1. Create/modify YAML policy template
2. Validate syntax: `.\deploy-ca-policy.ps1 -PolicyFile policy.yaml -WhatIf`
3. Deploy in report-only mode
4. Monitor Conditional Access logs for 7 days
5. Switch to enforced mode if no issues
6. Document in COMPLIANCE-MAPPING.md

### **Troubleshooting**
- **Authentication Failures**: Check `Connect-AzAccount` and `Connect-MgGraph` scopes
- **Policy Deployment Errors**: Verify YAML syntax and required licenses (E5 features)
- **Cost Monitoring Issues**: Ensure Cost Management API permissions are granted
- **Cross-Tenant Sync**: Validate partner tenant trust settings and B2B policies

### **Common Error Patterns & Solutions**
- **YAML Indentation**: Use spaces only (no tabs). Validate with `yamllint -d relaxed file.yaml`
- **Missing Modules**: Scripts check prerequisites before import. Example pattern:
  ```powershell
  if (!(Get-Module -ListAvailable -Name Microsoft.Graph)) {
      Write-Host "Module Microsoft.Graph not found. Installing..." -ForegroundColor Yellow
      Install-Module -Name Microsoft.Graph -Force -Scope CurrentUser
  }
  ```
- **Policy GUID Placeholders**: Replace `emergency_access_accounts`, `external_collaboration_terms_guid` with actual GUIDs from your tenant
- **Report-Only Testing**: Always deploy with `state: enabledForReportingButNotEnforced` first, monitor for 7 days
- **Break-Glass Accounts**: NEVER include in CA policy scope - use exclude lists to prevent lockout
- **PowerShell Execution Policy**: Scripts support both `pwsh` (PowerShell 7+) and `powershell.exe` (Windows PowerShell 5.1)

### **Testing Workflow** (DO NOT SKIP)
1. Validate YAML syntax locally: `yamllint -d relaxed docs/policies/your-policy.yaml`
2. Test deployment with `-WhatIf`: `.\deploy-ca-policy.ps1 -PolicyFile policy.yaml -WhatIf`
3. Deploy in report-only mode: Edit YAML `state: enabledForReportingButNotEnforced`
4. Monitor Conditional Access logs for 7 days in Azure Portal
5. Switch to enforced mode ONLY after validation: `state: enabled`
6. Document changes in COMPLIANCE-MAPPING.md with control mapping

## Integration Points

### **External Services**
- **QuickBooks Online**: Policy templates include app-specific conditional access
- **Dynamics 365**: Custom CA policies for D365 finance/operations apps
- **SharePoint Online**: Document-based collaboration policies
- **Microsoft Teams**: External collaboration policies and guest access controls

### **Monitoring & Alerts**
- **Azure Monitor**: Cost alerts, policy compliance, sign-in anomalies
- **Microsoft Sentinel**: SIEM integration for advanced threat detection
- **Teams/Slack**: Notification webhooks for policy violations and cost overruns

## Lean Tech Principles

### **Phase 1: Quick Wins (0-3 months)**
- ✅ CI/CD with GitHub Actions
- ✅ MFA and DLP in Microsoft 365
- ✅ Pay-as-you-go cloud tiers
- 🔄 Compliance templates (SOX, GDPR, HIPAA)

### **Phase 2: Incremental Automation (3-6 months)**
- 📋 Finance automation (QuickBooks API integration)
- 📋 SharePoint-based document control
- 📋 Built-in Microsoft 365 security features

### **Phase 3: Scale Gradually (6-12 months)**
- 📋 Power Apps for low-code workflows
- 📋 AI pilots (summarization for audits)

### **Phase 4: Future Expansion**
- 🔮 GitHub Marketplace app listing
- 🔮 Agentic AI and cloud upgrades

## Documentation & Support

- **Quick Reference**: See `README.md` for visual roadmap and getting started
- **Project Status**: See `PROJECT-STATUS.md` for current phase, costs, and milestones
- **Compliance**: See `COMPLIANCE-MAPPING.md` for SOX/GDPR/HIPAA mapping
- **E5 Optimization**: See `docs/e5-optimization-guide.md` for license feature usage
- **Cross-Tenant**: See `docs/cross-tenant-collab.md` for multi-tenant scenarios
- **Support**: Open GitHub issue or contact via repository

For questions or unclear conventions, see README.md and docs/, or open an issue.

````
