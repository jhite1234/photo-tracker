import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/camera_screen.dart';
import 'screens/gallery_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(PlanetPhotoTracker(cameras: cameras));
}

class PlanetPhotoTracker extends StatelessWidget {
  final List<CameraDescription> cameras;
  const PlanetPhotoTracker({required this.cameras, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planet Photo Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(cameras: cameras),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({required this.cameras, Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [CameraScreen(cameras: widget.cameras), GalleryScreen()];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
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
