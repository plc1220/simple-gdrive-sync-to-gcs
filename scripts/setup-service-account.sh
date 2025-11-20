#!/bin/bash

# Setup script for GDrive to GCS Sync Platform
# This script creates the necessary service account and grants permissions

PROJECT_ID="my-rd-coe-demo-gen-ai"
SA_NAME="gdrive-sync-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "=== Setting up GDrive Sync Service Account ==="
echo "Project: $PROJECT_ID"
echo "Service Account: $SA_EMAIL"
echo ""

# Create service account
echo "Creating service account..."
gcloud iam service-accounts create $SA_NAME \
    --display-name="GDrive to GCS Sync Service Account" \
    --project=$PROJECT_ID

# Grant necessary permissions
echo "Granting Storage Admin role..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/storage.admin"

echo "Granting Cloud Run Invoker role..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/run.invoker"

echo ""
echo "✅ Service account created successfully!"
echo ""
echo "⚠️  IMPORTANT: You need to grant this service account access to Google Drive:"
echo ""
echo "1. Go to Google Cloud Console > IAM & Admin > Service Accounts"
echo "2. Find: $SA_EMAIL"
echo "3. Enable Domain-Wide Delegation (if using Workspace)"
echo "   OR"
echo "4. Share your Google Drive folders with: $SA_EMAIL"
echo ""
echo "5. For each folder in config.json, share it with the service account email"
echo ""
