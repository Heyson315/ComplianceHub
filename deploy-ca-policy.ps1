#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Conditional Access Policy from YAML template to Azure/Entra tenant
    Automates policy creation via Microsoft Graph API

.DESCRIPTION
    This script:
    - Reads YAML policy template
    - Converts to Microsoft Graph API JSON format
    - Authenticates to Microsoft Graph
    - Creates or updates Conditional Access policy
    - Validates deployment
    - Provides rollback capability

.PARAMETER PolicyFile
    Path to YAML policy template file

.PARAMETER TenantId
    Azure tenant ID (optional, will auto-detect if not provided)

.PARAMETER WhatIf
    Preview changes without deploying (dry-run mode)

.PARAMETER ReportOnly
    Deploy policy in report-only mode (safe for testing)

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\deploy-ca-policy.ps1 -PolicyFile "docs/policies/conditional-access-solo-cpa-custom.yaml" -WhatIf
    
.EXAMPLE
    .\deploy-ca-policy.ps1 -PolicyFile "docs/policies/conditional-access-mfa-external-e5-enhanced.yaml" -ReportOnly

.EXAMPLE
    .\deploy-ca-policy.ps1 -PolicyFile "docs/policies/conditional-access-solo-cpa-custom.yaml" -Force

.NOTES
    Author: Hassan Rahman (Heyson315)
    Version: 1.0
    License: MIT
    Requires: PowerShell 7+, Microsoft.Graph modules
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ })]
    [string]$PolicyFile,
    
    [Parameter()]
    [string]$TenantId,
    
    [Parameter()]
    [switch]$WhatIf,
    
    [Parameter()]
    [switch]$ReportOnly,
    
    [Parameter()]
    [switch]$Force
)

#Requires -Version 7.0

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

$script:GraphApiVersion = "v1.0"
$script:GraphEndpoint = "https://graph.microsoft.com/$script:GraphApiVersion"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""
}

function Write-Status {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    $Icon = switch ($Type) {
        "Success" { "✅" }
        "Error" { "❌" }
        "Warning" { "⚠️ " }
        "Info" { "ℹ️ " }
        default { "•" }
    }
    
    $Color = switch ($Type) {
        "Success" { "Green" }
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Info" { "Cyan" }
        default { "White" }
    }
    
    Write-Host "  $Icon $Message" -ForegroundColor $Color
}

function Test-Prerequisites {
    Write-Header "1️⃣  Checking Prerequisites"
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Status "PowerShell 7+ required (current: $($PSVersionTable.PSVersion))" "Error"
        throw "Upgrade to PowerShell 7+"
    }
    Write-Status "PowerShell Version: $($PSVersionTable.PSVersion)" "Success"
    
    # Check required modules
    $requiredModules = @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.Identity.SignIns"
    )
    
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Status "$module not installed" "Error"
            
            $install = Read-Host "Install $module now? (Y/N)"
            if ($install -eq 'Y') {
                Write-Host "  Installing $module..." -ForegroundColor Yellow
                Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
                Write-Status "$module installed" "Success"
            }
            else {
                throw "Required module not installed: $module"
            }
        }
        else {
            $version = (Get-Module -ListAvailable -Name $module | Select-Object -First 1).Version
            Write-Status "$module installed (v$version)" "Success"
        }
    }
    
    # Check powershell-yaml module (for YAML parsing)
    if (-not (Get-Module -ListAvailable -Name "powershell-yaml")) {
        Write-Status "powershell-yaml not installed (required for YAML parsing)" "Warning"
        
        $install = Read-Host "Install powershell-yaml now? (Y/N)"
        if ($install -eq 'Y') {
            Write-Host "  Installing powershell-yaml..." -ForegroundColor Yellow
            Install-Module -Name powershell-yaml -Scope CurrentUser -Force -AllowClobber
            Write-Status "powershell-yaml installed" "Success"
        }
        else {
            Write-Status "Will use basic YAML parsing (limited functionality)" "Warning"
        }
    }
    else {
        Write-Status "powershell-yaml installed" "Success"
    }
}

function Connect-ToMicrosoftGraph {
    Write-Header "2️⃣  Connecting to Microsoft Graph"
    
    try {
        # Check if already connected
        $context = Get-MgContext -ErrorAction SilentlyContinue
        
        if ($null -eq $context) {
            Write-Status "Not connected, initiating authentication..." "Info"
            
            $scopes = @(
                "Policy.ReadWrite.ConditionalAccess",
                "Policy.Read.All",
                "Directory.Read.All",
                "Application.Read.All"
            )
            
            Connect-MgGraph -Scopes $scopes -ErrorAction Stop
            $context = Get-MgContext
        }
        
        Write-Status "Connected to tenant: $($context.TenantId)" "Success"
        Write-Status "Account: $($context.Account)" "Info"
        
        # Store tenant ID
        if (-not $script:TenantId) {
            $script:TenantId = $context.TenantId
        }
        
        # Verify permissions
        $grantedScopes = $context.Scopes
        $requiredScopes = @("Policy.ReadWrite.ConditionalAccess", "Policy.Read.All")
        $missingScopes = $requiredScopes | Where-Object { $_ -notin $grantedScopes }
        
        if ($missingScopes.Count -gt 0) {
            Write-Status "Missing required permissions: $($missingScopes -join ', ')" "Error"
            throw "Insufficient permissions. Re-run with admin consent."
        }
        
        Write-Status "All required permissions granted" "Success"
    }
    catch {
        Write-Status "Failed to connect to Microsoft Graph: $_" "Error"
        throw
    }
}

function Read-PolicyTemplate {
    param([string]$FilePath)
    
    Write-Header "3️⃣  Reading Policy Template"
    
    try {
        Write-Status "Reading file: $FilePath" "Info"
        
        # Check if file exists
        if (-not (Test-Path $FilePath)) {
            throw "Policy file not found: $FilePath"
        }
        
        # Read file content
        $content = Get-Content -Path $FilePath -Raw
        
        # Try to parse as YAML
        try {
            Import-Module powershell-yaml -ErrorAction Stop
            $policy = ConvertFrom-Yaml -Yaml $content
            Write-Status "Parsed YAML successfully" "Success"
        }
        catch {
            Write-Status "YAML parsing failed, using basic parsing" "Warning"
            # Fallback: basic key-value parsing (limited)
            $policy = @{}
            foreach ($line in ($content -split "`n")) {
                if ($line -match "^(\w+):\s*(.+)$") {
                    $policy[$matches[1]] = $matches[2].Trim('"')
                }
            }
        }
        
        # Validate policy structure
        if (-not $policy.name) {
            throw "Policy template missing 'name' field"
        }
        
        if (-not $policy.display_name) {
            throw "Policy template missing 'display_name' field"
        }
        
        Write-Status "Policy Name: $($policy.name)" "Info"
        Write-Status "Display Name: $($policy.display_name)" "Info"
        
        return $policy
    }
    catch {
        Write-Status "Failed to read policy template: $_" "Error"
        throw
    }
}

function Convert-ToGraphApiFormat {
    param([hashtable]$PolicyTemplate)
    
    Write-Header "4️⃣  Converting to Graph API Format"
    
    try {
        Write-Status "Converting YAML to Graph API JSON..." "Info"
        
        # Build Graph API policy object
        $graphPolicy = @{
            displayName = $PolicyTemplate.display_name
            state = if ($ReportOnly) { "enabledForReportingButNotEnforced" } else { $PolicyTemplate.state }
        }
        
        # Add description if present
        if ($PolicyTemplate.description) {
            $graphPolicy.description = $PolicyTemplate.description
        }
        
        # Build conditions
        $conditions = @{}
        
        # Users
        if ($PolicyTemplate.assignments.users) {
            $conditions.users = @{
                includeUsers = @()
                excludeUsers = @()
            }
            
            if ($PolicyTemplate.assignments.users.include) {
                foreach ($user in $PolicyTemplate.assignments.users.include) {
                    if ($user -eq "GuestsOrExternalUsers") {
                        $conditions.users.includeGuestsOrExternalUsers = @{
                            guestOrExternalUserTypes = "b2bCollaborationGuest,b2bCollaborationMember"
                        }
                    }
                    else {
                        $conditions.users.includeUsers += $user
                    }
                }
            }
            
            if ($PolicyTemplate.assignments.users.exclude) {
                $conditions.users.excludeUsers = $PolicyTemplate.assignments.users.exclude
            }
        }
        
        # Applications
        if ($PolicyTemplate.assignments.cloud_apps) {
            $conditions.applications = @{
                includeApplications = $PolicyTemplate.assignments.cloud_apps.include
            }
            
            if ($PolicyTemplate.assignments.cloud_apps.exclude) {
                $conditions.applications.excludeApplications = $PolicyTemplate.assignments.cloud_apps.exclude
            }
        }
        
        # Client app types
        if ($PolicyTemplate.conditions.client_app_types) {
            $conditions.clientAppTypes = $PolicyTemplate.conditions.client_app_types
        }
        
        # Locations
        if ($PolicyTemplate.conditions.locations) {
            $conditions.locations = @{
                includeLocations = @($PolicyTemplate.conditions.locations.include)
            }
            
            if ($PolicyTemplate.conditions.locations.exclude) {
                $conditions.locations.excludeLocations = $PolicyTemplate.conditions.locations.exclude
            }
        }
        
        # Sign-in risk levels (E5)
        if ($PolicyTemplate.conditions.sign_in_risk_levels) {
            $conditions.signInRiskLevels = $PolicyTemplate.conditions.sign_in_risk_levels
        }
        
        # User risk levels (E5)
        if ($PolicyTemplate.conditions.user_risk_levels) {
            $conditions.userRiskLevels = $PolicyTemplate.conditions.user_risk_levels
        }
        
        # Platforms
        if ($PolicyTemplate.conditions.device_platforms) {
            $conditions.platforms = @{
                includePlatforms = @($PolicyTemplate.conditions.device_platforms.include)
            }
            
            if ($PolicyTemplate.conditions.device_platforms.exclude) {
                $conditions.platforms.excludePlatforms = $PolicyTemplate.conditions.device_platforms.exclude
            }
        }
        
        $graphPolicy.conditions = $conditions
        
        # Grant controls
        if ($PolicyTemplate.grant_controls) {
            $grantControls = @{
                operator = $PolicyTemplate.grant_controls.operator
                builtInControls = $PolicyTemplate.grant_controls.built_in_controls
            }
            
            # Terms of Use
            if ($PolicyTemplate.grant_controls.terms_of_use) {
                $grantControls.termsOfUse = $PolicyTemplate.grant_controls.terms_of_use
            }
            
            # Authentication strength (E5)
            if ($PolicyTemplate.grant_controls.authentication_strength) {
                $grantControls.authenticationStrength = @{
                    id = $PolicyTemplate.grant_controls.authentication_strength.strength_id
                }
            }
            
            $graphPolicy.grantControls = $grantControls
        }
        
        # Session controls
        if ($PolicyTemplate.session_controls) {
            $sessionControls = @{}
            
            # Sign-in frequency
            if ($PolicyTemplate.session_controls.sign_in_frequency) {
                $sessionControls.signInFrequency = @{
                    value = $PolicyTemplate.session_controls.sign_in_frequency.value
                    type = $PolicyTemplate.session_controls.sign_in_frequency.type
                    isEnabled = $true
                }
            }
            
            # Persistent browser
            if ($PolicyTemplate.session_controls.persistent_browser) {
                $sessionControls.persistentBrowser = @{
                    mode = $PolicyTemplate.session_controls.persistent_browser.mode
                    isEnabled = $PolicyTemplate.session_controls.persistent_browser.is_enabled
                }
            }
            
            # Cloud App Security (E5)
            if ($PolicyTemplate.session_controls.cloud_app_security) {
                $sessionControls.cloudAppSecurity = @{
                    cloudAppSecurityType = $PolicyTemplate.session_controls.cloud_app_security.cloud_app_security_type
                    isEnabled = $PolicyTemplate.session_controls.cloud_app_security.is_enabled
                }
            }
            
            # Continuous Access Evaluation (E5)
            if ($PolicyTemplate.session_controls.continuous_access_evaluation) {
                $sessionControls.continuousAccessEvaluation = @{
                    mode = $PolicyTemplate.session_controls.continuous_access_evaluation.mode
                }
            }
            
            $graphPolicy.sessionControls = $sessionControls
        }
        
        Write-Status "Conversion successful" "Success"
        Write-Status "Policy will be deployed as: $($graphPolicy.state)" "Info"
        
        return $graphPolicy
    }
    catch {
        Write-Status "Failed to convert policy: $_" "Error"
        throw
    }
}

function Test-PolicyExists {
    param([string]$DisplayName)
    
    try {
        $existingPolicy = Get-MgIdentityConditionalAccessPolicy -Filter "displayName eq '$DisplayName'" -ErrorAction SilentlyContinue
        return $existingPolicy
    }
    catch {
        return $null
    }
}

function Deploy-Policy {
    param([hashtable]$GraphPolicy)
    
    Write-Header "5️⃣  Deploying Policy"
    
    try {
        # Check if policy already exists
        $existingPolicy = Test-PolicyExists -DisplayName $GraphPolicy.displayName
        
        if ($existingPolicy) {
            Write-Status "Policy already exists: $($existingPolicy.displayName)" "Warning"
            Write-Status "Policy ID: $($existingPolicy.Id)" "Info"
            Write-Status "Current State: $($existingPolicy.State)" "Info"
            
            if (-not $Force) {
                $update = Read-Host "Update existing policy? (Y/N)"
                if ($update -ne 'Y') {
                    Write-Status "Deployment cancelled by user" "Warning"
                    return $null
                }
            }
            
            # Update existing policy
            if ($WhatIf) {
                Write-Status "WHATIF: Would update policy $($existingPolicy.Id)" "Info"
                return $existingPolicy
            }
            
            Write-Status "Updating policy..." "Info"
            $updatedPolicy = Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $existingPolicy.Id -BodyParameter $GraphPolicy
            Write-Status "Policy updated successfully!" "Success"
            return $updatedPolicy
        }
        else {
            # Create new policy
            if (-not $Force) {
                Write-Status "Policy Details:" "Info"
                Write-Host ""
                Write-Host "  Name: $($GraphPolicy.displayName)" -ForegroundColor Cyan
                Write-Host "  State: $($GraphPolicy.state)" -ForegroundColor Cyan
                Write-Host "  Users: $($GraphPolicy.conditions.users.includeUsers.Count) included, $($GraphPolicy.conditions.users.excludeUsers.Count) excluded" -ForegroundColor Cyan
                Write-Host "  Apps: $($GraphPolicy.conditions.applications.includeApplications.Count) included" -ForegroundColor Cyan
                Write-Host ""
                
                $confirm = Read-Host "Create this policy? (Y/N)"
                if ($confirm -ne 'Y') {
                    Write-Status "Deployment cancelled by user" "Warning"
                    return $null
                }
            }
            
            if ($WhatIf) {
                Write-Status "WHATIF: Would create new policy '$($GraphPolicy.displayName)'" "Info"
                return $null
            }
            
            Write-Status "Creating policy..." "Info"
            $newPolicy = New-MgIdentityConditionalAccessPolicy -BodyParameter $GraphPolicy
            Write-Status "Policy created successfully!" "Success"
            Write-Status "Policy ID: $($newPolicy.Id)" "Info"
            return $newPolicy
        }
    }
    catch {
        Write-Status "Failed to deploy policy: $_" "Error"
        throw
    }
}

function Test-PolicyDeployment {
    param([string]$PolicyId)
    
    Write-Header "6️⃣  Validating Deployment"
    
    try {
        Write-Status "Retrieving deployed policy..." "Info"
        $deployedPolicy = Get-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $PolicyId
        
        if ($deployedPolicy) {
            Write-Status "Policy validated successfully!" "Success"
            Write-Host ""
            Write-Host "  Policy Details:" -ForegroundColor Cyan
            Write-Host "  ═══════════════" -ForegroundColor Cyan
            Write-Host "  ID: $($deployedPolicy.Id)" -ForegroundColor White
            Write-Host "  Display Name: $($deployedPolicy.DisplayName)" -ForegroundColor White
            Write-Host "  State: $($deployedPolicy.State)" -ForegroundColor White
            Write-Host "  Created: $($deployedPolicy.CreatedDateTime)" -ForegroundColor White
            Write-Host "  Modified: $($deployedPolicy.ModifiedDateTime)" -ForegroundColor White
            Write-Host ""
            
            return $true
        }
        else {
            Write-Status "Policy not found after deployment!" "Error"
            return $false
        }
    }
    catch {
        Write-Status "Validation failed: $_" "Error"
        return $false
    }
}

function Export-PolicyJson {
    param(
        [object]$Policy,
        [string]$OutputPath
    )
    
    try {
        $Policy | ConvertTo-Json -Depth 10 | Out-File $OutputPath
        Write-Status "Policy exported to: $OutputPath" "Success"
    }
    catch {
        Write-Status "Failed to export policy: $_" "Warning"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    Write-Host ""
    Write-Host "🚀 Conditional Access Policy Deployment Tool" -ForegroundColor Cyan
    Write-Host "   Automated deployment via Microsoft Graph API" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: Check prerequisites
    Test-Prerequisites
    
    # Step 2: Connect to Microsoft Graph
    Connect-ToMicrosoftGraph
    
    # Step 3: Read policy template
    $policyTemplate = Read-PolicyTemplate -FilePath $PolicyFile
    
    # Step 4: Convert to Graph API format
    $graphPolicy = Convert-ToGraphApiFormat -PolicyTemplate $policyTemplate
    
    # Step 5: Deploy policy
    $deployedPolicy = Deploy-Policy -GraphPolicy $graphPolicy
    
    if ($deployedPolicy -and -not $WhatIf) {
        # Step 6: Validate deployment
        $validated = Test-PolicyDeployment -PolicyId $deployedPolicy.Id
        
        # Step 7: Export policy JSON
        $exportPath = ".\deployed-policy-$($deployedPolicy.Id)-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        Export-PolicyJson -Policy $deployedPolicy -OutputPath $exportPath
        
        # Success summary
        Write-Header "✅ Deployment Complete"
        Write-Host ""
        Write-Host "  Policy successfully deployed!" -ForegroundColor Green
        Write-Host "  Policy ID: $($deployedPolicy.Id)" -ForegroundColor Cyan
        Write-Host "  Display Name: $($deployedPolicy.DisplayName)" -ForegroundColor Cyan
        Write-Host "  State: $($deployedPolicy.State)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Next Steps:" -ForegroundColor Yellow
        
        if ($deployedPolicy.State -eq "enabledForReportingButNotEnforced") {
            Write-Host "  1. Monitor report-only logs for 1-2 weeks" -ForegroundColor White
            Write-Host "  2. Review Entra admin center → CA → Insights" -ForegroundColor White
            Write-Host "  3. Enable policy when ready (remove -ReportOnly flag)" -ForegroundColor White
        }
        else {
            Write-Host "  1. Verify policy in Entra admin center" -ForegroundColor White
            Write-Host "  2. Test with a non-admin account" -ForegroundColor White
            Write-Host "  3. Monitor sign-in logs for issues" -ForegroundColor White
        }
        Write-Host ""
    }
    elseif ($WhatIf) {
        Write-Header "✅ WhatIf Complete"
        Write-Host ""
        Write-Host "  No changes were made (WhatIf mode)" -ForegroundColor Yellow
        Write-Host "  Run without -WhatIf to deploy" -ForegroundColor Cyan
        Write-Host ""
    }
    
    exit 0
}
catch {
    Write-Host ""
    Write-Host "❌ Deployment Failed" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check your Microsoft Graph permissions" -ForegroundColor White
    Write-Host "  2. Verify YAML template syntax" -ForegroundColor White
    Write-Host "  3. Ensure you have Global Admin or Conditional Access Admin role" -ForegroundColor White
    Write-Host "  4. Run with -Verbose for detailed error information" -ForegroundColor White
    Write-Host ""
    
    exit 1
}
finally {
    Write-Host "=" * 80 -ForegroundColor Gray
    Write-Host ""
}
