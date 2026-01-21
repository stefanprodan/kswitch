# Release Guide

This guide explains how to set up signing and notarization credentials
and how to release KSwitch using `make release`.

## Prerequisites

- Apple Developer Program membership
- macOS with Keychain Access
- GitHub CLI (`gh`) installed and authenticated
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

### Step 1.4: Get the Signing Identity Name

1. Run this command to list valid code signing identities:

```bash
security find-identity -v -p codesigning
```

2. Find the identity that starts with `Developer ID Application:`
3. Copy the full name (e.g., `Developer ID Application: Your Name (TEAMID)`)

### Step 1.5: Set the Environment Variable

```bash
export APPLE_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
```

---

## Part 2: App Store Connect API Key

This key is used for notarizing the app with Apple.

### Step 2.1: Create an API Key

1. Go to https://appstoreconnect.apple.com/access/integrations/api
2. Click **Keys** tab (or **Generate API Key** if first time)
3. Click the **+** button to create a new key
4. Enter a **Name** (e.g., "KSwitch Release")
5. Select **Developer** access role
6. Click **Generate**

### Step 2.2: Download and Note the Details

After creating the key:

1. **Download the API Key** (`.p8` file)
   - **Important**: You can only download this ONCE! Save it securely.
2. Note the **Key ID** (e.g., `6X3CMK22CY`)
3. Note the **Issuer ID** at the top of the page (UUID format like `12345678-1234-1234-1234-123456789012`)
4. Store the `.p8` file in a secure location (e.g., `~/.appstoreconnect/AuthKey_XXXXXX.p8`)

### Step 2.3: Set the Environment Variables

```bash
export APP_STORE_CONNECT_API_KEY_PATH="$HOME/.appstoreconnect/AuthKey_XXXXXX.p8"
export APP_STORE_CONNECT_KEY_ID="6X3CMK22CY"
export APP_STORE_CONNECT_ISSUER_ID="12345678-1234-1234-1234-123456789012"
```

---

## Part 3: Sparkle EdDSA Key

This key is used to sign the appcast.xml for Sparkle auto-updates.

### Step 3.1: Build the App

First, build the app to download Sparkle as a dependency:

```bash
make build
```

### Step 3.2: Generate a Key Pair

Generate the EdDSA key pair:

```bash
swift package --package-path .build/checkouts/Sparkle generate-keys
```

This outputs a **private key** and a **public key**.

### Step 3.3: Update the Public Key

Update `SPARKLE_PUBLIC_KEY` in `Makefile` with the generated public key.

### Step 3.4: Set the Environment Variable

```bash
export SPARKLE_PRIVATE_KEY="your-private-key-here"
```

---

## Running the Release

### Step 1: Set Environment Variables

Ensure these variables are set (see Parts 1-3 above):

| Environment Variable             | Description                                      |
|----------------------------------|--------------------------------------------------|
| `APPLE_SIGNING_IDENTITY`         | Code signing identity name from Keychain         |
| `APP_STORE_CONNECT_API_KEY_PATH` | Path to App Store Connect API key (.p8 file)     |
| `APP_STORE_CONNECT_KEY_ID`       | API Key ID                                       |
| `APP_STORE_CONNECT_ISSUER_ID`    | Issuer ID                                        |
| `SPARKLE_PRIVATE_KEY`            | EdDSA private key for Sparkle appcast signing    |

### Step 2: Run the Release

```bash
make release APP_VERSION=1.0.0
```

This will:
1. Validate git state (must be on `main` with no uncommitted changes)
2. Create and push a signed git tag (`v1.0.0`)
3. Build, sign, and notarize the app
4. Create distribution files (ZIP + DMG with checksums)
5. Generate `appcast.xml` for Sparkle updates
6. Create a GitHub release with all assets

---

## Links

- [Apple Developer Certificates](https://developer.apple.com/account/resources/certificates)
- [App Store Connect API Keys](https://appstoreconnect.apple.com/access/api)
- [Apple Notarization Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
