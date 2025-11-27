import os
import tempfile
import subprocess
from googleapiclient.discovery import build
from google.cloud import storage
from google.auth import default

# Environment variables from Cloud Run Job
PROJECT_ID = os.getenv("GCP_PROJECT")
DRIVE_FOLDER_ID = os.getenv("DRIVE_FOLDER_ID")
BUCKET_NAME = os.getenv("GCS_BUCKET")

# Authenticate using Cloud Run Job service account
def get_credentials():
    creds, _ = default(scopes=[
        "https://www.googleapis.com/auth/drive.readonly",
    ])
    return creds

creds = get_credentials()
drive = build("drive", "v3", credentials=creds)
gcs = storage.Client()


# -----------------------------------------------------
# Google Drive helpers
# -----------------------------------------------------

def list_drive_files():
    """List files in the Drive folder."""
    resp = drive.files().list(
        q=f"'{DRIVE_FOLDER_ID}' in parents and trashed = false",
        fields="files(id,name,mimeType)",
        supportsAllDrives=True,
        includeItemsFromAllDrives=True
    ).execute()
    return resp.get("files", [])


def download_bytes(file_id):
    """Download raw bytes of any Drive file."""
    return drive.files().get_media(fileId=file_id).execute()


def export_google_to_pdf(file_id):
    """Export Google Docs/Sheets/Slides to PDF."""
    return drive.files().export(
        fileId=file_id,
        mimeType="application/pdf"
    ).execute()


# -----------------------------------------------------
# Office conversion via LibreOffice
# -----------------------------------------------------

def convert_office_to_pdf(binary, filename):
    """Convert DOCX/XLSX using LibreOffice headless."""
    try:
        with tempfile.TemporaryDirectory() as tmp:
            src = os.path.join(tmp, filename)
            out = tmp

            with open(src, "wb") as f:
                f.write(binary)

            subprocess.run(
                ["soffice", "--headless", "--convert-to", "pdf", "--outdir", out, src],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True
            )

            pdf_file = filename.rsplit(".", 1)[0] + ".pdf"
            pdf_path = os.path.join(out, pdf_file)

            with open(pdf_path, "rb") as f:
                return f.read()

    except Exception as e:
        print(f"❌ LibreOffice conversion failed for {filename}: {e}")
        return None


# -----------------------------------------------------
# File processing logic
# -----------------------------------------------------

def process_file(f):
    name = f["name"]
    mime = f["mimeType"]
    fid = f["id"]

    print(f"→ Processing {name} ({mime})")

    # 1. Already PDF → upload directly
    if mime == "application/pdf" or name.lower().endswith(".pdf"):
        raw = download_bytes(fid)
        return raw, name

    # 2. Google Docs / Sheets / Slides
    if mime.startswith("application/vnd.google-apps."):
        print("   Exporting Google Workspace → PDF")
        pdf = export_google_to_pdf(fid)
        return pdf, f"{name}.pdf"

    # 3. Office docs (Word, Excel)
    office_mimes = [
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "application/msword",
        "application/vnd.ms-excel"
    ]
    if mime in office_mimes:
        print("   Converting Office → PDF")
        raw = download_bytes(fid)
        pdf = convert_office_to_pdf(raw, name)
        if pdf:
            return pdf, f"{name}.pdf"

    print(f"   ⚠ Skipping unsupported type: {mime}")
    return None, None


# -----------------------------------------------------
# Main entrypoint
# -----------------------------------------------------

def main():
    print(f"🔍 Checking folder: {DRIVE_FOLDER_ID}")
    print(f"📦 Target bucket: {BUCKET_NAME}")
    
    bucket = gcs.bucket(BUCKET_NAME)
    files = list_drive_files()

    print(f"Found {len(files)} files in folder {DRIVE_FOLDER_ID}")
    
    if len(files) == 0:
        print("⚠️  No files found. Possible reasons:")
        print("   - Folder is empty or only contains subfolders")
        print("   - Folder is in a Shared Drive and needs special permissions")
        print("   - Service account doesn't have access to this specific folder")
        print("   - Folder ID might be incorrect")
        return

    for f in files:
        pdf_bytes, pdf_name = process_file(f)
        if pdf_bytes and pdf_name:
            blob = bucket.blob(pdf_name)
            blob.upload_from_string(pdf_bytes, content_type="application/pdf")
            print(f"   ✅ Uploaded {pdf_name}")
        else:
            print("   → No upload (skipped)")


if __name__ == "__main__":
    main()
