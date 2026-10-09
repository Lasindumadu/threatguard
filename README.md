# ThreatGuard

ThreatGuard is a Flutter-based communication threat analysis application designed to detect suspicious, phishing, scam, spam, and social-engineering patterns in messages.

The project combines a rule-based threat analysis engine with a lightweight machine-learning classifier and a hybrid decision layer. It also includes Android SMS integration for analyzing messages from the device SMS inbox.

## Current Features

* Rule-based communication threat detection
* Threat classification:

  * Likely legitimate
  * Spam
  * Phishing
  * Scam
  * Social engineering
* Risk scoring and threat indicators
* URL extraction and structural analysis
* Detection of suspicious URL characteristics
* Unicode and simple obfuscation-aware text matching
* Machine-learning feature extraction and classification
* Hybrid rule + machine-learning analysis
* Android SMS inbox integration
* SMS permission handling
* Sender and organization analysis
* Organization URL consistency checks
* Local URL reputation analysis
* Optional online URL reputation infrastructure for future integration

## Technology

* Flutter
* Dart
* Android
* Kotlin
* Rule-based threat analysis
* Lightweight machine-learning classification

## Project Status

ThreatGuard is an active research and development project.

The current evaluation dataset is a curated benchmark used to test the detection engine. Its results should not be interpreted as evidence of real-world detection accuracy or complete protection against all threats.

Online threat-intelligence integrations are currently treated as optional future infrastructure. The current core analysis can operate without a network connection.

## Development Environment

The project is developed and tested with:

* Flutter 3.47.4
* Dart 3.13.3
* Android Studio
* Android SDK

## Running the Project

Install Flutter and the required Android development tools, then run:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

For a connected Android device, make sure USB debugging is enabled and the device is recognized by Flutter.

## Project Structure

```text
lib/
├── core/
│   ├── models/
│   └── services/
├── features/
│   └── analyzer/
│   └── sms/
└── main.dart

test/
└── Unit and integration tests
```

## Disclaimer

ThreatGuard is a security analysis and research project. Detection results are advisory and may contain false positives or false negatives. Users should not rely on the application as the sole protection against phishing, scams, malware, or other security threats.
