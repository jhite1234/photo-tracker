import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/camera_screen.dart';
import 'screens/gallery_screen.dart';
import 'utils/native_location_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(PlanetPhotoTracker(cameras: cameras));
}

class PlanetPhotoTracker extends StatefulWidget {
  final List<CameraDescription> cameras;
  const PlanetPhotoTracker({required this.cameras, Key? key}) : super(key: key);

  @override
  _PlanetPhotoTrackerState createState() => _PlanetPhotoTrackerState();
}

class _PlanetPhotoTrackerState extends State<PlanetPhotoTracker> {
  Map<String, dynamic>? _nativeLocation;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _startNativeLocationUpdates();
  }

  // Fetch native location periodically (every 5 seconds).
  void _startNativeLocationUpdates() {
    _fetchNativeLocation(); // Initial fetch.
    _locationTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _fetchNativeLocation();
    });
  }

  void _fetchNativeLocation() async {
    final loc = await NativeLocationService.getNativeLocation();
    if (loc != null) {
      setState(() {
        _nativeLocation = loc;
      });
      print("Global native location update: $_nativeLocation");
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planet Photo Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        iconTheme: IconThemeData(color: Colors.blue.shade700),
        appBarTheme: AppBarTheme(
          iconTheme: IconThemeData(color: Colors.blue.shade700),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      themeMode: ThemeMode.system,
      home: HomeScreen(
        cameras: widget.cameras,
        nativeLocation: _nativeLocation,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Map<String, dynamic>? nativeLocation;
  const HomeScreen({
    required this.cameras,
    required this.nativeLocation,
    Key? key,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  Widget _buildPage() {
    if (_selectedIndex == 0) {
      // Pass native location data to CameraScreen.
      return CameraScreen(
        cameras: widget.cameras,
        nativeLocation: widget.nativeLocation,
      );
    } else {
      return GalleryScreen();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.blue.shade200,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Capture',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),
            label: 'Gallery',
          ),
        ],
      ),
    );
  }
}
