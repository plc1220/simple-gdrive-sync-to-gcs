#!/usr/bin/env python3
"""
Generate OAuth refresh token for Google Drive access.
This script will open a browser window for authentication.
"""

import os
import json
from google_auth_oauthlib.flow import InstalledAppFlow

# Define the scopes needed
SCOPES = [
    'https://www.googleapis.com/auth/drive.readonly',
    'https://www.googleapis.com/auth/devstorage.full_control'
]

# Path to the client secret file
CLIENT_SECRET_FILE = 'client_secret_452883396851-sr8ov1u4bsefdqf3s4sj7nqun3jc2ehi.apps.googleusercontent.com.json'

def generate_token():
    """Generate and save the refresh token."""
    
    if not os.path.exists(CLIENT_SECRET_FILE):
        print(f"❌ Error: Client secret file not found: {CLIENT_SECRET_FILE}")
        print("Please ensure the OAuth client secret JSON file is in the current directory.")
        return None
    
    print("🔐 Starting OAuth flow...")
    print("A browser window will open for authentication.")
    print("")
    
    try:
        # Create the flow using the client secrets file
        flow = InstalledAppFlow.from_client_secrets_file(
            CLIENT_SECRET_FILE, 
            SCOPES
        )
        
        # Run the local server to get credentials
        creds = flow.run_local_server(port=0)
        
        # Save the credentials to a file
        token_data = {
            'refresh_token': creds.refresh_token,
            'token': creds.token,
            'client_id': creds.client_id,
            'client_secret': creds.client_secret,
            'scopes': creds.scopes
        }
        
        with open('token.json', 'w') as token_file:
            json.dump(token_data, token_file, indent=2)
        
        print("")
        print("✅ Authentication successful!")
        print("")
        print("📝 Token saved to: token.json")
        print("")
        print("🔑 Refresh Token:")
        print(creds.refresh_token)
        print("")
        
        return creds.refresh_token
        
    except Exception as e:
        print(f"❌ Error during authentication: {e}")
        return None

if __name__ == '__main__':
    print("=" * 60)
    print("Google Drive OAuth Token Generator")
    print("=" * 60)
    print("")
    
    refresh_token = generate_token()
    
    if refresh_token:
        print("=" * 60)
        print("Next steps:")
        print("1. The token has been saved to token.json")
        print("2. Run the deployment script to upload to GCP Secrets")
        print("=" * 60)
    else:
        print("❌ Token generation failed.")
        exit(1)
