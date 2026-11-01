# Google Play Release Guide — CyberShield AI

## 1. App Identity & Configuration
- **Package Name / Application ID:** `com.cybershield.ai.security`
- **Minimum Android SDK:** 21 (Android 5.0)
- **Target Android SDK:** 34 (Android 14)
- **Version Code:** 1
- **Version Name:** 1.0.0

## 2. Generating a Release Android App Bundle (.aab)
Run the following command in PowerShell from the project root:
```powershell
flutter build appbundle --release
```
The output AAB file will be located at:
`build/app/outputs/bundle/release/app-release.aab`

## 3. Generating a Signed APK for Testing
```powershell
flutter build apk --release --split-per-abi
```
Outputs will be located at:
`build/app/outputs/flutter-apk/`

## 4. Play Console Checklist
1. **Store Listing:** Provide high-res icon, feature graphic (1024x500), and phone screenshots.
2. **Data Safety Form:** Declare local-first processing, optional k-anonymity checks, and no collection of private messages.
3. **Content Rating:** Complete questionnaire (Utility/Security).
4. **Target Audience:** General consumer audience.
