#!/usr/bin/env bash
# Deploy the ฝนตกไหม API to Cloud Run (asia-southeast1).
#
#   PROJECT=my-project api/deploy/cloudrun.sh            # build with Cloud Build from source
#   PROJECT=my-project BUILD=docker api/deploy/cloudrun.sh  # build locally, push to Artifact Registry
#
# One-time setup the script does for you (idempotent): enable APIs, create the
# Artifact Registry repo (docker mode), and give the runtime service account
# access to the GEMINI_API_KEY secret. Create the secret yourself first:
#
#   printf '%s' "$GEMINI_API_KEY" | gcloud secrets create GEMINI_API_KEY --data-file=- --project "$PROJECT"
#
# Optional env: SERVICE, REGION, DEMO_MODE (1), REPORT_STORE (memory|firestore),
# GEMINI_MODEL, GOOGLE_MAPS_SECRET (name of a secret holding GOOGLE_MAPS_API_KEY).
set -euo pipefail

: "${PROJECT:?set PROJECT to your Google Cloud project id}"
SERVICE="${SERVICE:-fontokmai-api}"
REGION="${REGION:-asia-southeast1}"
BUILD="${BUILD:-source}"
REPO="${REPO:-fontokmai}"
DEMO_MODE="${DEMO_MODE:-1}"
REPORT_STORE="${REPORT_STORE:-memory}"
GEMINI_MODEL="${GEMINI_MODEL:-gemini-2.5-flash}"
GEMINI_SECRET="${GEMINI_SECRET:-GEMINI_API_KEY}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
gc() { gcloud --project "$PROJECT" "$@"; }

apis=(run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com)
[[ "$REPORT_STORE" == firestore ]] && apis+=(firestore.googleapis.com)
[[ -n "${GOOGLE_MAPS_SECRET:-}" ]] && apis+=(weather.googleapis.com routes.googleapis.com places.googleapis.com geocoding-backend.googleapis.com)
gc services enable "${apis[@]}"

gc secrets describe "$GEMINI_SECRET" >/dev/null 2>&1 || {
  echo "secret $GEMINI_SECRET not found; create it first (see the header of this script)" >&2
  exit 1
}
PROJECT_NUMBER="$(gc projects describe "$PROJECT" --format='value(projectNumber)')"
RUNTIME_SA="${RUNTIME_SA:-$PROJECT_NUMBER-compute@developer.gserviceaccount.com}"
gc secrets add-iam-policy-binding "$GEMINI_SECRET" --member "serviceAccount:$RUNTIME_SA" \
  --role roles/secretmanager.secretAccessor >/dev/null
if [[ "$REPORT_STORE" == firestore ]]; then
  gc firestore databases describe --database='(default)' >/dev/null 2>&1 ||
    gc firestore databases create --database='(default)' --location "$REGION"
  gc projects add-iam-policy-binding "$PROJECT" --member "serviceAccount:$RUNTIME_SA" \
    --role roles/datastore.user --condition=None >/dev/null
fi

secrets="GEMINI_API_KEY=$GEMINI_SECRET:latest"
if [[ -n "${GOOGLE_MAPS_SECRET:-}" ]]; then
  secrets+=",GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_SECRET:latest"
fi
envs="DEMO_MODE=$DEMO_MODE,REPORT_STORE=$REPORT_STORE,GEMINI_MODEL=$GEMINI_MODEL,GOOGLE_CLOUD_PROJECT=$PROJECT"

common=(--region "$REGION" --allow-unauthenticated --port 8080 --memory 512Mi --cpu 1
  --min-instances 0 --max-instances 3 --timeout 120
  --set-env-vars "$envs" --set-secrets "$secrets")

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
echo "smoke test: curl -s $URL/healthz && curl -s $URL/v1/places"
