<#
.SYNOPSIS
  Deploy the fontokmai API to Cloud Run from Windows (PowerShell port of cloudrun.sh).

.DESCRIPTION
  Builds with Cloud Build from a staged copy of api/ + data/ (no Docker or rsync
  needed), runs as the fontokmai-api service account created by infra.ps1, and
  mounts whichever secrets exist in Secret Manager.

  With -Vertex (default) Gemini runs on Vertex AI through the service account;
  GEMINI_API_KEY is only mounted when -Vertex:$false.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File api\deploy\cloudrun.ps1 -Project my-project
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File api\deploy\cloudrun.ps1 -Project my-project -DemoMode 1   # scripted มิว demo

.NOTES
  Runs exactly one always-on instance: Google sign-ins live in its memory, so a
  second instance or a cold start would lose them.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $Project,
  [string] $Region = "asia-southeast1",
  [string] $Service = "fontokmai-api",
  [ValidateSet("0", "1")] [string] $DemoMode = "0",
  [ValidateSet("memory", "firestore")] [string] $ReportStore = "firestore",
  [string] $GeminiModel = "gemini-2.5-flash",
  # Vertex AI location for Gemini; check the model is offered there, or use "global".
  [string] $GeminiLocation = "asia-southeast1",
  [bool] $Vertex = $true,
  # Hosting site the Google sign-in returns to, and the OAuth client's redirect URI.
  [string] $AppUrl = "https://ai-cup-511208.web.app",
  [string] $OAuthRedirectUri = "https://fontokmai-api-lmr33aj5zq-as.a.run.app/oauth2callback"
)

function Test-Secret([string] $Name) {
  $versions = & gcloud --project $Project secrets versions list $Name --filter="state=ENABLED" --format="value(name)" 2>$null
  return ($LASTEXITCODE -eq 0 -and [string]::IsNullOrWhiteSpace("$versions") -eq $false)
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ApiSA = "fontokmai-api@$Project.iam.gserviceaccount.com"

# ---- stage a minimal build context (same as cloudrun.sh) --------------------
$ctx = Join-Path ([IO.Path]::GetTempPath()) ("fontokmai-build-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path (Join-Path $ctx "data") -Force | Out-Null
try {
  # /XD and /XF ".*" skip dot-folders and dot-files like rsync --exclude '.*'.
  & robocopy (Join-Path $Root "api") (Join-Path $ctx "api") /E /XD ".*" /XF ".*" /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
  Copy-Item (Join-Path $Root "data\bkk_flood_risk_points.json"), (Join-Path $Root "data\bkk_landmarks.json") (Join-Path $ctx "data")
  Copy-Item (Join-Path $Root "api\Dockerfile") (Join-Path $ctx "Dockerfile")

  # ---- env vars and secrets ------------------------------------------------
  $envs = @(
    "DEMO_MODE=$DemoMode", "REPORT_STORE=$ReportStore", "GEMINI_MODEL=$GeminiModel",
    "GOOGLE_CLOUD_PROJECT=$Project", "GOOGLE_CLOUD_LOCATION=$GeminiLocation",
    "TASKS_QUEUE=proactive-checks", "TASKS_LOCATION=$Region",
    "TASKS_INVOKER_SA=fontokmai-invoker@$Project.iam.gserviceaccount.com",
    "PUBSUB_TOPIC_RAW=raw-messages",
    "APP_URL=$AppUrl", "OAUTH_REDIRECT_URI=$OAuthRedirectUri"
  ) -join ","

  $secretNames = @("GOOGLE_MAPS_API_KEY", "LINE_CHANNEL_SECRET", "LINE_CHANNEL_ACCESS_TOKEN",
    "GOOGLE_OAUTH_CLIENT_ID", "GOOGLE_OAUTH_CLIENT_SECRET")
  if (-not $Vertex) { $secretNames += "GEMINI_API_KEY" }
  $mounted = @($secretNames | Where-Object { Test-Secret $_ } | ForEach-Object { "$_=${_}:latest" })
  $missing = @($secretNames | Where-Object { $mounted -notcontains "$_=${_}:latest" })
  if ($missing.Count -gt 0) { Write-Host "Secrets not found (skipped): $($missing -join ', ')" -ForegroundColor DarkYellow }

  $deployArgs = @(
    "run", "deploy", $Service, "--source", $ctx,
    "--region", $Region, "--service-account", $ApiSA,
    "--allow-unauthenticated", "--port", "8080", "--memory", "512Mi", "--cpu", "1",
    "--min-instances", "1", "--max-instances", "1", "--no-cpu-throttling", "--timeout", "300",
    "--set-env-vars", $envs
  )
  if ($mounted.Count -gt 0) { $deployArgs += @("--set-secrets", ($mounted -join ",")) }

  & gcloud --project $Project @deployArgs
  if ($LASTEXITCODE -ne 0) { throw "gcloud run deploy failed ($LASTEXITCODE)" }
} finally {
  Remove-Item $ctx -Recurse -Force -ErrorAction SilentlyContinue
}

$url = (& gcloud --project $Project run services describe $Service --region $Region --format="value(status.url)").Trim()
Write-Host "deployed: $url" -ForegroundColor Green
Write-Host "smoke test: Invoke-RestMethod $url/v1/healthz; Invoke-RestMethod $url/v1/places"
Write-Host "next: re-run api\deploy\infra.ps1 -Project $Project to wire Pub/Sub push and run.invoker"
