# Planet Photo Tracker

Planet Photo Tracker is a Flutter application designed for field data collection. It allows users to capture photos with integrated GPS, timestamp, and customizable description overlays. Users can reposition overlays directly on the image, crop images using pinch-to-zoom (while keeping overlays fixed), and manage captured images via an in-app gallery. The app supports dark mode and even lets Android users trigger capture via the hardware volume-down button.

## Features

### Camera Capture
- Capture high-resolution photos using your device’s camera.
- Trigger image capture using the hardware volume-down button on Android.

### Overlay Information
- Automatically tag images with GPS coordinates and timestamps.
- Add customizable descriptions that can be repositioned on the image.

### Interactive Image Editing
- Use pinch-to-zoom to crop the underlying image while overlays remain fixed.
- Editing controls are separated from the capture area so the keyboard does not affect the saved image.
- Automatic return to the camera screen after saving an image.
- Description field now features white text, cursor, and selection handles with a transparent light blue highlight for better readability.

### Gallery View
- Browse, share, and delete images directly within the app.
- Images are grouped by capture date (e.g., Today, Yesterday, This Week, etc.).
- Bulk-select or deselect entire date groups using group checkboxes.
- Improved grid view with spacing between images.

### Dark Mode Support
- The app automatically adapts to your device’s light/dark theme.

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
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

## Code Organization

```
lib/
├── main.dart                           # Entry point, global theme, and navigation.
├── screens/
│   ├── camera_screen.dart              # Camera features (capture, zoom, overlays).
│   ├── preview_screen.dart             # Image preview and editing.
│   └── gallery_screen.dart             # Gallery for managing images.
└── utils/
    └── native_location_service.dart    # Native location integration via method channel.
```

Permissions & Native Integration
Camera: Captures images using the camera package.
Location: Retrieves GPS data via native integration (implemented in MainActivity.kt for Android and AppDelegate.swift for iOS).
Storage: Saves images locally.
Ensure that the necessary permissions are configured in AndroidManifest.xml and Info.plist.



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

Editing controls in the preview screen dynamically adjust based on the current theme and now use a consistent white styling for text elements and selection highlights.


## Changelog
Release v0.2.4

### Preview Screen Enhancements:
- Automatic return to the camera screen after saving an image.
- Separated capture area from editing controls so the keyboard does not crop the saved image.
- Only the underlying image is pannable/zoomable (for cropping), while overlays remain fixed.
- Description field now styled with white text, white cursor, and white selection handles with a transparent light blue highlight.

### Camera Screen Enhancements:
- Added hardware volume-down capture on Android using a custom platform channel.

### Gallery Screen Enhancements:
- Restored group selection functionality by date (Today, Yesterday, etc.) with checkboxes to select/deselect entire groups.
- Added spacing between images in the grid view.

### General Improvements:
- Updated styling for consistency across light and dark themes.
- Various bug fixes and code improvements.


## Contributing
Contributions are welcome! Open an issue or submit a pull request for bug fixes, improvements, or new feature suggestions.


## License
This project is licensed under the MIT License. See the LICENSE file for details.

