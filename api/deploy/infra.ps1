<#
.SYNOPSIS
  One-time GCP setup for the fontokmai AI pipeline (Windows / PowerShell).

.DESCRIPTION
  Idempotent: every resource is described first and only created when missing,
  so the script can be re-run at any time.

  Run it twice:
    1. Before the first deploy  -> APIs, service accounts, Firestore, Pub/Sub
                                   topics, Cloud Tasks queue, Artifact Registry.
    2. After cloudrun.ps1       -> run.invoker binding and Pub/Sub push
                                   subscriptions (they need the Cloud Run URL).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File api\deploy\infra.ps1 -Project my-project
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File api\deploy\infra.ps1 -Project my-project -WeatherNextDataset my-project:weathernext
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File api\deploy\infra.ps1 -Project my-project -SetSecrets
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $Project,
  [string] $Region = "asia-southeast1",
  [string] $Service = "fontokmai-api",
  [string] $Repo = "fontokmai",
  # PROJECT:DATASET of the WeatherNext linked dataset, once Analytics Hub access is approved.
  [string] $WeatherNextDataset = "",
  # Prompt for and store LINE / OAuth / Maps / Gemini secrets in Secret Manager.
  [switch] $SetSecrets,
  # Optional: create a billing budget alert on this billing account (e.g. 012345-6789AB-CDEF01).
  [string] $BillingAccount = "",
  [int] $BudgetUsd = 100
)

# ---- helpers ---------------------------------------------------------------

function Invoke-G {
  # Runs gcloud with the project set; throws on failure.
  & gcloud --project $Project @args
  if ($LASTEXITCODE -ne 0) { throw "gcloud $($args -join ' ') failed ($LASTEXITCODE)" }
}

function Test-G {
  # True when a gcloud describe/list call succeeds (resource exists).
  & gcloud --project $Project @args 2>&1 | Out-Null
  return $LASTEXITCODE -eq 0
}

function Confirm-Resource([string] $Label, [scriptblock] $Exists, [scriptblock] $Create) {
  if (& $Exists) { Write-Host "  ok      $Label" -ForegroundColor DarkGray }
  else { Write-Host "  create  $Label" -ForegroundColor Cyan; & $Create }
}

function Grant-ProjectRole([string] $Member, [string] $Role) {
  Invoke-G projects add-iam-policy-binding $Project --member $Member --role $Role --condition=None --quiet | Out-Null
  Write-Host "  grant   $Role -> $Member" -ForegroundColor DarkGray
}

function Read-Plain([string] $Prompt) {
  # Works on Windows PowerShell 5.1 and PowerShell 7.
  $secure = Read-Host -Prompt $Prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Set-Secret([string] $Name, [string] $Value) {
  # WriteAllText writes UTF-8 without BOM and without a trailing newline;
  # piping a string into gcloud from PowerShell would append CRLF.
  $tmp = [IO.Path]::GetTempFileName()
  try {
    [IO.File]::WriteAllText($tmp, $Value)
    if (Test-G secrets describe $Name) { Invoke-G secrets versions add $Name --data-file $tmp | Out-Null }
    else { Invoke-G secrets create $Name --replication-policy automatic --data-file $tmp | Out-Null }
    Write-Host "  stored  secret $Name" -ForegroundColor Cyan
  } finally { Remove-Item $tmp -Force }
}

# ---- 1. APIs ---------------------------------------------------------------

Write-Host "`n[1/7] Enabling APIs" -ForegroundColor Yellow
$apis = @(
  "run.googleapis.com", "cloudbuild.googleapis.com", "artifactregistry.googleapis.com",
  "secretmanager.googleapis.com", "firestore.googleapis.com",
  "aiplatform.googleapis.com", "bigquery.googleapis.com", "analyticshub.googleapis.com",
  "pubsub.googleapis.com", "cloudtasks.googleapis.com",
  "calendar-json.googleapis.com", "gmail.googleapis.com",
  "fcm.googleapis.com", "identitytoolkit.googleapis.com",
  "weather.googleapis.com", "routes.googleapis.com", "places.googleapis.com", "geocoding-backend.googleapis.com",
  "billingbudgets.googleapis.com"
)
Invoke-G services enable @apis

$ProjectNumber = (& gcloud projects describe $Project --format="value(projectNumber)").Trim()
$ApiSA      = "fontokmai-api@$Project.iam.gserviceaccount.com"
$InvokerSA  = "fontokmai-invoker@$Project.iam.gserviceaccount.com"
$PubSubAgent = "service-$ProjectNumber@gcp-sa-pubsub.iam.gserviceaccount.com"

# ---- 2. Service accounts and roles -----------------------------------------

Write-Host "`n[2/7] Service accounts" -ForegroundColor Yellow
Confirm-Resource "SA fontokmai-api" { Test-G iam service-accounts describe $ApiSA } {
  Invoke-G iam service-accounts create fontokmai-api --display-name "fontokmai API (Cloud Run runtime)"
}
Confirm-Resource "SA fontokmai-invoker" { Test-G iam service-accounts describe $InvokerSA } {
  Invoke-G iam service-accounts create fontokmai-invoker --display-name "fontokmai invoker (Pub/Sub push + Cloud Tasks)"
}

foreach ($role in @(
    "roles/aiplatform.user", "roles/datastore.user", "roles/bigquery.jobUser",
    "roles/pubsub.publisher", "roles/cloudtasks.enqueuer", "roles/secretmanager.secretAccessor")) {
  Grant-ProjectRole "serviceAccount:$ApiSA" $role
}

# The API attaches the invoker SA's OIDC token to Cloud Tasks it creates.
Invoke-G iam service-accounts add-iam-policy-binding $InvokerSA `
  --member "serviceAccount:$ApiSA" --role roles/iam.serviceAccountUser --quiet | Out-Null
# Pub/Sub mints OIDC tokens for push subscriptions as the invoker SA.
Invoke-G iam service-accounts add-iam-policy-binding $InvokerSA `
  --member "serviceAccount:$PubSubAgent" --role roles/iam.serviceAccountTokenCreator --quiet | Out-Null

if ($WeatherNextDataset) {
  # Dataset-level read on the WeatherNext linked dataset only.
  & bq add-iam-policy-binding --member="serviceAccount:$ApiSA" --role=roles/bigquery.dataViewer $WeatherNextDataset | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "bq add-iam-policy-binding on $WeatherNextDataset failed" }
  Write-Host "  grant   bigquery.dataViewer on $WeatherNextDataset" -ForegroundColor DarkGray
} else {
  Write-Host "  skip    WeatherNext dataset (re-run with -WeatherNextDataset after Analytics Hub approval)" -ForegroundColor DarkYellow
}

# ---- 3. Firestore, Artifact Registry ---------------------------------------

Write-Host "`n[3/7] Firestore and Artifact Registry" -ForegroundColor Yellow
Confirm-Resource "Firestore (default) in $Region" { Test-G firestore databases describe "--database=(default)" } {
  Invoke-G firestore databases create "--database=(default)" --location $Region --type firestore-native
}
Confirm-Resource "Artifact Registry $Repo" { Test-G artifacts repositories describe $Repo --location $Region } {
  Invoke-G artifacts repositories create $Repo --repository-format docker --location $Region
}

# ---- 4. Pub/Sub topics and Cloud Tasks queue -------------------------------

Write-Host "`n[4/7] Pub/Sub topics and Cloud Tasks" -ForegroundColor Yellow
foreach ($topic in @("raw-messages", "raw-messages-dlq", "gmail-push")) {
  Confirm-Resource "topic $topic" { Test-G pubsub topics describe $topic } { Invoke-G pubsub topics create $topic }
}
Confirm-Resource "subscription raw-messages-dlq-hold" { Test-G pubsub subscriptions describe raw-messages-dlq-hold } {
  # Keeps dead-lettered messages around for inspection.
  Invoke-G pubsub subscriptions create raw-messages-dlq-hold --topic raw-messages-dlq --message-retention-duration 7d
}
# Gmail watch() publishes as this Google-owned account.
Invoke-G pubsub topics add-iam-policy-binding gmail-push `
  --member "serviceAccount:gmail-api-push@system.gserviceaccount.com" --role roles/pubsub.publisher | Out-Null
# Pub/Sub must be able to forward failed messages to the DLQ topic.
Invoke-G pubsub topics add-iam-policy-binding raw-messages-dlq `
  --member "serviceAccount:$PubSubAgent" --role roles/pubsub.publisher | Out-Null

Confirm-Resource "queue proactive-checks" { Test-G tasks queues describe proactive-checks --location $Region } {
  Invoke-G tasks queues create proactive-checks --location $Region --max-attempts 5 --max-dispatches-per-second 10
}

# ---- 5. Secrets ------------------------------------------------------------

Write-Host "`n[5/7] Secrets" -ForegroundColor Yellow
if ($SetSecrets) {
  foreach ($name in @("GOOGLE_MAPS_API_KEY", "LINE_CHANNEL_SECRET", "LINE_CHANNEL_ACCESS_TOKEN",
      "GOOGLE_OAUTH_CLIENT_ID", "GOOGLE_OAUTH_CLIENT_SECRET", "GEMINI_API_KEY")) {
    $value = Read-Plain "$name (leave empty to skip)"
    if ($value) { Set-Secret $name $value } else { Write-Host "  skip    $name" -ForegroundColor DarkGray }
  }
} else {
  Write-Host "  skip    (re-run with -SetSecrets to enter values)" -ForegroundColor DarkGray
}

# ---- 6. Budget -------------------------------------------------------------

Write-Host "`n[6/7] Budget alert" -ForegroundColor Yellow
if ($BillingAccount) {
  $exists = & gcloud billing budgets list --billing-account $BillingAccount `
    --filter "displayName=fontokmai-$Project" --format "value(name)" 2>$null
  if ($exists) { Write-Host "  ok      budget fontokmai-$Project" -ForegroundColor DarkGray }
  else {
    & gcloud billing budgets create --billing-account $BillingAccount `
      --display-name "fontokmai-$Project" --budget-amount "${BudgetUsd}USD" `
      --filter-projects "projects/$Project" `
      --threshold-rule percent=0.5 --threshold-rule percent=0.9 --threshold-rule percent=1.0
    if ($LASTEXITCODE -ne 0) { throw "budget create failed" }
  }
} else {
  Write-Host "  skip    (pass -BillingAccount to create one)" -ForegroundColor DarkGray
}

# ---- 7. Post-deploy wiring (needs the Cloud Run service) --------------------

Write-Host "`n[7/7] Post-deploy wiring" -ForegroundColor Yellow
if (-not (Test-G run services describe $Service --region $Region)) {
  Write-Host "  wait    Cloud Run service $Service not deployed yet." -ForegroundColor DarkYellow
  Write-Host "          Run api\deploy\cloudrun.ps1 -Project $Project, then re-run this script." -ForegroundColor DarkYellow
  return
}
$RunUrl = (& gcloud --project $Project run services describe $Service --region $Region --format="value(status.url)").Trim()

Invoke-G run services add-iam-policy-binding $Service --region $Region `
  --member "serviceAccount:$InvokerSA" --role roles/run.invoker | Out-Null
Write-Host "  grant   run.invoker on $Service -> invoker SA" -ForegroundColor DarkGray

$pushSubs = @(
  @{ Name = "raw-messages-push"; Topic = "raw-messages"; Path = "/internal/pubsub/raw" },
  @{ Name = "gmail-push-sub";    Topic = "gmail-push";   Path = "/internal/pubsub/gmail" }
)
foreach ($s in $pushSubs) {
  Confirm-Resource "push subscription $($s.Name)" { Test-G pubsub subscriptions describe $s.Name } {
    Invoke-G pubsub subscriptions create $s.Name --topic $s.Topic `
      --push-endpoint "$RunUrl$($s.Path)" --push-auth-service-account $InvokerSA `
      --ack-deadline 120 --dead-letter-topic raw-messages-dlq --max-delivery-attempts 5
  }
  # Pub/Sub must be able to ack messages it dead-letters.
  Invoke-G pubsub subscriptions add-iam-policy-binding $s.Name `
    --member "serviceAccount:$PubSubAgent" --role roles/pubsub.subscriber | Out-Null
}

Write-Host "`nDone. Service URL: $RunUrl" -ForegroundColor Green
Write-Host "LINE webhook URL to paste in LINE Developers console: $RunUrl/webhooks/line"
Write-Host "OAuth redirect URI to add in Google Auth Platform:    $RunUrl/oauth/google/callback"
