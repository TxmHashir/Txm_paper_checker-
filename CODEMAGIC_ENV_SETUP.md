# CodeMagic CI/CD Configuration for VisionQR

## Problem

The `.env` file is not committed to version control (for security), so CodeMagic CI/CD builds fail because the file is missing.

## Solution: Configure CodeMagic to Inject .env at Build Time

### **Option 1: Using CodeMagic Environment Variables (RECOMMENDED)**

1. **Go to CodeMagic Dashboard**
   - Navigate to your app
   - Click **Settings** → **Environment variables**

2. **Add Your Secret**
   - Variable name: `GEMINI_API_KEY`
   - Value: `your-actual-gemini-api-key`
   - Check "Secure" to encrypt the value ✓

3. **Create/Use `codemagic.yaml`**

   Add this file to your project root:

   ```yaml
   workflows:
     android-workflow:
       name: Android Build
       instance_type: mac_mini_m2
       environment:
         vars:
           GEMINI_API_KEY: $GEMINI_API_KEY # Reference the secret
       triggers:
         - push
         - pull_request
       scripts:
         - name: Create .env file
           script: |
             echo "GEMINI_API_KEY=$GEMINI_API_KEY" > .env
         - name: Install dependencies
           script: flutter pub get
         - name: Build APK
           script: flutter build apk --release
     ios-workflow:
       name: iOS Build
       instance_type: mac_mini_m2
       environment:
         vars:
           GEMINI_API_KEY: $GEMINI_API_KEY
       triggers:
         - push
       scripts:
         - name: Create .env file
           script: |
             echo "GEMINI_API_KEY=$GEMINI_API_KEY" > .env
         - name: Install dependencies
           script: flutter pub get
         - name: Build iOS
           script: flutter build ios --release
   ```

### **Option 2: Manual Script in CodeMagic UI**

If you don't have `codemagic.yaml`:

1. Go to **Settings** → **Build** → **Pre-build scripts**
2. Add this script:
   ```bash
   echo "GEMINI_API_KEY=$GEMINI_API_KEY" > .env
   ```
3. Place it **BEFORE** the "Flutter packages" step

### **Verify It Works**

After configuring:

1. Commit your changes to Git (including `codemagic.yaml` and `.env.example`)
2. Push to trigger a new build
3. Watch the build logs—you should see "Creating .env file" succeed
4. Build should complete without asset errors

### **Security Checklist**

- ✅ `.env` is in `.gitignore` (not committed)
- ✅ `.env.example` is committed (no secrets, for reference)
- ✅ API key is stored as a CodeMagic environment secret
- ✅ Scripts inject the key at build time only

### **Troubleshooting**

| Error                                       | Fix                                                          |
| ------------------------------------------- | ------------------------------------------------------------ |
| "No file or variants found for asset: .env" | Make sure pre-build script runs BEFORE build                 |
| Build still fails                           | Check CodeMagic environment variables are set                |
| Key not working                             | Verify GEMINI_API_KEY value is correct in CodeMagic settings |

---

**Next Steps:**

1. Create `codemagic.yaml` or update it with the scripts above
2. Set `GEMINI_API_KEY` as an environment variable in CodeMagic
3. Commit and push to trigger a new build
