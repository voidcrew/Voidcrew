# External BYOND resources

`PRELOAD_RSC` must remain **0**. Otherwise DreamDaemon packages the complete
resource set synchronously during client joins and ignores `EXTERNAL_RSC_URLS`.
Set `-DPRELOAD_RSC=0` in each TGS instance's DreamMaker
`CompilerAdditionalArguments`, preserving any existing arguments. This overrides
the upstream default of 1 without editing the game's compile-options source.
Recompile and activate the result; changing configuration alone does not change
an old DMB.

## Install on each Windows TGS instance

First install and deploy on `vctranslate`, verify a fresh-client join, then repeat
on `vc`. Each instance has its own `Configuration` directory and S3 prefix.

1. Copy `tools/tgs_scripts/PostCompile.bat`, `DeploymentActivation.bat`, and
   `ExternalRsc.ps1` into `Configuration/EventScripts/`. Preserve/merge any existing
   hooks. `.tgs.yml` includes these files for newly initialized instances.
2. Copy `tools/tgs_scripts/external-rsc.example.json` to
   `Configuration/external-rsc.json`, set the bucket and region, and use distinct
   prefixes such as `external-rsc/vctranslate/` and `external-rsc/vc/`.
3. Create `Configuration/Secrets/`, restrict its NTFS permissions to Administrators
   and the TGS service identity (LocalSystem on this installation), then save
   `external-rsc-aws.json` there with string fields `AccessKeyId`, `SecretAccessKey`,
   and optionally `SessionToken`. Credentials are read on every upload. Never put
   this file in the repository, `GameStaticFiles`, event arguments, or job output.
4. Grant the uploader `s3:PutObject`, `s3:PutObjectAcl`, and `s3:DeleteObject` only
   for its resource prefix, plus `s3:ListBucket` restricted with `s3:prefix` to
   that prefix's `tgstation-*` keys. Anonymous listing can remain denied.
   Objects must permit anonymous HTTP GET/HEAD and `public-read` ACLs; a bucket
   policy requiring TLS or disabling public ACLs prevents this configuration.
   Do not use KMS encryption for these anonymously downloaded objects.
5. Remove the inherited tgstation download URL from the instance's
   `Configuration/GameStaticFiles/config/resources.txt`. The hook replaces only
   active `EXTERNAL_RSC_URLS` lines and preserves browser asset settings.
6. In TGS host logging, enable Debug for
   `Tgstation.Server.Host.Components.StaticFiles.Configuration`. TGS 6.19.2 captures
   successful event-script output only at this level. Search the TGS host/job
   diagnostics for `[external-rsc]`, `ERROR`, and `PRUNING FAILED`; a successful
   compile job alone does **not** mean resource upload succeeded.

The uploader uses Windows PowerShell 5.1/.NET and `curl.exe`; no AWS CLI or module
is required. Signed S3 requests use HTTPS. Client downloads use **plain HTTP**.
Enable S3 server access logging to a separate logging destination if collecting
join evidence. Access logs arrive asynchronously and are delivered best effort.

## Deployment behavior

In [TGS 6.19.2's event contract](https://github.com/tgstation/tgstation-server/blob/tgstation-server-v6.19.2/src/Tgstation.Server.Host/Components/Events/EventType.cs),
`PostCompile.bat` receives the actual deployment directory as argument 1 and the
engine version as argument 2; `TGS_INSTANCE_ROOT` identifies the instance.
It runs before static files are linked, so the script edits the authoritative
`Configuration/GameStaticFiles/config/resources.txt` directly.

The hook clears external URLs, packages that deployment's `tgstation.rsc` at the
ZIP root, and uploads `tgstation-<rsc-md5>.zip` with `public-read`, a one-year
immutable cache policy, and `rsc-md5` object metadata. It verifies HTTP HEAD, then
downloads and decompresses the ZIP to check the embedded RSC's MD5. Only then does
it record `external-rsc-build.json` beside the DMB and atomically publish the URL.
Temporary ZIPs are removed. Provision disk space for two ZIPs during verification;
budget roughly 150+ MB per cold client and one verification download per upload.

Upload/verification failures are logged, clear the URL for on-demand delivery,
and return success to TGS so the deployment continues. An inability to write
fallback configuration is reported separately and needs operator attention.
`DeploymentActivation.bat` receives the selected deployment directory as argument
1, checks its RSC hash and HTTP object metadata, and reapplies its URL on launch
or rollback. Missing/stale manifests or objects select on-demand delivery.

Pruning is restricted to exact hash-named ZIPs under that instance's prefix and
retains three builds: the running and newly uploaded builds, plus the newest
remaining upload. The running build stays available if several compiles occur
before a round restart. Pruning failures retain the verified URL and log a warning.
If bucket versioning is enabled, configure noncurrent-version expiration too;
ordinary object deletion does not remove historical versions.

## Client builds that abort the download

BYOND 516.1677 through at least 516.1688 abort the archive download in roughly
half of all attempts, on fast connections as well as slow ones, and 516.1687's
release note acknowledges a race in the HTTP client used for `preload_rsc`.
While the download is running, and after it has been cut short, those clients do
not load `browse()` windows: every tgui window is closed as a zombie, chat images
fail, and sounds are dropped. Reconnecting starts another download that usually
aborts again. Sessions where the client skipped the download and fetched
resources on demand behaved normally.

`EXTERNAL_RSC_ON_DEMAND_FROM_BUILD` (default 1677) therefore keeps `preload_rsc`
at 0 for clients on that build or newer, so they pull resources from the server
as they need them, and hands the archive only to older builds. Raise it once
BYOND ships a build that completes the download reliably, or set it to 0 to give
the archive to everyone. The access log records which delivery each client got.

## Verify and disable

After activation, run from an administrator PowerShell on the game host:

```powershell
$instance = 'C:\path\to\instance'
& "$instance\Configuration\EventScripts\ExternalRsc.ps1" -Mode Verify `
  -InstanceRoot $instance -DeploymentDirectory "$instance\Game\Live"
```

This runs `curl -I` over HTTP, checks the configured URL and manifest against
`Game/Live/tgstation.rsc`, downloads the ZIP, and checks the decompressed MD5.
The helper reads the RSC with file sharing compatible with a running DreamDaemon;
ordinary `Get-FileHash` can fail because DreamDaemon holds a write-capable handle.
Unlike event modes, verification exits nonzero on failure. Verify the compiled
client's initial `preload_rsc` is 0 and, after `send_resources()`, is the matching
HTTP URL (admin variable inspection); compiler arguments alone are not evidence
that the running build changed.

For each instance, record the fresh-client join time and save before/after
FreezeWatch rows covering the entire download. Use a fresh BYOND cache/profile
and connect to the server's public game address. Do not run the game connection
through a localhost SSH tunnel: [BYOND ignores external resource URLs for local
connections](https://www.byond.com/docs/notes/314.html), so that test forces direct
resource delivery. The TGS management API can still use a loopback SSH tunnel.
BYOND also stores externally downloaded resources in `cache/http_cache.rsc`
and retains downloaded ZIPs. Preserve or isolate those as well when preparing
another cold-cache test; clearing only `byond.rsc` can leave an HTTP cache warm.
The after window must have no row where **both** `io_read_kb_s > 10000` and
`io_write_kb_s > 10000`, no `since_ok_ms > 1500`, and no approximately 100 MB
DreamDaemon transmit burst. `net_tx_kb_s` is host-wide: inspect the download
window and account for traffic from other instances. Process write counters
include socket writes and bound the tested DreamDaemon's total output.
Correlate the client's S3 GET for the hash-named ZIP with the access logs;
the hook's own verification GET is a separate request. Keep this operational
evidence in private diagnostics, not in the source repository.

To disable immediately, comment out every active `EXTERNAL_RSC_URLS` line and
reload configuration/restart normally. Set `Enabled` to `false` in
`Configuration/external-rsc.json` so hooks keep it disabled on later deployments.
Keep `PRELOAD_RSC=0`; clients then fetch resources on demand.

To rotate credentials, create a replacement key with the same prefix-scoped
permissions, replace the protected credentials file atomically, publish and verify
on the test instance, then production, and revoke the old key after both succeed.
No service restart is needed to pick up replacement credentials.

Local regression checks: `powershell -NoProfile -File tools/tgs_scripts/tests/ExternalRsc.Tests.ps1`.
Signing follows the [AWS SigV4 specification and test vectors](https://docs.aws.amazon.com/AmazonS3/latest/developerguide/sig-v4-header-based-auth.html).
