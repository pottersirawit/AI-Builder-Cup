#!/usr/bin/env bash
# Deploy the ฝนตกไหม API to Cloud Run (asia-southeast1).
#
#   PROJECT=my-project api/deploy/cloudrun.sh            # build with Cloud Build from source
#   PROJECT=my-project BUILD=docker api/deploy/cloudrun.sh  # build locally, push to Artifact Registry
#
# It UPDATES the service: env vars and secrets it does not name are kept, so
# the production config (Gemini on Vertex AI, Firestore, Cloud Tasks, Pub/Sub,
# LINE, the Maps key, the runtime service account) survives a redeploy.
# Gemini runs on Vertex AI through GOOGLE_CLOUD_PROJECT; a GEMINI_API_KEY
# secret is mounted only if one exists. See docs/DEPLOY.md.
#
# Optional env: SERVICE, REGION, DEMO_MODE (0; set 1 for the scripted มิว demo),
# REPORT_STORE (memory|firestore) and GEMINI_MODEL (left as deployed unless
# set), GOOGLE_MAPS_SECRET (name of a secret holding GOOGLE_MAPS_API_KEY),
# APP_URL (the Hosting site the Google sign-in returns to), OAUTH_REDIRECT_URI.
# GOOGLE_OAUTH_CLIENT_ID and GOOGLE_OAUTH_CLIENT_SECRET are mounted when those
# secrets exist.
#
# Exactly one always-on instance: Google sign-ins live in its memory, so a
# second instance or a cold start would lose them.
set -euo pipefail

: "${PROJECT:?set PROJECT to your Google Cloud project id}"
SERVICE="${SERVICE:-fontokmai-api}"
REGION="${REGION:-asia-southeast1}"
BUILD="${BUILD:-source}"
REPO="${REPO:-fontokmai}"
DEMO_MODE="${DEMO_MODE:-0}"
REPORT_STORE="${REPORT_STORE:-}"
GEMINI_MODEL="${GEMINI_MODEL:-}"
GEMINI_SECRET="${GEMINI_SECRET:-GEMINI_API_KEY}"
APP_URL="${APP_URL:-https://ai-cup-511208.web.app}"
OAUTH_REDIRECT_URI="${OAUTH_REDIRECT_URI:-https://fontokmai-api-lmr33aj5zq-as.a.run.app/oauth2callback}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
gc() { gcloud --project "$PROJECT" "$@"; }

apis=(run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com)
[[ "$REPORT_STORE" == firestore ]] && apis+=(firestore.googleapis.com)
[[ -n "${GOOGLE_MAPS_SECRET:-}" ]] && apis+=(weather.googleapis.com routes.googleapis.com places.googleapis.com geocoding-backend.googleapis.com)
gc services enable "${apis[@]}"

PROJECT_NUMBER="$(gc projects describe "$PROJECT" --format='value(projectNumber)')"
# Grant secrets to the account the service already runs as.
DEPLOYED_SA="$(gc run services describe "$SERVICE" --region "$REGION" \
  --format='value(spec.template.spec.serviceAccountName)' 2>/dev/null || true)"
RUNTIME_SA="${RUNTIME_SA:-${DEPLOYED_SA:-$PROJECT_NUMBER-compute@developer.gserviceaccount.com}}"
if [[ "$REPORT_STORE" == firestore ]]; then
  gc firestore databases describe --database='(default)' >/dev/null 2>&1 ||
    gc firestore databases create --database='(default)' --location "$REGION"
  gc projects add-iam-policy-binding "$PROJECT" --member "serviceAccount:$RUNTIME_SA" \
    --role roles/datastore.user --condition=None >/dev/null
fi

secrets=""
if gc secrets describe "$GEMINI_SECRET" >/dev/null 2>&1; then
  gc secrets add-iam-policy-binding "$GEMINI_SECRET" --member "serviceAccount:$RUNTIME_SA" \
    --role roles/secretmanager.secretAccessor >/dev/null
  secrets="GEMINI_API_KEY=$GEMINI_SECRET:latest"
fi
if [[ -n "${GOOGLE_MAPS_SECRET:-}" ]]; then
  secrets+=",GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_SECRET:latest"
fi
for name in GOOGLE_OAUTH_CLIENT_ID GOOGLE_OAUTH_CLIENT_SECRET; do
  if gc secrets describe "$name" >/dev/null 2>&1; then
    gc secrets add-iam-policy-binding "$name" --member "serviceAccount:$RUNTIME_SA" \
      --role roles/secretmanager.secretAccessor >/dev/null
    secrets+=",$name=$name:latest"
  fi
done
envs="DEMO_MODE=$DEMO_MODE,GOOGLE_CLOUD_PROJECT=$PROJECT"
envs+=",APP_URL=$APP_URL,OAUTH_REDIRECT_URI=$OAUTH_REDIRECT_URI"
[[ -n "$REPORT_STORE" ]] && envs+=",REPORT_STORE=$REPORT_STORE"
[[ -n "$GEMINI_MODEL" ]] && envs+=",GEMINI_MODEL=$GEMINI_MODEL"

common=(--region "$REGION" --allow-unauthenticated --port 8080 --memory 512Mi --cpu 1
  --min-instances 1 --max-instances 1 --no-cpu-throttling --timeout 120
  --update-env-vars "$envs")
[[ -n "$secrets" ]] && common+=(--update-secrets "${secrets#,}")

case "$BUILD" in
source)
  # The Dockerfile builds from the repo root (it needs data/), so stage only
  # what the image needs instead of uploading the whole repo (Flutter app etc.).
  ctx="$(mktemp -d)"
  trap 'rm -rf "$ctx"' EXIT
  mkdir -p "$ctx/data"
  rsync -a --exclude '.*' "$ROOT/api" "$ctx/"
  cp "$ROOT/data/bkk_flood_risk_points.json" "$ROOT/data/bkk_landmarks.json" "$ctx/data/"
  cp "$ROOT/api/Dockerfile" "$ctx/Dockerfile"
  gc run deploy "$SERVICE" --source "$ctx" "${common[@]}"
  ;;
docker)
  IMAGE="$REGION-docker.pkg.dev/$PROJECT/$REPO/api:$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || date +%s)"
  gc artifacts repositories describe "$REPO" --location "$REGION" >/dev/null 2>&1 ||
    gc artifacts repositories create "$REPO" --repository-format docker --location "$REGION"
  gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet
  docker build --platform linux/amd64 -f "$ROOT/api/Dockerfile" -t "$IMAGE" "$ROOT"
  docker push "$IMAGE"
  gc run deploy "$SERVICE" --image "$IMAGE" "${common[@]}"
  ;;
*)
  echo "BUILD must be source or docker, got $BUILD" >&2
  exit 1
  ;;
esac

URL="$(gc run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
echo "deployed: $URL"
echo "smoke test: curl -s $URL/v1/healthz && curl -s $URL/v1/places"
