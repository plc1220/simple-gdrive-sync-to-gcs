# Google Drive → PDF → GCS Sync Platform

A fully automated pipeline that:

- Reads **multiple Google Drive folders**
- Converts all supported files to **PDF**
- Uploads them into **dedicated GCS buckets**
- Uses **Cloud Run Jobs** for scalable, per-folder sync tasks
- Deploys automatically via **Cloud Build**

Perfect for **Vertex AI Search / Datastore ingestion**, archiving, or enterprise document pipelines.

---

# 📦 Architecture Overview

```
config.json               cloudbuild.yaml
     │                           │
     ▼                           ▼
┌──────────────┐        ┌──────────────────────────┐
│ Folder list  │        │ Cloud Build Orchestration│
└──────────────┘        └──────────────┬───────────┘
                                       │
                          For each Drive folder:
                                       │
                                       ▼
                    ┌──────────────────────────────────┐
                    │  Create Bucket: gs://mediaprima-<name> │
                    │  Deploy Cloud Run Job: sync-<name>     │
                    │  Execute job immediately               │
                    └─────────────────┬──────────────────────┘
                                      │
                                      ▼
                      ┌────────────────────────────────┐
                      │  Cloud Run Job (Python + LO)    │
                      │─────────────────────────────────│
                      │  - Google Workspace → PDF        │
                      │  - XLS/DOC → PDF (LibreOffice)   │
                      │  - Existing PDFs → upload         │
                      │  - Unsupported types skipped      │
                      └──────────────────────────────────┘
                                      │
                                      ▼
                          ┌──────────────────────┐
                          │ Dedicated GCS Bucket │
                          └──────────────────────┘
```

---

# ⚙️ How It Works

1. Admin updates folder configuration:

```json
{
  "folders": [
    { "name": "finance", "id": "12ABC123..." },
    { "name": "hr", "id": "2zfAEx..." }
  ]
}
```

2. Trigger Cloud Build:

```bash
gcloud builds submit --config cloudbuild.yaml .
```

3. Cloud Build will:

- Sanitize folder names  
- Create **one GCS bucket per folder**:

```
gs://mediaprima-finance/
gs://mediaprima-hr/
```

- Deploy a Cloud Run Job per folder:

```
sync-finance
sync-hr
```

- Execute each job immediately

4. Cloud Run Job will:

- List files in the Drive folder  
- Convert files → PDF using the correct pipeline:
  - Google Docs / Sheets / Slides → Drive export
  - XLS / XLSX / DOC / DOCX → LibreOffice
  - PDF → pass-through
- Upload PDF into the folder’s dedicated bucket

---

# 📁 Repository Structure

```
.
├── cloudbuild.yaml
├── cloudrun-job/
│   ├── Dockerfile
│   ├── main.py
│   └── requirements.txt
├── config/
│   └── config.json
└── scripts/
    └── setup-service-account.sh
```

---

# 🚨 Requirements

### Enable required APIs:

```bash
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  drive.googleapis.com \
  secretmanager.googleapis.com
```

### Service Account Permissions

The Cloud Run Job service account (default: **gdrive-sync-sa**) must have:

| Permission | Role |
|-----------|------|
| Access to Google Drive folder | Share folder → Viewer |
| Write to GCS buckets | `roles/storage.objectAdmin` |
| Run Jobs | `roles/run.invoker` |
| Cloud Client Libraries | `roles/iam.serviceAccountUser` |

---

# 🚀 Deployment Instructions

## 1. One-time setup

### Create the service account:

```bash
gcloud iam service-accounts create gdrive-sync-sa \
  --project=my-rd-coe-demo-gen-ai
```

### Grant required IAM roles:

```bash
gcloud projects add-iam-policy-binding my-rd-coe-demo-gen-ai \
  --member="serviceAccount:gdrive-sync-sa@my-rd-coe-demo-gen-ai.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

gcloud projects add-iam-policy-binding my-rd-coe-demo-gen-ai \
  --member="serviceAccount:gdrive-sync-sa@my-rd-coe-demo-gen-ai.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding my-rd-coe-demo-gen-ai \
  --member="serviceAccount:gdrive-sync-sa@my-rd-coe-demo-gen-ai.iam.gserviceaccount.com" \
  --role="roles/run.invoker"
```

### 2. **Share Google Drive folders with the service account**

For **every** folder listed in `config/config.json`:

- Open Google Drive  
- Right-click the folder → **Share**
- Add:

```
gdrive-sync-sa@my-rd-coe-demo-gen-ai.iam.gserviceaccount.com
```

- Give **Viewer** access  
- Click **Send**

> ⚠️ If you skip this step, Cloud Run cannot read the files.

---

# 🚢 Deploy the Platform

```bash
gcloud builds submit --config cloudbuild.yaml .
```

Cloud Build will:

- Build the Docker image  
- Create buckets  
- Deploy Cloud Run Jobs  
- Execute them immediately to sync files  

---

# 🔄 Manual Sync

Re-run a specific folder sync:

```bash
gcloud run jobs execute sync-finance \
  --region asia-southeast1 \
  --project my-rd-coe-demo-gen-ai
```

---

# 🧩 Supported Conversions

| File Type | Behavior |
|-----------|----------|
| Google Docs / Sheets / Slides | Export via Drive → PDF |
| PDF | Upload as-is |
| XLS / XLSX / DOC / DOCX | LibreOffice → PDF |
| Images | (optional: add conversion later) |
| Others | Skipped |

---

# 🎉 Done!

You now have a **production-ready, multi-folder, scalable document ingestion pipeline** that:

- Auto-provisions Cloud Run Jobs  
- Auto-creates per-folder GCS buckets  
- Converts everything to PDF cleanly  
- Integrates with Vertex AI Search  
- Uses stable service-account Drive access  
- Is configurable and extensible  
