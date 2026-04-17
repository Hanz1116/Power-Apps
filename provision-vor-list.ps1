#Requires -Modules PnP.PowerShell
<#
.SYNOPSIS
    Provisions the VORRequests SharePoint list for the BCI VOR Canvas App.

.DESCRIPTION
    Creates the VORRequests list with all required columns in the target SharePoint
    site. Run this script once before connecting the Canvas App to SharePoint.
    The Title column (auto-generated VOR-NNNN reference) is already present on
    every SharePoint list — no need to add it.

.PARAMETER SiteUrl
    Full URL of the SharePoint site, e.g.:
    https://bcisales.sharepoint.com/sites/Operations

.EXAMPLE
    .\provision-vor-list.ps1 -SiteUrl "https://bcisales.sharepoint.com/sites/Operations"
#>
param(
    [Parameter(Mandatory)]
    [string]$SiteUrl
)

$ErrorActionPreference = "Stop"
$listTitle = "VORRequests"

Write-Host "Connecting to $SiteUrl ..." -ForegroundColor Cyan
Connect-PnPOnline -Url $SiteUrl -Interactive

# ── Helper functions ─────────────────────────────────────────────────────────

function Add-ChoiceField {
    param(
        [string]$Name,
        [string]$DisplayName,
        [string[]]$Choices,
        [bool]$Required = $false
    )
    if (Get-PnPField -List $listTitle -Identity $Name -ErrorAction SilentlyContinue) {
        Write-Warning "  '$Name' already exists — skipping."
        return
    }
    Write-Host "  + Choice : $DisplayName"
    $choicesXml = ($Choices | ForEach-Object { "<CHOICE>$_</CHOICE>" }) -join ""
    $schemaXml = "<Field Type='Choice' DisplayName='$DisplayName' Name='$Name' Required='$(if($Required){"TRUE"}else{"FALSE"})'><CHOICES>$choicesXml</CHOICES></Field>"
    Add-PnPFieldFromXml -List $listTitle -FieldXml $schemaXml | Out-Null
}

function Add-TextField {
    param(
        [string]$Name,
        [string]$DisplayName,
        [bool]$Required = $false,
        [bool]$MultiLine = $false
    )
    if (Get-PnPField -List $listTitle -Identity $Name -ErrorAction SilentlyContinue) {
        Write-Warning "  '$Name' already exists — skipping."
        return
    }
    $type = if ($MultiLine) { "Note" } else { "Text" }
    Write-Host "  + $type  : $DisplayName"
    $schemaXml = "<Field Type='$type' DisplayName='$DisplayName' Name='$Name' Required='$(if($Required){"TRUE"}else{"FALSE"})'/>"
    Add-PnPFieldFromXml -List $listTitle -FieldXml $schemaXml | Out-Null
}

function Add-NumberField {
    param(
        [string]$Name,
        [string]$DisplayName,
        [bool]$Required = $false,
        [int]$Min = 0
    )
    if (Get-PnPField -List $listTitle -Identity $Name -ErrorAction SilentlyContinue) {
        Write-Warning "  '$Name' already exists — skipping."
        return
    }
    Write-Host "  + Number : $DisplayName"
    $schemaXml = "<Field Type='Number' DisplayName='$DisplayName' Name='$Name' Required='$(if($Required){"TRUE"}else{"FALSE"})' Min='$Min'/>"
    Add-PnPFieldFromXml -List $listTitle -FieldXml $schemaXml | Out-Null
}

function Add-DateField {
    param(
        [string]$Name,
        [string]$DisplayName,
        [bool]$Required = $false,
        [bool]$DateOnly = $false
    )
    if (Get-PnPField -List $listTitle -Identity $Name -ErrorAction SilentlyContinue) {
        Write-Warning "  '$Name' already exists — skipping."
        return
    }
    Write-Host "  + DateTime: $DisplayName"
    $fmt = if ($DateOnly) { "DateOnly" } else { "DateTime" }
    $schemaXml = "<Field Type='DateTime' DisplayName='$DisplayName' Name='$Name' Required='$(if($Required){"TRUE"}else{"FALSE"})' Format='$fmt'/>"
    Add-PnPFieldFromXml -List $listTitle -FieldXml $schemaXml | Out-Null
}

function Add-PersonField {
    param(
        [string]$Name,
        [string]$DisplayName,
        [bool]$Required = $false
    )
    if (Get-PnPField -List $listTitle -Identity $Name -ErrorAction SilentlyContinue) {
        Write-Warning "  '$Name' already exists — skipping."
        return
    }
    Write-Host "  + User   : $DisplayName"
    $schemaXml = "<Field Type='User' DisplayName='$DisplayName' Name='$Name' Required='$(if($Required){"TRUE"}else{"FALSE"})'/>"
    Add-PnPFieldFromXml -List $listTitle -FieldXml $schemaXml | Out-Null
}

# ── List creation ─────────────────────────────────────────────────────────────

if (Get-PnPList -Identity $listTitle -ErrorAction SilentlyContinue) {
    Write-Warning "List '$listTitle' already exists — column provisioning will proceed, existing columns are skipped."
} else {
    Write-Host "Creating list '$listTitle' ..." -ForegroundColor Cyan
    New-PnPList -Title $listTitle -Template GenericList -EnableVersioning | Out-Null
    Write-Host "List created." -ForegroundColor Green
}

# ── Column provisioning ───────────────────────────────────────────────────────
# Title column (VOR-NNNN reference) is built-in on every SharePoint list.
# All other columns are added below.

Write-Host "`nProvisioning columns ..." -ForegroundColor Cyan

Add-ChoiceField  -Name "IdentifierType"        -DisplayName "Identifier Type"          -Choices @("VIN","Stock#")                                                                                                                     -Required $true
Add-TextField    -Name "VehicleIdentifier"      -DisplayName "Vehicle Identifier"       -Required $true
Add-ChoiceField  -Name "SubmittedOnBehalfOf"    -DisplayName "Submitted on Behalf Of"   -Choices @("Workshop (self)","Customer")                                                                                                       -Required $true
Add-TextField    -Name "CustomerName"           -DisplayName "Customer Name"
Add-TextField    -Name "FaultDescription"       -DisplayName "Fault Description"        -Required $true  -MultiLine $true
Add-TextField    -Name "PartName"               -DisplayName "Part Name"                -Required $true
Add-TextField    -Name "PartNumber"             -DisplayName "Part Number"
Add-NumberField  -Name "Quantity"               -DisplayName "Quantity"                 -Required $true  -Min 1
Add-ChoiceField  -Name "Urgency"                -DisplayName "Urgency"                  -Choices @("Safety critical","Operational","Scheduled")                                                                                        -Required $true
Add-TextField    -Name "RequestorName"          -DisplayName "Requestor Name"           -Required $true
Add-DateField    -Name "DateSubmitted"          -DisplayName "Date Submitted"
Add-ChoiceField  -Name "CurrentStatus"          -DisplayName "Current Status"           -Choices @("Draft","Submitted","Validation","Orderer processing","Parts ordered","Parts received","Dispatched","Closed","Rejected")            -Required $true
Add-PersonField  -Name "AssignedReviewer"       -DisplayName "Assigned Reviewer"
Add-PersonField  -Name "AssignedOrderer"        -DisplayName "Assigned Orderer"
Add-TextField    -Name "RejectionReason"        -DisplayName "Rejection Reason"         -MultiLine $true
Add-DateField    -Name "SignOffDate"            -DisplayName "Sign-Off Date"
Add-TextField    -Name "PONumber"               -DisplayName "PO Number"
Add-DateField    -Name "EstimatedDeliveryDate"  -DisplayName "Estimated Delivery Date"  -DateOnly $true
Add-DateField    -Name "ActualDeliveryDate"     -DisplayName "Actual Delivery Date"     -DateOnly $true
Add-ChoiceField  -Name "DispatchRoute"          -DisplayName "Dispatch Route"           -Choices @("Workshop","Customer")
Add-TextField    -Name "HandoverReference"      -DisplayName "Handover Reference"
Add-TextField    -Name "StageNotes"             -DisplayName "Stage Notes"              -MultiLine $true

Write-Host "`nAll columns provisioned successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Open Power Apps Studio (make.powerapps.com)."
Write-Host "  2. Import VORApp.msapp  (pack with: pac canvas pack --msapp VORApp.msapp --sources VORApp/)"
Write-Host "  3. Add a SharePoint connection pointing to:"
Write-Host "       Site : $SiteUrl"
Write-Host "       List : $listTitle"
Write-Host "  4. In the app, replace the VORRequests data-source placeholder with the live connection."
Write-Host "  5. Save and publish."
