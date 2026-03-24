#!/bin/bash
# OffTalk APK Build Script
# This simple script will guide you through creating the release APK for OffTalk.

echo "--- Building OffTalk APK ---"

# Step 1: Ensure Flutter is installed and on your PATH
if ! command -v flutter &> /dev/null
then
    echo "Error: 'flutter' command could not be found."
    echo "Please install Flutter SDK (https://docs.flutter.dev/get-started/install/linux) or use snap: sudo snap install flutter --classic"
    exit 1
fi

echo "[1/4] Flutter SDK found. Getting dependencies..."
flutter pub get

# Step 2: Code Generation (if necessary)
echo "[2/4] Running code generation tools..."
flutter pub run build_runner build --delete-conflicting-outputs

# Step 3: Run the actual flutter build command
echo "[3/4] Building APK release..."
# The --release flag automatically uses ProGuard to minify and obfuscate your code
flutter build apk --release

# Step 4: Output location
echo "[4/4] Build Complete!"
echo "The native APK file is located at:"
echo "$(pwd)/build/app/outputs/flutter-apk/app-release.apk"
echo "You can transfer this file to your Android device to install OffTalk."

exit 0
