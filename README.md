# Planet Photo Tracker

Planet Photo Tracker is a Flutter application designed specifically for field data collection. It allows users to capture photos integrated with GPS, date, and custom description overlays. Users can adjust overlay positions, and manage captured images easily through an in-app gallery. The app also supports pinch-to-zoom and adapts seamlessly between light and dark themes based on your device settings.

## Features

### Camera Capture
- Capture high-resolution photos using your device’s camera.

### Overlay Information
- Automatically tag images with GPS coordinates and timestamps.
- Add customizable descriptions that can be repositioned directly on the image.

### Pinch-to-Zoom
- Intuitive zoom controls during image capture.

### Gallery View
- View, share, and delete images directly within the app.

### Dark Mode Support
- Automatically adapts to your device’s theme (light/dark).

### Customizable Overlays
- Drag-and-drop repositioning for GPS, date, and description overlays.

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) installed on your machine.
- Android Studio (or Xcode for iOS).
- An Android device or emulator for testing.

### Installation
Clone the repository:

```bash
git clone https://github.com/yourusername/planet_photo_tracker.git
cd planet_photo_tracker
```

Fetch dependencies:

```bash
flutter pub get
```

### Running the App
Ensure you have a connected Android device or running emulator, then execute:

```bash
flutter run
```

## Building for Release

### Android APK
To build a release APK:

```bash
flutter build apk --release
```
The APK will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle
For Google Play distribution:

```bash
flutter build appbundle --release
```
The generated bundle:
```
build/app/outputs/bundle/release/app.aab
```

> **Note:** Ensure proper signing configurations in `android/app/build.gradle` before building.

## Code Organization

```
lib/
├── main.dart                  # Entry point, global theme, and navigation.
├── screens/
│   ├── camera_screen.dart     # Camera features (capture, zoom, overlays).
│   ├── preview_screen.dart    # Image preview and editing.
│   └── gallery_screen.dart    # Gallery for managing images.
└── utils/
    └── permission_util.dart   # Permissions handling.
```

## Permissions
- **Camera:** Capturing images (`camera` package).
- **Location:** GPS data integration (`geolocator` package).
- **Storage:** Saving images locally. Adjustable for public storage if needed.

Ensure permissions are properly configured in `AndroidManifest.xml` and `Info.plist` (iOS).

## Customization & Theme
App theme adapts automatically based on device settings. Customize further by modifying `ThemeData` in `main.dart`:

```dart
theme: ThemeData(
  primarySwatch: Colors.blue,
  iconTheme: IconThemeData(color: Colors.blue.shade700),
  appBarTheme: AppBarTheme(
    iconTheme: IconThemeData(color: Colors.blue.shade700),
  ),
),
```

Bottom control areas dynamically adjust background colors based on the current theme in `preview_screen.dart`.

## Contributing
Contributions are encouraged! Open issues or submit pull requests for bug fixes, improvements, or feature additions.

## License
Licensed under the MIT License. See [LICENSE](LICENSE) for details.

