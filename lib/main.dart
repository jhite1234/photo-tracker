import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // For date formatting

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;
  runApp(PlanetPhotoTracker(camera: firstCamera));
}

class PlanetPhotoTracker extends StatelessWidget {
  final CameraDescription camera;
  const PlanetPhotoTracker({required this.camera, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planet Photo Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(camera: camera),
    );
  }
}

/// HomeScreen with bottom navigation to switch between Capture and Gallery screens.
class HomeScreen extends StatefulWidget {
  final CameraDescription camera;
  const HomeScreen({required this.camera, Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [CameraScreen(camera: widget.camera), GalleryScreen()];
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

/// CameraScreen captures an image along with GPS & timestamp data.
class CameraScreen extends StatefulWidget {
  final CameraDescription camera;
  const CameraScreen({required this.camera, Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  Position? _currentPosition;
  late DateTime _captureTime;

  // Overlay settings.
  bool _showGPS = true;
  bool _showDate = true;
  bool _showDescription = true;
  Offset gpsPosition = const Offset(20, 20);
  Offset datePosition = const Offset(20, 60);
  Offset descPosition = const Offset(20, 100);
  String descriptionText = 'Your description here';

  // Track if location permission is granted.
  bool _locationPermissionGranted = false;
  // Subscription for continuous position updates.
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();

    // Initialize the camera with audio disabled.
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();

    // Explicitly check/request location permission at runtime.
    _checkLocationPermission();

    // Load any previously saved overlay settings.
    _loadSettings();
  }

  Future<void> _fetchCurrentLocation() async {
    if (!_locationPermissionGranted) return;
    try {
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = currentPosition;
      });
      print(
        "Current position: Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}",
      );
    } catch (e) {
      print("Error fetching position: $e");
    }
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled. Please enable them in settings.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    print("Initial location permission status: $permission");

    if (permission == LocationPermission.denied) {
      print("Requesting location permission...");
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      print("Location permission permanently denied. Opening app settings.");
      await Geolocator.openAppSettings();
      return;
    }

    if (permission == LocationPermission.denied) {
      print("User denied location permission.");
      return;
    }

    print("Location permission granted: $permission");
    setState(() {
      _locationPermissionGranted = true;
    });
    _fetchCurrentLocation();
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Force user to respond.
      builder: (context) {
        return AlertDialog(
          title: const Text("Location Permission Required"),
          content: const Text(
            "This app needs location access to tag your photos with GPS data. Please allow location permission.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkLocationPermission();
              },
              child: const Text("Allow"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      gpsPosition = Offset(
        prefs.getDouble('gps_x') ?? 20,
        prefs.getDouble('gps_y') ?? 20,
      );
      datePosition = Offset(
        prefs.getDouble('date_x') ?? 20,
        prefs.getDouble('date_y') ?? 60,
      );
      descPosition = Offset(
        prefs.getDouble('desc_x') ?? 20,
        prefs.getDouble('desc_y') ?? 100,
      );
      _showGPS = prefs.getBool('showGPS') ?? true;
      _showDate = prefs.getBool('showDate') ?? true;
      _showDescription = prefs.getBool('showDescription') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setDouble('gps_x', gpsPosition.dx);
    prefs.setDouble('gps_y', gpsPosition.dy);
    prefs.setDouble('date_x', datePosition.dx);
    prefs.setDouble('date_y', datePosition.dy);
    prefs.setDouble('desc_x', descPosition.dx);
    prefs.setDouble('desc_y', descPosition.dy);
    prefs.setBool('showGPS', _showGPS);
    prefs.setBool('showDate', _showDate);
    prefs.setBool('showDescription', _showDescription);
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _captureAndProcessImage() async {
    try {
      await _initializeControllerFuture;

      // If we don't have a current position yet, try to get one immediately.
      if (_currentPosition == null && _locationPermissionGranted) {
        _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        print("Fetched position at capture: $_currentPosition");
      }

      final image = await _controller.takePicture();
      _captureTime = DateTime.now();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => PreviewScreen(
                imagePath: image.path,
                gpsData:
                    _currentPosition != null
                        ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}'
                        : 'No GPS',
                captureTime: _captureTime,
                initialGpsOffset: gpsPosition,
                initialDateOffset: datePosition,
                initialDescOffset: descPosition,
                showGPS: _showGPS,
                showDate: _showDate,
                showDescription: _showDescription,
                descriptionText: descriptionText,
                onSettingsChanged: (
                  newGps,
                  newDate,
                  newDesc,
                  newShowGPS,
                  newShowDate,
                  newShowDesc,
                  newDescText,
                ) {
                  setState(() {
                    gpsPosition = newGps;
                    datePosition = newDate;
                    descPosition = newDesc;
                    _showGPS = newShowGPS;
                    _showDate = newShowDate;
                    _showDescription = newShowDesc;
                    descriptionText = newDescText;
                  });
                  _saveSettings();
                },
              ),
        ),
      );
    } catch (e) {
      print('Error capturing image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Even if location permission isn't granted, we show the camera preview.
    // The location dialog should prompt the user to allow access.
    return Scaffold(
      appBar: AppBar(title: const Text('Capture Image')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureAndProcessImage,
        tooltip: 'Capture',
        child: const Icon(Icons.camera),
      ),
    );
  }
}

/// PreviewScreen lets the user adjust overlays and save the final image.
class PreviewScreen extends StatefulWidget {
  final String imagePath;
  final String gpsData;
  final DateTime captureTime;
  final Offset initialGpsOffset;
  final Offset initialDateOffset;
  final Offset initialDescOffset;
  final bool showGPS;
  final bool showDate;
  final bool showDescription;
  final String descriptionText;
  final Function(Offset, Offset, Offset, bool, bool, bool, String)
  onSettingsChanged;

  const PreviewScreen({
    required this.imagePath,
    required this.gpsData,
    required this.captureTime,
    required this.initialGpsOffset,
    required this.initialDateOffset,
    required this.initialDescOffset,
    required this.showGPS,
    required this.showDate,
    required this.showDescription,
    required this.descriptionText,
    required this.onSettingsChanged,
    Key? key,
  }) : super(key: key);

  @override
  _PreviewScreenState createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late double maxWidth;
  late double maxHeight;
  late Offset gpsOffset;
  late Offset dateOffset;
  late Offset descOffset;
  late bool showGPS;
  late bool showDate;
  late bool showDescription;
  late String descriptionText;

  bool _is24HourFormat = true;
  late TextEditingController _descriptionController;
  final GlobalKey _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    gpsOffset = widget.initialGpsOffset;
    dateOffset = widget.initialDateOffset;
    descOffset = widget.initialDescOffset;
    showGPS = widget.showGPS;
    showDate = widget.showDate;
    showDescription = widget.showDescription;
    descriptionText = widget.descriptionText;

    _descriptionController = TextEditingController(text: descriptionText);
    _descriptionController.addListener(() {
      setState(() {
        descriptionText = _descriptionController.text;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    final appBarHeight =
        AppBar().preferredSize.height + MediaQuery.of(context).padding.top;

    setState(() {
      maxWidth = size.width;
      maxHeight = size.height - appBarHeight;
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime time, bool is24Hour) {
    try {
      if (is24Hour) {
        return DateFormat('MM-dd-yy HH:mm').format(time);
      } else {
        return DateFormat('MM-dd-yy h:mm a').format(time);
      }
    } catch (e) {
      print("Error formatting DateTime: $e");
      return "Invalid Date";
    }
  }

  double _calculateTextWidth(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontSize: 15)),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    );
    painter.layout();
    return painter.size.width;
  }

  Widget _buildDraggableOverlay(
    String text,
    Offset offset,
    Function(Offset) onUpdate,
  ) {
    final textStyle = const TextStyle(color: Colors.white, fontSize: 15);
    final overlayWidth = _calculateTextWidth(text) + 16;
    const overlayHeight = 30;

    final screenSize = MediaQuery.of(context).size;
    final appBarHeight =
        AppBar().preferredSize.height + MediaQuery.of(context).padding.top;

    final constrainedMaxWidth = screenSize.width - overlayWidth;
    final constrainedMaxHeight =
        screenSize.height - overlayHeight - appBarHeight;

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final newOffset = Offset(
              (offset.dx + details.delta.dx).clamp(0.0, constrainedMaxWidth),
              (offset.dy + details.delta.dy).clamp(0.0, constrainedMaxHeight),
            );
            onUpdate(newOffset);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(text, style: textStyle),
        ),
      ),
    );
  }

  Future<void> _saveOverlayedImage() async {
    try {
      RenderRepaintBoundary boundary =
          _globalKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${directory.path}/planet_photo_tracker');
      if (!(await imageDir.exists())) {
        await imageDir.create(recursive: true);
      }
      final file =
          await File(
            '${imageDir.path}/${DateTime.now().millisecondsSinceEpoch}.png',
          ).create();
      await file.writeAsBytes(pngBytes);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image saved')));
    } catch (e) {
      print('Error saving image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDateTime = _formatDateTime(
      widget.captureTime,
      _is24HourFormat,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview & Edit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Image',
            onPressed: _saveOverlayedImage,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              key: _globalKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(widget.imagePath), fit: BoxFit.cover),
                  if (showGPS)
                    _buildDraggableOverlay(
                      'GPS: ${widget.gpsData}',
                      gpsOffset,
                      (newOffset) => gpsOffset = newOffset,
                    ),
                  if (showDate)
                    _buildDraggableOverlay(
                      'Date: $formattedDateTime',
                      dateOffset,
                      (newOffset) => dateOffset = newOffset,
                    ),
                  if (showDescription)
                    _buildDraggableOverlay(
                      descriptionText,
                      descOffset,
                      (newOffset) => descOffset = newOffset,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Wrap(
                  spacing: 20,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: showGPS,
                          onChanged:
                              (value) => setState(() => showGPS = value!),
                        ),
                        const Text('GPS'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: showDate,
                          onChanged:
                              (value) => setState(() => showDate = value!),
                        ),
                        const Text('Date'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: showDescription,
                          onChanged:
                              (value) =>
                                  setState(() => showDescription = value!),
                        ),
                        const Text('Description'),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('24-Hour Time'),
                    Switch(
                      value: _is24HourFormat,
                      onChanged:
                          (value) => setState(() => _is24HourFormat = value),
                    ),
                  ],
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Description'),
                  controller: _descriptionController,
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onSettingsChanged(
                      gpsOffset,
                      dateOffset,
                      descOffset,
                      showGPS,
                      showDate,
                      showDescription,
                      descriptionText,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings saved')),
                    );
                  },
                  child: const Text('Save Settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// GalleryScreen displays saved images in a grid with selection, deletion, and sharing.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<FileSystemEntity> _images = [];
  bool _selectionMode = false;
  Set<String> _selectedImages = {};

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final directory = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${directory.path}/planet_photo_tracker');
    if (!(await imageDir.exists())) {
      await imageDir.create(recursive: true);
    }
    setState(() {
      _images =
          imageDir
              .listSync()
              .where((file) => file.path.endsWith('.png'))
              .toList();
      _selectedImages.clear();
    });
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedImages.contains(path)) {
        _selectedImages.remove(path);
      } else {
        _selectedImages.add(path);
      }
    });
  }

  Future<void> _deleteSelectedImages() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Selected Images'),
            content: const Text(
              'Are you sure you want to delete the selected images?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirm == true) {
      for (String path in _selectedImages) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      setState(() {
        _selectionMode = false;
        _selectedImages.clear();
      });
      _loadImages();
    }
  }

  Future<void> _shareSelectedImages() async {
    if (_selectedImages.isNotEmpty) {
      final files = _selectedImages.map((path) => XFile(path)).toList();
      await Share.shareXFiles(files, text: 'Planet Photo Tracker Images');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share Selected',
              onPressed: _selectedImages.isEmpty ? null : _shareSelectedImages,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Selected',
              onPressed: _selectedImages.isEmpty ? null : _deleteSelectedImages,
            ),
          ],
          IconButton(
            icon: Icon(_selectionMode ? Icons.cancel : Icons.select_all),
            tooltip: _selectionMode ? 'Cancel Selection' : 'Select Images',
            onPressed: () {
              setState(() {
                _selectionMode = !_selectionMode;
                if (!_selectionMode) {
                  _selectedImages.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadImages,
          ),
        ],
      ),
      body:
          _images.isEmpty
              ? const Center(child: Text('No images found.'))
              : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                ),
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final file = _images[index];
                  final path = file.path;
                  bool isSelected = _selectedImages.contains(path);
                  return GestureDetector(
                    onLongPress: () {
                      if (!_selectionMode) {
                        setState(() {
                          _selectionMode = true;
                          _selectedImages.add(path);
                        });
                      }
                    },
                    onTap: () {
                      if (_selectionMode) {
                        _toggleSelection(path);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => FullImageScreen(imagePath: path),
                          ),
                        );
                      }
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(File(path), fit: BoxFit.cover),
                        ),
                        if (_selectionMode)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}

/// FullImageScreen displays a full-screen view of an image with a share option.
class FullImageScreen extends StatelessWidget {
  final String imagePath;
  const FullImageScreen({required this.imagePath, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Full Image'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () async {
              await Share.shareXFiles([
                XFile(imagePath),
              ], text: 'Planet Photo Tracker Image');
            },
          ),
        ],
      ),
      body: Center(child: Image.file(File(imagePath))),
    );
  }
}
