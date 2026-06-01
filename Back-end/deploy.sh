#!/usr/bin/env bash
# deploy.sh – Build, push, and deploy the API to Google Cloud Run
# ─────────────────────────────────────────────────────────────────
# Prerequisites:
#   1. gcloud CLI installed and authenticated  (gcloud auth login)
#   2. Docker installed and running
#   3. Artifact Registry repository created    (see REPO_URL below)
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────
PROJECT_ID="risky-pets-8be2e"          # <-- change this
REGION="europe-west3"                       # <-- change to your preferred region
SERVICE_NAME="zoonotic-risk-api"
REPO="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
TAG="${REPO}:latest"

# ── Build & Push ──────────────────────────────────────────────────
echo "🔨  Building Docker image..."
docker build -t "$TAG" .

echo "🚀  Pushing image to Google Container Registry..."
docker push "$TAG"

# ── Deploy to Cloud Run ───────────────────────────────────────────
echo "☁️   Deploying to Cloud Run (region: ${REGION})..."
gcloud run deploy "$SERVICE_NAME" \
  --image "$TAG" \
  --platform managed \
  --region "$REGION" \
  --allow-unauthenticated \
  --min-instances 1 \
  --memory 2Gi \
  --cpu 2 \
  --timeout 60 \
  --set-env-vars MODEL_DIR=./saved_model \
  --project "$PROJECT_ID"

echo "✅  Deployment complete."
gcloud run services describe "$SERVICE_NAME" \
  --platform managed \
  --region "$REGION" \
  --format "value(status.url)"
