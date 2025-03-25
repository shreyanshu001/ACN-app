# acn
# ACN Project Analysis

Below is a well-structured `README.md` file for your ACN (Agent Collaboration Network) Flutter project. It includes a project description, features, setup instructions, and usage details. You can save this as `README.md` in your project root directory (`acn/`).

---

# ACN - Agent Collaboration Network

ACN (Agent Collaboration Network) is a mobile application built with **Flutter** and **Firebase**, designed exclusively for real estate agents. It facilitates collaboration by allowing agents to share property inventories, post client requirements, and connect seamlessly to close deals efficiently. Whether you're a buyer agent searching for exclusive listings or a seller agent looking to match properties with potential buyers, ACN provides a verified, professional network for streamlined transactions.

## Features

- **Agent Authentication & Verification**:
  - Secure sign-up and login using Firebase Authentication (Email/Password).
  - Agent profiles stored in Firestore with a verification flag (manual verification pending).

- **Inventory Sharing**:
  - Seller agents can upload property listings with details like price, location, and images.
  - Listings are stored in Firestore, with images in Firebase Storage.

- **Requirement Posting**:
  - Buyer agents can post client needs (e.g., budget, location).
  - Requirements are saved in Firestore for easy matching.

- **Dashboard**:
  - A simple home screen to navigate between sharing inventory, posting requirements, and logging out.

- **Real-Time Backend**:
  - Powered by Firebase Firestore for real-time data updates and Firebase Storage for media.

- **Scalability**:
  - Serverless architecture with Firebase ensures scalability as the user base grows.

## Tech Stack

- **Flutter**: Cross-platform framework for iOS and Android development.
- **Firebase**:
  - **Authentication**: Secure login and sign-up.
  - **Firestore**: Real-time database for agents, inventories, and requirements.
  - **Storage**: Image and file uploads for property listings.
  - **Cloud Messaging**: (Optional, not implemented) For push notifications.

## Project Structure

```
acn/
├── android/                # Android-specific files
├── ios/                    # iOS-specific files
├── lib/
│   ├── screens/           # UI screens
│   │   ├── login_screen.dart
│   │   ├── home_screen.dart
│   │   ├── inventory_screen.dart
│   │   ├── requirements_screen.dart
│   ├── main.dart          # App entry point
│   ├── firebase_options.dart  # Firebase configuration (auto-generated)
├── pubspec.yaml           # Dependencies and project config
├── README.md              # This file
```

## Prerequisites

- **Flutter SDK**: [Install Flutter](https://flutter.dev/docs/get-started/install).
- **Firebase Account**: Create a project at [Firebase Console](https://console.firebase.google.com).
- **Editor**: VS Code or Android Studio with Flutter/Dart plugins.
- **Emulator/Device**: Android Emulator (via Android Studio) or iOS Simulator (via Xcode).

## Setup Instructions

### 1. Clone the Repository
```bash
git clone <repository-url>
cd acn
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Firebase
1. **Create Firebase Project**:
   - Go to [Firebase Console](https://console.firebase.google.com), create a project named "ACN".
   - Enable Authentication (Email/Password), Firestore, and Storage.

2. **Add Firebase to Flutter**:
   - Install Firebase CLI:
     ```bash
     npm install -g firebase-tools
     firebase login
     ```
   - Configure FlutterFire:
     ```bash
     dart pub global activate flutterfire_cli
     flutterfire configure
     ```
     - Select "ACN" project and generate `firebase_options.dart`.

3. **Platform Setup**:
   - **Android**:
     - Download `google-services.json` from Firebase and place it in `android/app/`.
     - Update `android/build.gradle` and `android/app/build.gradle` (see code comments).
   - **iOS**:
     - Download `GoogleService-Info.plist` and add it to `ios/Runner/` via Xcode.

### 4. Set Permissions
- **Android** (`android/app/src/main/AndroidManifest.xml`):
  ```xml
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
  ```
- **iOS** (`ios/Runner/Info.plist`):
  ```xml
  <key>NSPhotoLibraryUsageDescription</key>
  <string>Allow access to upload property images</string>
  ```

### 5. Run the App
- Start an emulator/simulator.
- Run:
  ```bash
  flutter run
  ```

## Functionality

### Authentication
- **Sign Up**: New agents register with email/password; a Firestore document is created with `verified: false`.
- **Login**: Existing agents log in to access the dashboard.

### Home Screen
- Navigate to:
  - **Share Inventory**: Upload property listings.
  - **Post Requirements**: Add client needs.
  - **Logout**: Sign out of the app.

### Inventory Sharing
- Input price, location, and pick an image from the gallery.
- Data is saved to Firestore, and images are uploaded to Storage.

### Requirement Posting
- Input budget and location.
- Requirements are stored in Firestore for matching with inventories.

## Future Enhancements
- Add a screen to browse inventories and requirements with real-time updates.
- Implement in-app messaging with Firebase Cloud Messaging.
- Enhance UI with animations and better styling.
- Add deal closure functionality with document uploads.

## Troubleshooting
- **Dependency Issues**: Run `flutter clean` and `flutter pub get`.
- **Firebase Errors**: Verify `firebase_options.dart` and platform config files.
- **Permissions**: Ensure storage permissions are granted on the device/emulator.

## License
This project is unlicensed and intended for educational purposes. Feel free to adapt and expand it for your needs!

---

This README provides a clear overview of the ACN project, its setup, and functionality. Add it to your `acn/` directory as `README.md`. Let me know if you’d like to tweak it further!