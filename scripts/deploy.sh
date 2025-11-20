#!/bin/bash

set -e  # Exit on error

# Configuration
PROJECT_ID="my-rd-coe-demo-gen-ai"
REGION="asia-southeast1"
SECRET_NAME="gdrive-refresh-token"
TOKEN_FILE="token.json"

echo "============================================================"
echo "GDrive to GCS Sync - Deployment Script"
echo "============================================================"
echo ""

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found."
    echo "Creating virtual environment..."
    python3 -m venv venv
    echo "✅ Virtual environment created."
    echo ""
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install dependencies if needed
if ! python -c "import google_auth_oauthlib" 2>/dev/null; then
    echo "📦 Installing dependencies..."
    pip install -q -r requirements-local.txt
    echo "✅ Dependencies installed."
    echo ""
fi

# Step 1: Generate token if it doesn't exist
if [ ! -f "$TOKEN_FILE" ]; then
    echo "============================================================"
    echo "Step 1: Generate OAuth Token"
    echo "============================================================"
    echo ""
    echo "⚠️  A browser window will open for authentication."
    echo "Please sign in with your Google account and grant access."
    echo ""
    read -p "Press Enter to continue..."
    
    python scripts/generate_token.py
    
    if [ ! -f "$TOKEN_FILE" ]; then
        echo "❌ Token generation failed. Exiting."
        exit 1
    fi
    echo ""
else
    echo "✅ Token file already exists: $TOKEN_FILE"
    echo ""
fi

# Step 2: Upload token to GCP Secret Manager
echo "============================================================"
echo "Step 2: Upload Token to GCP Secret Manager"
echo "============================================================"
echo ""

# Extract refresh token from token.json
REFRESH_TOKEN=$(python3 -c "import json; print(json.load(open('$TOKEN_FILE'))['refresh_token'])")

# Extract client secret from the OAuth client secret file
CLIENT_SECRET_FILE="client_secret_452883396851-sr8ov1u4bsefdqf3s4sj7nqun3jc2ehi.apps.googleusercontent.com.json"
CLIENT_SECRET=$(python3 -c "import json; print(json.load(open('$CLIENT_SECRET_FILE'))['installed']['client_secret'])")

echo "🔐 Uploading refresh token to Secret Manager..."

# Check if secret exists
if gcloud secrets describe $SECRET_NAME --project=$PROJECT_ID &>/dev/null; then
    echo "Secret already exists. Creating new version..."
    echo -n "$REFRESH_TOKEN" | gcloud secrets versions add $SECRET_NAME \
        --data-file=- \
        --project=$PROJECT_ID
else
    echo "Creating new secret..."
    echo -n "$REFRESH_TOKEN" | gcloud secrets create $SECRET_NAME \
        --data-file=- \
        --project=$PROJECT_ID \
        --replication-policy="automatic"
fi

echo "✅ Token uploaded to Secret Manager: $SECRET_NAME"
echo ""

echo "🔐 Uploading OAuth client secret to Secret Manager..."

# Upload client secret
CLIENT_SECRET_NAME="oauth-client-secret"
if gcloud secrets describe $CLIENT_SECRET_NAME --project=$PROJECT_ID &>/dev/null; then
    echo "Client secret already exists. Creating new version..."
    echo -n "$CLIENT_SECRET" | gcloud secrets versions add $CLIENT_SECRET_NAME \
        --data-file=- \
        --project=$PROJECT_ID
else
    echo "Creating new client secret..."
    echo -n "$CLIENT_SECRET" | gcloud secrets create $CLIENT_SECRET_NAME \
        --data-file=- \
        --project=$PROJECT_ID \
        --replication-policy="automatic"
fi

echo "✅ Client secret uploaded to Secret Manager: $CLIENT_SECRET_NAME"
echo ""

# Step 3: Grant Cloud Run access to the secret
echo "============================================================"
echo "Step 3: Grant Cloud Run Access to Secrets"
echo "============================================================"
echo ""

# Get the default compute service account
COMPUTE_SA="${PROJECT_ID}-compute@developer.gserviceaccount.com"

echo "Granting access to: $COMPUTE_SA"
gcloud secrets add-iam-policy-binding $SECRET_NAME \
    --member="serviceAccount:$COMPUTE_SA" \
    --role="roles/secretmanager.secretAccessor" \
    --project=$PROJECT_ID

gcloud secrets add-iam-policy-binding $CLIENT_SECRET_NAME \
    --member="serviceAccount:$COMPUTE_SA" \
    --role="roles/secretmanager.secretAccessor" \
    --project=$PROJECT_ID

echo "✅ Access granted to both secrets."
echo ""

# Step 4: Grant Cloud Build permission to act as Compute SA
echo "============================================================"
echo "Step 4: Grant Cloud Build Permissions"
echo "============================================================"
echo ""

# Get Cloud Build Service Account
CLOUDBUILD_SA="${PROJECT_ID}@cloudbuild.gserviceaccount.com"

echo "Granting iam.serviceAccountUser to: $CLOUDBUILD_SA"
gcloud iam service-accounts add-iam-policy-binding $COMPUTE_SA \
    --member="serviceAccount:$CLOUDBUILD_SA" \
    --role="roles/iam.serviceAccountUser" \
    --project=$PROJECT_ID

echo "✅ Permission granted."
echo ""

# Step 5: Deploy with Cloud Build
echo "============================================================"
echo "Step 5: Deploy with Cloud Build"
echo "============================================================"
echo ""

echo "🚀 Submitting Cloud Build job..."
gcloud builds submit --config cloudbuild.yaml . --project=$PROJECT_ID

echo ""
echo "============================================================"
echo "✅ Deployment Complete!"
echo "============================================================"
echo ""
echo "Your Google Drive folders are now syncing to GCS buckets."
echo ""
echo "To check the status:"
echo "  gcloud run jobs list --region $REGION --project $PROJECT_ID"
echo ""
echo "To manually trigger a sync:"
echo "  gcloud run jobs execute sync-<folder-name> --region $REGION --project $PROJECT_ID"
echo ""
echo "To view logs:"
echo "  gcloud logging read 'resource.type=cloud_run_job' --limit 50 --project $PROJECT_ID"
echo ""
