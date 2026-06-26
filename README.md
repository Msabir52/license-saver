# License Saver

License Saver is a read-only PowerShell module for analyzing Microsoft 365 license usage and identifying license savings opportunities.

The tool connects to Microsoft Graph, reviews assigned licenses, account status, sign-in activity, and subscribed SKU availability, then generates an HTML report showing licenses that may be reclaimed or reviewed.

## Current Capabilities

Implemented so far:

- Connects to Microsoft Graph using app-only authentication.
- Reads tenant/app settings from a config file.
- Reads the client secret from an environment variable.
- Queries licensed users from Microsoft Graph.
- Handles Microsoft Graph paging with `@odata.nextLink`.
- Handles basic Graph throttling responses using `Retry-After`.
- Identifies disabled users that still have assigned licenses.
- Identifies active licensed users with no sign-in activity across configurable thresholds.
- Identifies unassigned license seats in the tenant.
- Uses configurable per-SKU pricing from JSON.
- Calculates projected monthly and annual savings for disabled, inactive, and unassigned-license findings.
- Writes timestamped structured logs to both the console and a log file.
- Exports disabled, inactive, and unassigned-license findings as CSV files.
- Generates a single HTML report.

Still planned:

- Per-service usage analysis for Exchange, OneDrive, SharePoint, and Teams.
- Underutilized license downgrade recommendations.
- Local Graph response cache.

## Why This Exists

Tech-Keys clients pay for many Microsoft 365 licenses every month. Two common savings opportunities are:

1. Licenses assigned to disabled or inactive users.
2. Expensive licenses assigned to users who only use a small subset of included services.

This module is intended to help identify those opportunities consistently and produce a report that can be reviewed before any tenant changes are made.

## Project Structure

```text
license-saver/
├── Config/
│   └── sku-prices.json
├── Output/
│   └── LicenseReport.html
├── scripts/
│   └── dev-run.ps1
├── src/
│   └── LicenseSaver/
│       ├── LicenseSaver.psd1
│       ├── LicenseSaver.psm1
│       ├── Public/
│       │   └── Invoke-LicenseSaver.ps1
│       └── Private/
│           ├── Export-LicenseSaverCsv.ps1
│           ├── Get-ClientSecret.ps1
│           ├── Get-DisabledLicensedUser.ps1
│           ├── Get-GraphToken.ps1
│           ├── Get-InactiveLicensedUser.ps1
│           ├── Get-LicenseSavingsEstimate.ps1
│           ├── Get-LicensedUser.ps1
│           ├── Get-LicenseSaverConfig.ps1
│           ├── Get-ReadableLicenseList.ps1
│           ├── Get-SkuPriceLookup.ps1
│           ├── Get-SubscribedSkuData.ps1
│           ├── Get-UnassignedLicenseFinding.ps1
│           ├── Invoke-GraphGet.ps1
│           ├── New-LicenseHtmlReport.ps1
│           └── Write-Log.ps1
├── licensing.ps1
└── README.md
```

## Microsoft 365 Developer Tenant Setup

1. Create a free Microsoft 365 Developer tenant:
   - Go to `https://developer.microsoft.com/microsoft-365/dev-program`.
   - Sign in with your Microsoft account.
   - Create a sandbox tenant.
   - Use the sample users and licenses provided by the developer tenant.

2. Register an app in Microsoft Entra ID:
   - Open the Microsoft Entra admin center.
   - Go to **App registrations**.
   - Create a new registration.
   - Record the tenant ID and client ID.
   - Create a client secret.

3. Store the secret securely:
   - Do not hardcode the secret in the repo.
   - Store it in an environment variable.

Example:

```powershell
[Environment]::SetEnvironmentVariable(
    "LICENSESAVER_CLIENT_SECRET",
    "your-client-secret-value",
    "User"
)
```

## Required Microsoft Graph Permissions

The app registration needs application permissions for read-only Graph access.

Current permissions used:

| Permission | Why it is needed |
|---|---|
| `User.Read.All` | Read users, account status, and assigned licenses. |
| `AuditLog.Read.All` | Read `signInActivity` for last sign-in analysis. |
| `Organization.Read.All` | Read subscribed SKUs and license availability. |
| `Reports.Read.All` | Planned usage report access for service utilization analysis. |

After adding permissions, grant admin consent.

## Configuration

Create a local config file at:

```text
Config/config.json
```

Example:

```json
{
  "TenantId": "your-tenant-id",
  "ClientId": "your-app-client-id",
  "ClientSecretEnvVar": "LICENSESAVER_CLIENT_SECRET"
}
```

`Config/config.json` is intentionally ignored by git.

SKU pricing is configured in:

```text
Config/sku-prices.json
```

Pricing is kept outside the code so it can be updated without changing module logic.

## Running The Tool

From the repo root:

```powershell
.\licensing.ps1
```

Or call the module command directly:

```powershell
Import-Module .\src\LicenseSaver\LicenseSaver.psd1 -Force

Invoke-LicenseSaver `
    -ConfigPath .\Config\config.json `
    -PricePath .\Config\sku-prices.json `
    -ReportPath .\Output\LicenseReport.html `
    -LogPath .\Output\LicenseSaver.log `
    -CsvOutputDirectory .\Output `
    -InactiveDays 30,60,90
```

The tool writes:

- HTML report output to `ReportPath`.
- Structured run logs to `LogPath`.
- CSV exports to `CsvOutputDirectory`.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `ConfigPath` | `.\Config\config.json` | Path to tenant/app configuration. |
| `PricePath` | `.\Config\sku-prices.json` | Path to configurable SKU pricing. |
| `ReportPath` | `.\Output\LicenseReport.html` | Output path for the HTML report. |
| `LogPath` | `.\Output\LicenseSaver.log` | Output path for structured run logs. |
| `CsvOutputDirectory` | `.\Output` | Directory for CSV exports. |
| `InactiveDays` | `30,60,90` | Inactivity thresholds used in the report. |

## CSV Output

The tool exports three CSV files:

| File | Contents |
|---|---|
| `DisabledUsers.csv` | Disabled users that still have assigned licenses. |
| `InactiveUsers.csv` | Enabled licensed users inactive across configured thresholds. |
| `UnassignedLicenses.csv` | Available seats by subscribed SKU. |

## Report Sections

The generated HTML report currently includes:

- Executive summary
- Disabled users with active licenses
- Inactive licensed users
- Unassigned licenses
- Methodology notes

Each finding includes the user, license evidence, recommendation, projected savings, and supporting data where available.

## Methodology

### Disabled Licensed Users

A user is flagged when:

- `accountEnabled` is `false`.
- `assignedLicenses` contains one or more licenses.

Recommendation: review the account and consider reclaiming the assigned license.

Projected savings are estimated as the sum of configured monthly prices for the assigned licenses on the flagged account.

### Inactive Licensed Users

A user is flagged when:

- The account is enabled.
- The account has one or more assigned licenses.
- The last sign-in date is older than one of the configured thresholds.

Users with no returned sign-in activity are included for manual review.

Projected savings are estimated as the sum of configured monthly prices for the assigned licenses on the flagged account.

### Unassigned Licenses

A SKU is flagged when:

```text
prepaidUnits.enabled - consumedUnits > 0
```

Projected waste is calculated as:

```text
available seats * configured monthly SKU price
```

Annualized savings are calculated as:

```text
monthly projected waste * 12
```

## Design Decisions

- The module is read-only and does not modify tenant configuration.
- Credentials are not stored in the codebase.
- SKU pricing is configurable because Microsoft pricing changes and clients may have different agreements.
- The module is split into public and private functions so future Graph collectors and recommendation logic can be added cleanly.
- The current report is HTML-first because it is easy to review and share.

## Limitations

Current limitations:

- Service usage reports are not fully implemented yet.
- Underutilized license downgrade recommendations are not currently generated.
- Savings estimates depend on the completeness and accuracy of `Config/sku-prices.json`.
- No Pester tests are included yet.
- No local cache mode is implemented yet.

## Next Improvements

Planned next steps:

- Add Graph reports ingestion for Exchange, OneDrive, SharePoint, and Teams.
- Add SKU-to-service mapping and downgrade recommendation logic.
- Add Pester tests.
- Add cache support for regenerating reports without re-querying Graph.

## Security Notes

- No tenant IDs, client IDs, secrets, or passwords should be committed.
- `Config/config.json` should remain local only.
- The client secret must be stored in an environment variable or another secure secret store.
- The app registration should use the minimum read-only Microsoft Graph permissions required.
