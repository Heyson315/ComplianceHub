#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Azure Tenant E5 Validation Checklist for CPA Firm (Solo Practitioner)
    Includes QuickBooks, Dynamics 365, and accounting software integrations

.DESCRIPTION
    Comprehensive validation script for:
    - Microsoft 365 E5 tenant prerequisites
    - Cross-tenant collaboration readiness
    - QuickBooks Online API integration
    - Dynamics 365 Business Central compatibility
    - Other accounting software (Xero, Bill.com, etc.)
    - CPA firm specific compliance checks
    - Subscription cost analysis and credit tracking

.PARAMETER TenantId
    Your Azure tenant ID (optional, will auto-detect if not provided)

.PARAMETER IncludeQuickBooks
    Validate QuickBooks Online API prerequisites

.PARAMETER IncludeDynamics365
    Validate Dynamics 365 Business Central integration

.PARAMETER IncludeThirdPartyApps
    Check other accounting software integrations

.PARAMETER IncludeCostAnalysis
    Include detailed cost analysis and Azure credit check

.EXAMPLE
    .\validate-cpa-tenant-e5.ps1
    
.EXAMPLE
    .\validate-cpa-tenant-e5.ps1 -IncludeQuickBooks -IncludeDynamics365 -IncludeCostAnalysis -Verbose

.NOTES
    Author: Hassan Rahman (Heyson315)
    Version: 1.1
    CPA Firm: Solo Practitioner Testing Playground
    License: MIT
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TenantId,
    
    [Parameter()]
    [switch]$IncludeQuickBooks,
    
    [Parameter()]
    [switch]$IncludeDynamics365,
    
    [Parameter()]
    [switch]$IncludeThirdPartyApps,
    
    [Parameter()]
    [switch]$IncludeCostAnalysis,
    
    [Parameter()]
    [switch]$DetailedReport
)

# Requires PowerShell 7+
#Requires -Version 7.0

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

$script:ValidationResults = @()
$script:CriticalIssues = @()
$script:Warnings = @()
$script:Passed = 0
$script:Failed = 0
$script:WarningCount = 0
$script:TotalMonthlyCost = 0
$script:AzureCreditsAvailable = 0

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

function Write-CheckResult {
    param(
        [string]$CheckName,
        [string]$Status,
        [string]$Message,
        [string]$Severity = "Info"
    )
    
    $Icon = switch ($Status) {
        "Pass" { "✅"; $script:Passed++ }
        "Fail" { "❌"; $script:Failed++ }
        "Warning" { "⚠️ "; $script:WarningCount++ }
        "Info" { "ℹ️ " }
        default { "❓" }
    }
    
    Write-Host "  $Icon $CheckName" -ForegroundColor $(
        switch ($Status) {
            "Pass" { "Green" }
            "Fail" { "Red" }
            "Warning" { "Yellow" }
            default { "Cyan" }
        }
    )
    
    if ($Message) {
        Write-Host "     $Message" -ForegroundColor Gray
    }
    
    $script:ValidationResults += [PSCustomObject]@{
        Category = $script:CurrentCategory
        Check = $CheckName
        Status = $Status
        Message = $Message
        Severity = $Severity
    }
    
    if ($Status -eq "Fail" -and $Severity -eq "Critical") {
        $script:CriticalIssues += "${CheckName}: ${Message}"
    }
    elseif ($Status -eq "Warning") {
        $script:Warnings += "${CheckName}: ${Message}"
    }
}

function Test-ModuleInstalled {
    param([string]$ModuleName)
    return (Get-Module -ListAvailable -Name $ModuleName) -ne $null
}

function Install-RequiredModule {
    param([string]$ModuleName)
    
    Write-Host "  📦 Installing $ModuleName..." -ForegroundColor Yellow
    try {
        Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Host "  ✅ $ModuleName installed successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  ❌ Failed to install $ModuleName : $_" -ForegroundColor Red
        return $false
    }
}

# ============================================================================
# VALIDATION CHECKS
# ============================================================================

function Test-PowerShellPrerequisites {
    $script:CurrentCategory = "PowerShell Prerequisites"
    Write-Header "1️⃣  PowerShell & Module Prerequisites"
    
    # PowerShell Version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 7) {
        Write-CheckResult "PowerShell Version" "Pass" "Version $psVersion"
    }
    else {
        Write-CheckResult "PowerShell Version" "Fail" "Version $psVersion (Requires 7.0+)" "Critical"
    }
    
    # Required Modules
    $requiredModules = @(
        @{Name = "Microsoft.Graph"; MinVersion = "2.0" },
        @{Name = "Microsoft.Graph.Authentication"; MinVersion = "2.0" },
        @{Name = "Microsoft.Graph.Identity.SignIns"; MinVersion = "2.0" },
        @{Name = "Microsoft.Graph.Users"; MinVersion = "2.0" }
    )
    
    foreach ($module in $requiredModules) {
        $installed = Get-Module -ListAvailable -Name $module.Name | 
                     Where-Object { $_.Version -ge $module.MinVersion } | 
                     Select-Object -First 1
        
        if ($installed) {
            Write-CheckResult "$($module.Name)" "Pass" "Version $($installed.Version)"
        }
        else {
            Write-CheckResult "$($module.Name)" "Fail" "Not installed or version < $($module.MinVersion)" "High"
            
            $install = Read-Host "    Install $($module.Name) now? (Y/N)"
            if ($install -eq 'Y') {
                Install-RequiredModule -ModuleName $module.Name
            }
        }
    }
    
    # Check for Az module (for Azure subscription checks)
    if ($IncludeCostAnalysis) {
        $azInstalled = Test-ModuleInstalled -ModuleName "Az.Accounts"
        if ($azInstalled) {
            Write-CheckResult "Az.Accounts Module" "Pass" "Installed (for Azure cost analysis)"
        }
        else {
            Write-CheckResult "Az.Accounts Module" "Info" "Not installed (optional for Azure subscription checks)"
        }
    }
}

function Test-AzureAuthentication {
    $script:CurrentCategory = "Azure Authentication"
    Write-Header "2️⃣  Azure Tenant Authentication"
    
    try {
        # Check if already connected
        $context = Get-MgContext -ErrorAction SilentlyContinue
        
        if ($null -eq $context) {
            Write-Host "  🔐 Not connected to Microsoft Graph. Attempting authentication..." -ForegroundColor Yellow
            Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All", "Policy.Read.All" -ErrorAction Stop
            $context = Get-MgContext
        }
        
        Write-CheckResult "Microsoft Graph Connection" "Pass" "Connected to tenant: $($context.TenantId)"
        
        # Store tenant ID for later use
        if (-not $script:TenantId) {
            $script:TenantId = $context.TenantId
        }
        
        # Check permissions
        $scopes = $context.Scopes
        $requiredScopes = @("User.Read.All", "Directory.Read.All", "Policy.Read.All")
        $missingScopes = $requiredScopes | Where-Object { $_ -notin $scopes }
        
        if ($missingScopes.Count -eq 0) {
            Write-CheckResult "Required Permissions" "Pass" "All required scopes granted"
        }
        else {
            Write-CheckResult "Required Permissions" "Warning" "Missing: $($missingScopes -join ', ')"
        }
    }
    catch {
        Write-CheckResult "Microsoft Graph Connection" "Fail" "Failed to connect: $_" "Critical"
    }
}

function Test-SubscriptionCostsAndCredits {
    $script:CurrentCategory = "Subscription Costs & Credits"
    Write-Header "2️⃣.5️⃣  Subscription Cost Analysis & Azure Credits"
    
    Write-Host "  💰 Analyzing your subscription costs and available credits..." -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Get all subscribed SKUs
        $subscribedSkus = Get-MgSubscribedSku -ErrorAction Stop
        
        # Define SKU pricing and types
        $skuInfo = @{
            # Microsoft 365 E5 variants
            "c7df2760-2c81-4ef7-b578-5b5392b571df" = @{Name = "Microsoft 365 E5"; Cost = 57.00; Type = "Paid" }
            "06ebc4ee-1bb5-47dd-8120-11324bc54e06" = @{Name = "Microsoft 365 E5 (No Teams)"; Cost = 54.00; Type = "Paid" }
            "f8a1db68-be16-40ed-86d5-cb42ce701560" = @{Name = "Microsoft 365 E5 Developer"; Cost = 0.00; Type = "Free (90-day renewable)" }
            
            # Other common SKUs
            "18181a46-0d4e-45cd-891e-60aabd171b4e" = @{Name = "Office 365 E1"; Cost = 10.00; Type = "Paid" }
            "6fd2c87f-b296-42f0-b197-1e91e994b900" = @{Name = "Office 365 E3"; Cost = 23.00; Type = "Paid" }
            "05e9a617-0261-4cee-bb44-138d3ef5d965" = @{Name = "Microsoft 365 E3"; Cost = 36.00; Type = "Paid" }
            "4b590615-0888-425a-a965-b3bf7789848d" = @{Name = "Microsoft 365 Business Premium"; Cost = 22.00; Type = "Paid" }
            "cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46" = @{Name = "Microsoft 365 Business Basic"; Cost = 6.00; Type = "Paid" }
            
            # Dynamics 365
            "8e229017-d77b-43d5-9305-903c637de832" = @{Name = "Dynamics 365 Business Central Essentials"; Cost = 70.00; Type = "Paid" }
            "920656a2-7dd8-4c83-97b6-a356414dbd36" = @{Name = "Dynamics 365 Business Central Premium"; Cost = 100.00; Type = "Paid" }
        }
        
        $totalMonthlyCost = 0
        $freeSubscriptions = @()
        $paidSubscriptions = @()
        
        Write-Host "  📊 Microsoft 365 / Dynamics 365 Subscriptions:" -ForegroundColor Yellow
        Write-Host ""
        
        foreach ($sku in $subscribedSkus) {
            $skuId = $sku.SkuId
            $skuPartNumber = $sku.SkuPartNumber
            $consumedUnits = $sku.ConsumedUnits
            $enabledUnits = $sku.PrepaidUnits.Enabled;
            
            $info = $skuInfo[$skuId]
            if ($info) {
                $monthlyCost = $info.Cost * $consumedUnits
                $totalMonthlyCost += $monthlyCost
                
                $color = if ($info.Type -like "*Free*") { "Green" } else { "Yellow" }
                
                Write-Host "  • $($info.Name)" -ForegroundColor $color
                Write-Host "     Type: $($info.Type)" -ForegroundColor Gray
                Write-Host "     Assigned: $consumedUnits / $enabledUnits licenses" -ForegroundColor Gray
                Write-Host "     Cost per license: `$$($info.Cost)/month" -ForegroundColor Gray
                Write-Host "     Monthly cost: `$$([math]::Round($monthlyCost, 2))" -ForegroundColor $(if ($monthlyCost -eq 0) { "Green" } else { "Cyan" })
                Write-Host ""
                
                if ($info.Type -like "*Free*") {
                    $freeSubscriptions += $info.Name
                }
                else {
                    $paidSubscriptions += @{Name = $info.Name; Cost = $monthlyCost }
                }
            }
            else {
                # Unknown SKU
                Write-Host "  • $skuPartNumber (SKU: $skuId)" -ForegroundColor Gray
                Write-Host "     Assigned: $consumedUnits / $enabledUnits licenses" -ForegroundColor Gray
                Write-Host "     Cost: Unknown (check Microsoft pricing)" -ForegroundColor Yellow
                Write-Host ""
            }
        }
        
        # Calculate annual cost
        $annualCost = $totalMonthlyCost * 12
        $script:TotalMonthlyCost = $totalMonthlyCost
        
        Write-Host "  💵 Total Estimated Costs:" -ForegroundColor Cyan
        Write-Host "     Monthly: `$$([math]::Round($totalMonthlyCost, 2))" -ForegroundColor $(if ($totalMonthlyCost -eq 0) { "Green" } else { "Yellow" })
        Write-Host "     Annual: `$$([math]::Round($annualCost, 2))" -ForegroundColor $(if ($annualCost -eq 0) { "Green" } else { "Yellow" })
        Write-Host ""
        
        # Check subscription type
        if ($freeSubscriptions.Count -gt 0) {
            Write-CheckResult "Free Subscriptions Detected" "Pass" "$($freeSubscriptions.Count) free subscription(s): $($freeSubscriptions -join ', ')"
            
            Write-Host "  ℹ️  Developer Program Renewal:" -ForegroundColor Cyan
            Write-Host "     - E5 Developer subscriptions renew every 90 days" -ForegroundColor Gray
            Write-Host "     - Check renewal status: https://developer.microsoft.com/microsoft-365/profile" -ForegroundColor Gray
            Write-Host "     - Must show 'active usage' to auto-renew" -ForegroundColor Gray
            Write-Host ""
        }
        
        if ($paidSubscriptions.Count -gt 0) {
            $highestCost = ($paidSubscriptions | Sort-Object -Property Cost -Descending | Select-Object -First 1)
            Write-CheckResult "Paid Subscriptions Active" "Warning" "Monthly cost: `$$([math]::Round($totalMonthlyCost, 2)) - Consider cost optimization"
            
            Write-Host "  💡 Cost Optimization Tips:" -ForegroundColor Yellow
            Write-Host "     1. Review unused licenses and remove assignments" -ForegroundColor Gray
            Write-Host "     2. Consider E5 Developer (free) for testing/development" -ForegroundColor Gray
            Write-Host "     3. Use E3 instead of E5 if advanced security features not needed" -ForegroundColor Gray
            Write-Host "     4. Check for annual commitment discounts (save up to 17%)" -ForegroundColor Gray
            Write-Host ""
        }
        else {
            Write-CheckResult "Subscription Cost" "Pass" "No paid Microsoft 365 subscriptions - Using free tier"
        }
        
        # Check Azure subscriptions and credits
        Write-Host "  ☁️  Azure Subscription & Credits Check:" -ForegroundColor Cyan
        Write-Host ""
        
        $azAccountsInstalled = Test-ModuleInstalled -ModuleName "Az.Accounts"
        
        if ($azAccountsInstalled) {
            try {
                # Check if connected to Azure
                $azContext = Get-AzContext -ErrorAction SilentlyContinue
                
                if ($null -eq $azContext) {
                    Write-Host "  🔐 Not connected to Azure. Attempting authentication..." -ForegroundColor Yellow
                    Connect-AzAccount -TenantId $script:TenantId -ErrorAction Stop | Out-Null
                    $azContext = Get-AzContext
                }
                
                if ($azContext) {
                    $azSubscriptions = Get-AzSubscription -TenantId $script:TenantId -ErrorAction Stop
                    
                    if ($azSubscriptions.Count -gt 0) {
                        Write-Host "  📋 Azure Subscriptions Found: $($azSubscriptions.Count)" -ForegroundColor Green
                        Write-Host ""
                        
                        foreach ($sub in $azSubscriptions) {
                            Write-Host "  • $($sub.Name)" -ForegroundColor Yellow
                            Write-Host "     Subscription ID: $($sub.Id)" -ForegroundColor Gray
                            Write-Host "     State: $($sub.State)" -ForegroundColor $(if ($sub.State -eq "Enabled") { "Green" } else { "Red" })
                            
                            # Identify subscription type by name patterns
                            $subType = "Unknown"
                            $estimatedCredit = 0
                            
                            switch -Regex ($sub.Name) {
                                "Visual Studio Enterprise|MSDN" { 
                                    $subType = "Visual Studio Enterprise Subscription"
                                    $estimatedCredit = 150
                                }
                                "Visual Studio Professional" { 
                                    $subType = "Visual Studio Professional Subscription"
                                    $estimatedCredit = 50
                                }
                                "Free Trial|Azure Free" { 
                                    $subType = "Azure Free Trial"
                                    $estimatedCredit = 200  # One-time $200 credit
                                }
                                "Pay-As-You-Go|PAYG" { 
                                    $subType = "Pay-As-You-Go (No monthly credits)"
                                    $estimatedCredit = 0
                                }
                                "Sponsorship|Startup" { 
                                    $subType = "Microsoft Sponsorship / Startup Program"
                                    $estimatedCredit = 0  # Variable
                                }
                                "Azure for Students" { 
                                    $subType = "Azure for Students"
                                    $estimatedCredit = 100
                                }
                            }
                            
                            Write-Host "     Type: $subType" -ForegroundColor Gray
                            if ($estimatedCredit -gt 0) {
                                Write-Host "     Estimated Monthly Credit: `$$estimatedCredit" -ForegroundColor Green
                                $script:AzureCreditsAvailable += $estimatedCredit
                            }
                            Write-Host ""
                        }
                        
                        if ($script:AzureCreditsAvailable -gt 0) {
                            Write-CheckResult "Azure Credits Available" "Pass" "Estimated `$$script:AzureCreditsAvailable/month in Azure credits"
                        }
                        else {
                            Write-CheckResult "Azure Credits" "Info" "No automatic monthly credits detected (Pay-As-You-Go or unknown type)"
                        }
                    }
                    else {
                        Write-CheckResult "Azure Subscriptions" "Info" "No Azure subscriptions found in this tenant"
                    }
                }
            }
            catch {
                Write-CheckResult "Azure Subscription Check" "Warning" "Unable to check Azure subscriptions: $_"
                Write-Host "  ℹ️  To check Azure credits manually:" -ForegroundColor Cyan
                Write-Host "     1. Go to: https://portal.azure.com" -ForegroundColor Gray
                Write-Host "     2. Navigate to: Cost Management + Billing → Credits" -ForegroundColor Gray
                Write-Host ""
            }
        }
        else {
            Write-Host "  ℹ️  Az.Accounts module not installed. To check Azure credits:" -ForegroundColor Cyan
            Write-Host "     1. Install: Install-Module -Name Az.Accounts -Scope CurrentUser" -ForegroundColor Gray
            Write-Host "     2. Re-run this script with -IncludeCostAnalysis" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  Or check manually at: https://portal.azure.com → Cost Management + Billing" -ForegroundColor Gray
            Write-Host ""
            
            Write-CheckResult "Azure Credits Check" "Info" "Az.Accounts module required for automatic detection"
        }
        
        # Summary and recommendations
        Write-Host "  📌 Cost Summary & Recommendations:" -ForegroundColor Cyan
        Write-Host ""
        
        if ($totalMonthlyCost -eq 0 -and $freeSubscriptions.Count -gt 0) {
            Write-Host "  ✅ You're on FREE subscriptions! ($($freeSubscriptions -join ', '))" -ForegroundColor Green
            Write-Host "     - Perfect for testing and development" -ForegroundColor Gray
            Write-Host "     - Monitor renewal status every 90 days" -ForegroundColor Gray
            Write-Host "     - Ensure active usage to maintain auto-renewal" -ForegroundColor Gray
        }
        elseif ($totalMonthlyCost -gt 0 -and $totalMonthlyCost -lt 100) {
            Write-Host "  ⚠️  Low monthly cost (`$$([math]::Round($totalMonthlyCost, 2)))" -ForegroundColor Yellow
            Write-Host "     - Consider migrating to E5 Developer (free) if for testing" -ForegroundColor Gray
            Write-Host "     - Or downgrade to E3 if E5 features not fully utilized" -ForegroundColor Gray
        }
        elseif ($totalMonthlyCost -ge 100) {
            Write-Host "  🚨 HIGH monthly cost (`$$([math]::Round($totalMonthlyCost, 2)))" -ForegroundColor Red
            Write-Host "     - URGENT: Review license assignments" -ForegroundColor Red
            Write-Host "     - Remove unused licenses immediately" -ForegroundColor Red
            Write-Host "     - Consider E5 Developer for non-production use" -ForegroundColor Red
            Write-Host "     - Annual commitment can save 17% (~`$$([math]::Round($annualCost * 0.17, 2))/year)" -ForegroundColor Yellow
        }
        
        Write-Host ""
        
        # Azure credit recommendations
        if ($script:AzureCreditsAvailable -gt 0) {
            Write-Host "  💳 Azure Credits: You have ~`$$script:AzureCreditsAvailable/month" -ForegroundColor Green
            Write-Host "     - Use these for Azure services (VMs, Storage, etc.)" -ForegroundColor Gray
            Write-Host "     - Does NOT apply to Microsoft 365 licenses" -ForegroundColor Gray
        }
        else {
            Write-Host "  💳 No monthly Azure credits detected" -ForegroundColor Yellow
            Write-Host "     - Consider Visual Studio subscription (includes `$50-150/month credit)" -ForegroundColor Gray
            Write-Host "     - Or Azure for Students (`$100 credit for eligible students)" -ForegroundColor Gray
        }
        
        Write-Host ""
        
    }
    catch {
        Write-CheckResult "Cost Analysis" "Warning" "Unable to analyze costs: $_"
    }
}

function Test-E5Licensing {
    $script:CurrentCategory = "E5 Licensing"
    Write-Header "3️⃣  Microsoft 365 E5 License Validation"
    
    try {
        # Get all users
        $users = Get-MgUser -All -Property "DisplayName,UserPrincipalName,AssignedLicenses" -ErrorAction Stop
        $totalUsers = $users.Count
        
        Write-CheckResult "Total Users" "Info" "$totalUsers users in tenant"
        
        # E5 SKU IDs (multiple variants)
        $e5Skus = @(
            "c7df2760-2c81-4ef7-b578-5b5392b571df",  # Microsoft 365 E5
            "06ebc4ee-1bb5-47dd-8120-11324bc54e06",  # Microsoft 365 E5 (No Teams)
            "f8a1db68-be16-40ed-86d5-cb42ce701560"   # Microsoft 365 E5 Developer
        )
        
        $e5Users = $users | Where-Object {
            $_.AssignedLicenses.SkuId | Where-Object { $_ -in $e5Skus }
        }
        
        $e5Count = ($e5Users | Measure-Object).Count
        $e5Percentage = if ($totalUsers -gt 0) { [math]::Round(($e5Count / $totalUsers) * 100, 2) } else { 0 }
        
        if ($e5Count -gt 0) {
            Write-CheckResult "E5 License Assignments" "Pass" "$e5Count users with E5 ($e5Percentage%)"
        }
        else {
            Write-CheckResult "E5 License Assignments" "Fail" "No E5 licenses found" "Critical"
        }
        
        # Check for users without E5 (in solo CPA, should be minimal)
        $nonE5Users = $totalUsers - $e5Count
        if ($nonE5Users -gt 0) {
            Write-CheckResult "Unlicensed/Non-E5 Users" "Warning" "$nonE5Users users without E5"
        }
        
        # Check E5 features availability
        $subscribedSkus = Get-MgSubscribedSku -ErrorAction Stop
        $e5Sku = $subscribedSkus | Where-Object { $_.SkuId -in $e5Skus } | Select-Object -First 1
        
        if ($e5Sku) {
            $availableLicenses = $e5Sku.PrepaidUnits.Enabled - $e5Sku.ConsumedUnits
            Write-CheckResult "E5 Licenses Available" "Info" "$availableLicenses licenses available"
            
            # Check included services
            $e5Services = @(
                "IDENTITY_THREAT_PROTECTION",     # Identity Protection
                "INTUNE_A",                       # Intune
                "MFA_PREMIUM",                    # MFA
                "AAD_PREMIUM_P2"                  # Entra ID P2
            )
            
            $enabledServices = $e5Sku.ServicePlans | Where-Object { $_.ProvisioningStatus -eq "Success" }
            foreach ($service in $e5Services) {
                $enabled = $enabledServices | Where-Object { $_.ServicePlanName -eq $service }
                if ($enabled) {
                    Write-CheckResult "$service" "Pass" "Enabled"
                }
                else {
                    Write-CheckResult "$service" "Warning" "Not enabled or not found"
                }
            }
        }
    }
    catch {
        Write-CheckResult "E5 License Check" "Fail" "Error: $_" "High"
    }
}

function Test-IdentityProtection {
    $script:CurrentCategory = "Identity Protection"
    Write-Header "4️⃣  Identity Protection (E5 Feature)"
    
    try {
        # Check if Identity Protection is available
        # Note: This requires Microsoft.Graph.IdentityProtection module
        Write-CheckResult "Identity Protection Module" "Info" "Checking availability..."
        
        # For now, we'll check if the feature is enabled via policy
        $caCheck = @"
        Identity Protection features to verify manually:
        1. Sign-in risk policy configured
        2. User risk policy configured
        3. Risk detections monitored
        4. Alerts configured for high-risk events
"@
        Write-CheckResult "Identity Protection Setup" "Info" $caCheck
        
    }
    catch {
        Write-CheckResult "Identity Protection" "Warning" "Unable to verify: $_"
    }
}

function Test-ConditionalAccess {
    $script:CurrentCategory = "Conditional Access"
    Write-Header "5️⃣  Conditional Access Policies"
    
    try {
        $policies = Get-MgIdentityConditionalAccessPolicy -All -ErrorAction Stop
        $policyCount = ($policies | Measure-Object).Count
        
        if ($policyCount -gt 0) {
            Write-CheckResult "CA Policies Deployed" "Pass" "$policyCount policies found"
            
            # Check for external user policies
            $externalPolicies = $policies | Where-Object {
                $_.Conditions.Users.IncludeGuestsOrExternalUsers
            }
            
            if ($externalPolicies) {
                Write-CheckResult "External User Policies" "Pass" "$($externalPolicies.Count) policies target external users"
            }
            else {
                Write-CheckResult "External User Policies" "Warning" "No policies specifically for external users"
            }
            
            # Check for report-only policies
            $reportOnly = $policies | Where-Object { $_.State -eq "enabledForReportingButNotEnforced" }
            if ($reportOnly) {
                Write-CheckResult "Report-Only Policies" "Info" "$($reportOnly.Count) policies in report-only mode"
            }
            
            # Check for emergency access exclusions
            $policiesWithExclusions = $policies | Where-Object {
                $_.Conditions.Users.ExcludeUsers.Count -gt 0
            }
            
            if ($policiesWithExclusions) {
                Write-CheckResult "Emergency Access Exclusions" "Pass" "Some policies have user exclusions"
            }
            else {
                Write-CheckResult "Emergency Access Exclusions" "Warning" "No emergency access exclusions found"
            }
        }
        else {
            Write-CheckResult "CA Policies Deployed" "Fail" "No policies found - deploy E5 templates" "High"
        }
    }
    catch {
        Write-CheckResult "Conditional Access" "Fail" "Error: $_" "High"
    }
}

function Test-IntuneDeviceCompliance {
    $script:CurrentCategory = "Intune Device Compliance"
    Write-Header "6️⃣  Intune Device Compliance (E5 Feature)"
    
    # Note: Full Intune validation requires Microsoft.Graph.Intune module
    Write-Host "  ℹ️  Intune validation requires manual verification:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. Navigate to: Intune admin center → Devices → Compliance policies" -ForegroundColor Gray
    Write-Host "  2. Verify policies exist for:" -ForegroundColor Gray
    Write-Host "     - Windows 10/11 (BitLocker, Defender AV, OS version)" -ForegroundColor Gray
    Write-Host "     - iOS/iPadOS (device encryption, passcode)" -ForegroundColor Gray
    Write-Host "     - Android (device encryption, Google Play Protect)" -ForegroundColor Gray
    Write-Host "  3. Check device enrollment status" -ForegroundColor Gray
    Write-Host ""
    
    Write-CheckResult "Intune Configuration" "Info" "Manual verification required (see above)"
}

function Test-CrossTenantAccess {
    $script:CurrentCategory = "Cross-Tenant Access"
    Write-Header "7️⃣  Cross-Tenant Access Configuration"
    
    try {
        # Check cross-tenant access settings
        Write-Host "  ℹ️  Checking cross-tenant access configuration..." -ForegroundColor Cyan
        
        # For now, manual check
        $crossTenantCheck = @"
        Cross-tenant access settings to verify:
        1. Entra admin center → External Identities → Cross-tenant access settings
        2. Check if partner organizations configured
        3. Verify inbound/outbound trust settings
        4. Confirm MFA/device claims accepted
"@
        Write-CheckResult "Cross-Tenant Access" "Info" $crossTenantCheck
        
    }
    catch {
        Write-CheckResult "Cross-Tenant Access" "Warning" "Unable to verify: $_"
    }
}

function Test-QuickBooksIntegration {
    param()
    
    $script:CurrentCategory = "QuickBooks Online"
    Write-Header "8️⃣  QuickBooks Online API Integration"
    
    Write-Host "  📊 QuickBooks Online Prerequisites:" -ForegroundColor Cyan
    Write-Host ""
    
    # QuickBooks API requirements
    $qbRequirements = @(
        @{
            Name = "QuickBooks Developer Account"
            Check = "Do you have a QuickBooks Developer account?"
            Action = "Create at: https://developer.intuit.com/"
        },
        @{
            Name = "OAuth 2.0 App Created"
            Check = "Have you created an app in QuickBooks Developer portal?"
            Action = "Create app → Get Client ID & Secret"
        },
        @{
            Name = "Redirect URI Configured"
            Check = "Is your redirect URI registered?"
            Action = "Add to app settings (e.g., https://yourapp.com/callback)"
        },
        @{
            Name = "Scopes Requested"
            Check = "Required scopes: com.intuit.quickbooks.accounting"
            Action = "Enable in app settings"
        },
        @{
            Name = "Test Company Connection"
            Check = "Can you connect to QuickBooks sandbox?"
            Action = "Use sandbox company for testing"
        }
    )
    
    foreach ($req in $qbRequirements) {
        Write-Host "  ☐ $($req.Name)" -ForegroundColor Yellow
        Write-Host "     Check: $($req.Check)" -ForegroundColor Gray
        Write-Host "     Action: $($req.Action)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-CheckResult "QuickBooks API Prerequisites" "Info" "Manual verification required (see checklist above)"
    
    # API Endpoint Test (if credentials available)
    Write-Host "  ℹ️  To test QBO API connection, you'll need:" -ForegroundColor Cyan
    Write-Host "     - Client ID" -ForegroundColor Gray
    Write-Host "     - Client Secret" -ForegroundColor Gray
    Write-Host "     - Company ID (Realm ID)" -ForegroundColor Gray
    Write-Host "     - OAuth tokens (access + refresh)" -ForegroundColor Gray
    Write-Host ""
}

function Test-Dynamics365Integration {
    param()
    
    $script:CurrentCategory = "Dynamics 365 Business Central"
    Write-Header "9️⃣  Dynamics 365 Business Central Integration"
    
    Write-Host "  📊 Dynamics 365 Business Central Prerequisites:" -ForegroundColor Cyan
    Write-Host ""
    
    # D365 BC requirements
    $d365Requirements = @(
        @{
            Name = "Dynamics 365 Business Central License"
            Check = "Do you have D365 BC Essentials or Premium?"
            Action = "Required for API access"
        },
        @{
            Name = "Azure AD App Registration"
            Check = "Have you registered an Azure AD app for D365 BC?"
            Action = "Azure Portal → App Registrations → New"
        },
        @{
            Name = "API Permissions Granted"
            Check = "API permissions: Dynamics 365 Business Central API"
            Action = "Grant admin consent for API access"
        },
        @{
            Name = "Service Principal Access"
            Check = "Is service principal added to D365 BC?"
            Action = "Business Central → Users → Add app user"
        },
        @{
            Name = "Web Services Enabled"
            Check = "Are OData/API web services published?"
            Action = "D365 BC → Web Services → Publish required pages"
        }
    )
    
    foreach ($req in $d365Requirements) {
        Write-Host "  ☐ $($req.Name)" -ForegroundColor Yellow
        Write-Host "     Check: $($req.Check)" -ForegroundColor Gray
        Write-Host "     Action: $($req.Action)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-CheckResult "Dynamics 365 BC Prerequisites" "Info" "Manual verification required (see checklist above)"
    
    # Environment check
    Write-Host "  ℹ️  D365 Business Central API Endpoints:" -ForegroundColor Cyan
    Write-Host "     Production: https://api.businesscentral.dynamics.com/v2.0/{tenantId}/{environment}" -ForegroundColor Gray
    Write-Host "     Sandbox: Use your sandbox environment name" -ForegroundColor Gray
    Write-Host ""
}

function Test-ThirdPartyApps {
    param()
    
    $script:CurrentCategory = "Third-Party Integrations"
    Write-Header "🔟 Other Accounting Software Integrations"
    
    $thirdPartyApps = @(
        @{
            Name = "Xero"
            ApiDocs = "https://developer.xero.com/"
            AuthType = "OAuth 2.0"
            Notes = "Popular for small businesses"
        },
        @{
            Name = "Bill.com"
            ApiDocs = "https://developer.bill.com/"
            AuthType = "OAuth 2.0"
            Notes = "AP/AR automation"
        },
        @{
            Name = "Avalara (Tax)"
            ApiDocs = "https://developer.avalara.com/"
            AuthType = "API Key / OAuth"
            Notes = "Sales tax automation"
        },
        @{
            Name = "Stripe (Payments)"
            ApiDocs = "https://stripe.com/docs/api"
            AuthType = "API Key"
            Notes = "Payment processing"
        },
        @{
            Name = "Plaid (Banking)"
            ApiDocs = "https://plaid.com/docs/"
            AuthType = "API Key"
            Notes = "Bank account connectivity"
        }
    )
    
    Write-Host "  📋 Common CPA Firm Integrations:" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($app in $thirdPartyApps) {
        Write-Host "  • $($app.Name)" -ForegroundColor Yellow
        Write-Host "     Docs: $($app.ApiDocs)" -ForegroundColor Gray
        Write-Host "     Auth: $($app.AuthType)" -ForegroundColor Gray
        Write-Host "     Notes: $($app.Notes)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-CheckResult "Third-Party App Research" "Info" "See list above for integration options"
}

function Test-CPAFirmCompliance {
    $script:CurrentCategory = "CPA Firm Compliance"
    Write-Header "1️⃣1️⃣  CPA Firm Specific Compliance Checks"
    
    Write-Host "  🏢 Solo CPA Practitioner Considerations:" -ForegroundColor Cyan
    Write-Host ""
    
    $cpaChecks = @(
        @{
            Name = "Client Data Segregation"
            Requirement = "Each client's data in separate folders/SharePoint sites"
            Status = "Manual"
        },
        @{
            Name = "7-Year Data Retention"
            Requirement = "Configure audit logs and file retention (IRS requirement)"
            Status = "Manual"
        },
        @{
            Name = "Encryption at Rest"
            Requirement = "Enabled by default in Microsoft 365"
            Status = "Auto"
        },
        @{
            Name = "Encryption in Transit"
            Requirement = "TLS 1.2+ for all connections"
            Status = "Auto"
        },
        @{
            Name = "MFA Enforcement"
            Requirement = "All users (including you) must use MFA"
            Status = "Check CA Policies"
        },
        @{
            Name = "Client Confidentiality"
            Requirement = "AICPA Code of Professional Conduct Section 1.700"
            Status = "Policy"
        },
        @{
            Name = "State Board Compliance"
            Requirement = "Check your state's data protection requirements"
            Status = "Manual"
        }
    )
    
    foreach ($check in $cpaChecks) {
        Write-Host "  ☐ $($check.Name)" -ForegroundColor Yellow
        Write-Host "     Requirement: $($check.Requirement)" -ForegroundColor Gray
        Write-Host "     Status: $($check.Status)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-CheckResult "CPA Compliance Framework" "Info" "Manual verification required (see checklist above)"
}

function Write-FinalSummary {
    Write-Header "📊 Validation Summary"
    
    Write-Host "  Results:" -ForegroundColor Cyan
    Write-Host "  ✅ Passed: $script:Passed" -ForegroundColor Green
    Write-Host "  ❌ Failed: $script:Failed" -ForegroundColor Red
    Write-Host "  ⚠️  Warnings: $script:WarningCount" -ForegroundColor Yellow
    Write-Host ""
    
    # Critical issues
    if ($script:CriticalIssues.Count -gt 0) {
        Write-Host "  🚨 CRITICAL ISSUES (Must Fix):" -ForegroundColor Red
        foreach ($issue in $script:CriticalIssues) {
            Write-Host "     • $issue" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    # Warnings
    if ($script:Warnings.Count -gt 0 -and $script:Warnings.Count -le 5) {
        Write-Host "  ⚠️  WARNINGS (Recommended):" -ForegroundColor Yellow
        foreach ($warning in $script:Warnings) {
            Write-Host "     • $warning" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    # Next steps
    Write-Host "  📋 Next Steps:" -ForegroundColor Cyan
    Write-Host ""
    
    if ($script:Failed -gt 0) {
        Write-Host "  1. Address CRITICAL issues above" -ForegroundColor Red
        Write-Host "  2. Review E5 prerequisites in docs/e5-optimization-guide.md" -ForegroundColor Yellow
        Write-Host "  3. Deploy missing CA policies from docs/policies/" -ForegroundColor Yellow
    }
    else {
        Write-Host "  1. ✅ Tenant meets E5 prerequisites!" -ForegroundColor Green
        Write-Host "  2. Deploy E5-enhanced CA policy (docs/policies/conditional-access-mfa-external-e5-enhanced.yaml)" -ForegroundColor Cyan
        Write-Host "  3. Set up cross-tenant access (docs/cross-tenant-access/partner-tenant-config.yaml)" -ForegroundColor Cyan
        Write-Host "  4. Configure accounting software integrations (QuickBooks, D365)" -ForegroundColor Cyan
    }
    Write-Host ""
    
    # Export detailed report
    if ($DetailedReport) {
        $reportPath = ".\validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $script:ValidationResults | ConvertTo-Json -Depth 10 | Out-File $reportPath
        Write-Host "  📄 Detailed report saved: $reportPath" -ForegroundColor Cyan
        Write-Host ""
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    Write-Host ""
    Write-Host "🎯 Azure Tenant E5 Validation for CPA Firm (Solo Practitioner)" -ForegroundColor Cyan
    Write-Host "   Testing Playground + Accounting Software Integrations" -ForegroundColor Cyan
    Write-Host ""
    
    # Run validation checks
    Test-PowerShellPrerequisites
    Test-AzureAuthentication
    
    # Cost analysis (if requested or by default)
    if ($IncludeCostAnalysis -or $PSBoundParameters.Count -eq 0) {
        Test-SubscriptionCostsAndCredits
    }
    
    Test-E5Licensing
    Test-IdentityProtection
    Test-ConditionalAccess
    Test-IntuneDeviceCompliance
    Test-CrossTenantAccess
    
    # Optional integrations
    if ($IncludeQuickBooks -or $PSBoundParameters.Count -eq 0) {
        Test-QuickBooksIntegration
    }
    
    if ($IncludeDynamics365 -or $PSBoundParameters.Count -eq 0) {
        Test-Dynamics365Integration
    }
    
    if ($IncludeThirdPartyApps -or $PSBoundParameters.Count -eq 0) {
        Test-ThirdPartyApps
    }
    
    # Cost analysis if requested
    if ($IncludeCostAnalysis) {
        Test-SubscriptionCostsAndCredits
    }
    
    Test-CPAFirmCompliance
    
    # Final summary
    Write-FinalSummary
    
    # Exit code
    if ($script:Failed -gt 0) {
        exit 1
    }
    else {
        exit 0
    }
}
catch {
    Write-Host ""
    Write-Host "❌ Fatal Error: $_" -ForegroundColor Red
    Write-Host ""
    exit 1
}
finally {
    Write-Host "=" * 80 -ForegroundColor Gray
    Write-Host ""
}
