# Google Drive Authentication Setup Guide

## The Problem

Service accounts **cannot** be shared on personal Google Drive folders because they don't have a Google Account. You'll get this error:

> "Sorry, you cannot share with gdrive-sync-sa@... because they do not have a Google Account."

## Solutions

There are **3 ways** to authenticate with Google Drive:

---

## ✅ Option 1: Use Google Workspace with Domain-Wide Delegation (Recommended for Organizations)

If you're using **Google Workspace** (not personal Gmail):

### Steps:

1. **Create a service account** (already done via `setup-service-account.sh`)

2. **Enable Domain-Wide Delegation**:
   ```bash
   gcloud iam service-accounts update gdrive-sync-sa@my-rd-coe-demo-gen-ai.iam.gserviceaccount.com \
     --project=my-rd-coe-demo-gen-ai
   ```

3. **Get the Client ID**:
   ```bash
   gcloud iam service-accounts describe gdrive-sync-sa@my-rd-coe-demo-gen-ai.iam.gserviceaccount.com \
     --project=my-rd-coe-demo-gen-ai \
     --format='value(oauth2ClientId)'
   ```

4. **In Google Workspace Admin Console**:
   - Go to: Security > API Controls > Domain-wide Delegation
   - Add new API client
   - Client ID: (from step 3)
   - OAuth Scopes: `https://www.googleapis.com/auth/drive.readonly`

5. **Update `main.py`** to impersonate a user (see below)

---

## ✅ Option 2: Make Drive Folder Publicly Accessible (Easiest for Testing)

### Steps:

1. **Open your Google Drive folder** (`lc-test`)

2. **Click "Share"**

3. **Change access to "Anyone with the link"**:
   - Set to: **Viewer**
   - Copy the link

4. **No code changes needed** - the service account can now access it

⚠️ **Warning**: This makes your folder publicly accessible. Only use for non-sensitive data.

---

## ✅ Option 3: Use OAuth 2.0 User Credentials (For Personal Google Drive)

This is the most complex but works with personal Gmail accounts.

### Steps:

1. **Create OAuth 2.0 Credentials**:
   - Go to: [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
   - Create OAuth 2.0 Client ID
   - Application type: Desktop app
   - Download the JSON file

2. **Generate a refresh token** (run locally):
   ```bash
   pip install google-auth-oauthlib google-auth-httplib2 google-api-python-client
   ```

   Create `generate_token.py`:
   ```python
   from google_auth_oauthlib.flow import InstalledAppFlow
   import json

   SCOPES = ['https://www.googleapis.com/auth/drive.readonly']
   
   flow = InstalledAppFlow.from_client_secrets_file(
       'client_secret.json', SCOPES)
   creds = flow.run_local_server(port=0)
   
   print("Refresh Token:", creds.refresh_token)
   ```

   Run it:
   ```bash
   python generate_token.py
   ```

3. **Store the refresh token as a Secret**:
   ```bash
   echo -n "YOUR_REFRESH_TOKEN" | gcloud secrets create gdrive-refresh-token \
     --data-file=- \
     --project=my-rd-coe-demo-gen-ai
   ```

4. **Update Cloud Run Job to use the secret** (in `cloudbuild.yaml`)

---

## 🚀 Recommended Approach

For **personal Google Drive** (easiest):
- Use **Option 2** (make folder publicly accessible with link)

For **Google Workspace**:
- Use **Option 1** (domain-wide delegation)

For **production with personal accounts**:
- Use **Option 3** (OAuth with refresh tokens)

---

## Quick Test: Option 2 (Public Link)

1. Open your folder: https://drive.google.com/drive/folders/1WWEkIfKdXNznkHGc0_VheWuE9Sqz7rSS

2. Click "Share" → "Anyone with the link" → "Viewer"

3. Re-run Cloud Build:
   ```bash
   gcloud builds submit --config cloudbuild.yaml .
   ```

This should work immediately without any code changes!
