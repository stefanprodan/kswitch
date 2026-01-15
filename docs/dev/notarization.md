# Release Notarization Guide

This guide explains how to set up the GitHub secrets required for automated releases of KSwitch.

## Overview

The release workflow requires **5 secrets** to be configured in GitHub:

| Secret                         | Description                                   |
|--------------------------------|-----------------------------------------------|
| `APPLE_CERTIFICATE_P12`        | Developer ID Application certificate (base64) |
| `APPLE_CERTIFICATE_PASSWORD`   | Password for the .p12 file                    |
| `APP_STORE_CONNECT_API_KEY_P8` | App Store Connect API key (base64)            |
| `APP_STORE_CONNECT_KEY_ID`     | API Key ID                                    |
| `APP_STORE_CONNECT_ISSUER_ID`  | Issuer ID                                     |

## Prerequisites

- Apple Developer Program membership
- macOS with Keychain Access
- Access to [Apple Developer Portal](https://developer.apple.com/account)
- Access to [App Store Connect](https://appstoreconnect.apple.com)

---

## Part 1: Developer ID Application Certificate

This certificate is used to sign the app for distribution outside the Mac App Store.

### Step 1.1: Create a Certificate Signing Request (CSR)

1. Open **Keychain Access** on your Mac
2. Go to **Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority**
3. Fill in:
   - **User Email Address**: Your email
   - **Common Name**: Your name
   - **CA Email Address**: Leave empty
   - **Request is**: Select **Saved to disk**
4. Click **Continue** and save the `.certSigningRequest` file

### Step 1.2: Create the Certificate in Apple Developer Portal

1. Go to https://developer.apple.com/account/resources/certificates/list
2. Click the **+** button to create a new certificate
3. Select **Developer ID Application** under "Software"
4. Click **Continue**
5. Upload the CSR file you created in Step 1.1
6. Click **Continue**
7. Download the certificate (`.cer` file)

### Step 1.3: Install the Certificate

1. Double-click the downloaded `.cer` file
2. It will be added to your **login** keychain in Keychain Access
3. Verify: Open Keychain Access → **My Certificates** → look for `Developer ID Application: Your Name (TEAMID)`

### Step 1.4: Export as .p12

1. In Keychain Access, go to **My Certificates**
2. Find `Developer ID Application: Your Name (TEAMID)`
   - It should have a **▶ disclosure triangle** showing a private key underneath
3. Click on the **certificate** (not the key)
4. Go to **File → Export Items** (or right-click → Export)
5. Choose **Personal Information Exchange (.p12)** format
6. Save the file and **enter a password** when prompted
7. Remember this password - you'll need it for `APPLE_CERTIFICATE_PASSWORD`

### Step 1.5: Base64 Encode the .p12

```bash
base64 -i /path/to/certificate.p12 | tr -d '\n' | pbcopy
```

This copies the base64-encoded certificate to your clipboard.

### Step 1.6: Add to GitHub Secrets

1. Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add:
   - **Name**: `APPLE_CERTIFICATE_P12`
   - **Value**: Paste the base64 string (Cmd+V)
4. Add another secret:
   - **Name**: `APPLE_CERTIFICATE_PASSWORD`
   - **Value**: The password you entered when exporting the .p12

---

## Part 2: App Store Connect API Key

This key is used for notarizing the app with Apple.

### Step 2.1: Create an API Key

1. Go to https://appstoreconnect.apple.com/access/integrations/api
2. Click **Keys** tab (or **Generate API Key** if first time)
3. Click the **+** button to create a new key
4. Enter a **Name** (e.g., "GitHub Actions")
5. Select **Developer** access role
6. Click **Generate**

### Step 2.2: Download and Note the Details

After creating the key:

1. **Download the API Key** (`.p8` file)
   - ⚠️ **Important**: You can only download this ONCE! Save it securely.
2. Note the **Key ID** (e.g., `6X3CMK22CY`)
3. Note the **Issuer ID** at the top of the page (UUID format like `12345678-1234-1234-1234-123456789012`)

### Step 2.3: Base64 Encode the .p8

```bash
base64 -i /path/to/AuthKey_XXXXXX.p8 | tr -d '\n' | pbcopy
```

### Step 2.4: Add to GitHub Secrets

Add these three secrets:

| Secret Name                    | Value                           |
|--------------------------------|---------------------------------|
| `APP_STORE_CONNECT_API_KEY_P8` | The base64-encoded .p8 content  |
| `APP_STORE_CONNECT_KEY_ID`     | The Key ID (e.g., `6X3CMK22CY`) |
| `APP_STORE_CONNECT_ISSUER_ID`  | The Issuer ID (UUID)            |

---

## Troubleshooting

### Certificate Troubleshooting

#### Certificate Not Trusted

Download the intermediate certificates from Apple:
- Go to https://www.apple.com/certificateauthority/
- Download "Developer ID - G2 (Expiring 09/17/2031)" (or the current one for Developer ID)
- Double-click each downloaded .cer file to add them to your keychain
- Restart Keychain Access and re-verify the certificate
- Run `security find-identity -v -p codesigning` to check valid identities

#### "Cannot export as .p12" - Only .cer option available

The private key is not associated with the certificate. This happens when:
- The certificate was created on a different Mac
- The private key was deleted

**Solution A**: Find the original Mac where the CSR was created and export from there.

**Solution B**: Create a new certificate:
1. Revoke the old certificate in Apple Developer Portal
2. Create a new CSR on your current Mac
3. Create a new Developer ID Application certificate
4. Export the new certificate as .p12

#### "0 valid identities found" in GitHub Actions

The certificate chain is incomplete. Make sure:
- You're using a **Developer ID Application** certificate (not Mac Developer or Apple Distribution)
- The .p12 contains both the certificate AND private key

### Notarization Troubleshooting

#### "invalidPrivateKeyContents"

The API key is corrupted or incorrectly encoded.

1. Re-download the .p8 file from App Store Connect (if you still can)
2. Re-encode: `base64 -i AuthKey_XXX.p8 | tr -d '\n' | pbcopy`
3. Update the `APP_STORE_CONNECT_API_KEY_P8` secret

#### "Invalid issuer" or authentication errors

Check that:
- `APP_STORE_CONNECT_KEY_ID` matches the Key ID exactly
- `APP_STORE_CONNECT_ISSUER_ID` is the Issuer ID (UUID), not the Key ID
- The API key has **Developer** or **Admin** role

---

### Links

- [Apple Developer Certificates](https://developer.apple.com/account/resources/certificates)
- [App Store Connect API Keys](https://appstoreconnect.apple.com/access/api)
- [Apple Notarization Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
