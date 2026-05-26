# Expenses Tracker

Simple Flutter app to record personal transactions in Cloud Firestore. It ships with three tabs:

- **Add** – create a transaction with note, amount, and date/time pickers
- **History** – browse, edit, or delete saved transactions ordered by newest first
- **Summary** – current-month totals, counts, and per-day breakdown

## Getting Started

1. **Install Flutter & Firebase CLI**
   - Ensure Flutter 3.24+ (`flutter --version`) is available.
   - Install the Firebase CLI if you plan to run `flutterfire configure`.

2. **Create a Firebase project**
   - Enable **Cloud Firestore** in *test* or *production* mode.
   - Add your iOS/Android/Web app(s) to the Firebase project.
   - Download the native config files (`google-services.json`, `GoogleService-Info.plist`) and place them under the default platform locations, or run `flutterfire configure` to generate `firebase_options.dart` for web/desktop targets.

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

Firestore collection used: `transactions` with fields `note (String)`, `amount (double)`, `timestamp (Timestamp)`, `createdAt (Timestamp)`, `updatedAt (Timestamp)`. Offline persistence is enabled automatically after Firebase initialization.

## Deploy to GitHub Pages

This repository includes a GitHub Actions workflow at `.github/workflows/deploy-web.yml`.
After the project is pushed to GitHub, enable Pages with **Settings > Pages > Build and deployment > Source > GitHub Actions**.

For a one-off local web build, run:

```bash
flutter build web --release --base-href /expenses/
```

Use `/` instead of `/expenses/` only if the repository is named `<your-user>.github.io`.
