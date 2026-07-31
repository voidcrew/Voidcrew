# Build the wiki and sync it to S3. One-time setup is in wiki/README.md.
#
#   .\wiki\deploy.ps1                      # uses the default bucket below
#   .\wiki\deploy.ps1 -Bucket other-name   # override
#
param(
    [string]$Bucket = "wiki.voidcrew-lrp.com",
    # CloudFront distribution serving the wiki. When set, each deploy ends with a
    # cache invalidation so changes show up immediately instead of after the TTL.
    # Requires the deploy IAM user to allow cloudfront:CreateInvalidation.
    [string]$DistributionId = "",
    [string]$AwsProfile = ""
)
$ErrorActionPreference = "Stop"
$wikiRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Machine-local settings (gitignored) - e.g. your CloudFront distribution id.
# Create wiki/deploy.local.ps1 with lines like:
#   if (-not $DistributionId) { $DistributionId = "YOUR_ID" }
$localConfig = Join-Path $wikiRoot "deploy.local.ps1"
if (Test-Path $localConfig) { . $localConfig }

python (Join-Path $wikiRoot "build.py")
if ($LASTEXITCODE -ne 0) { throw "Wiki build failed - nothing uploaded." }

$syncArgs = @("s3", "sync", (Join-Path $wikiRoot "dist"), "s3://$Bucket", "--delete")
if ($AwsProfile) { $syncArgs += @("--profile", $AwsProfile) }
aws @syncArgs
if ($LASTEXITCODE -ne 0) { throw "aws s3 sync failed - check credentials (aws configure) and bucket name." }

if ($DistributionId) {
    $invArgs = @("cloudfront", "create-invalidation", "--distribution-id", $DistributionId, "--paths", "/*", "--output", "text", "--query", "Invalidation.Id")
    if ($AwsProfile) { $invArgs += @("--profile", $AwsProfile) }
    aws @invArgs
    if ($LASTEXITCODE -ne 0) { throw "CloudFront invalidation failed - files ARE uploaded, but cached pages stay stale until the TTL expires." }
}

Write-Host "Deployed to s3://$Bucket" -ForegroundColor Green
