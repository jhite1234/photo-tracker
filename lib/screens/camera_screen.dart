import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../screens/preview_screen.dart';
import '../utils/permission_util.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({required this.cameras, Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  int _currentCameraIndex = 0;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0; // Used during pinch-to-zoom

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

  bool _locationPermissionGranted = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _checkPermissions();
    _loadSettings();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.cameras[_currentCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize().then((_) async {
      _minZoom = await _controller.getMinZoomLevel();
      _maxZoom = await _controller.getMaxZoomLevel();
      _currentZoom = _minZoom;
      setState(() {});
    });
  }

  void _switchCamera() async {
    if (widget.cameras.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % widget.cameras.length;
    await _controller.dispose();
    _initializeCamera();
  }

  Future<void> _checkPermissions() async {
    _locationPermissionGranted = await requestLocationPermission();
    if (_locationPermissionGranted) {
      _fetchCurrentLocation();
    } else {
      print("Location permission not granted.");
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = currentPosition;
      });
      print("Current position: $_currentPosition");
    } catch (e) {
      print("Error fetching position: $e");
    }
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
      if (_currentPosition == null && _locationPermissionGranted) {
        _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Image'),
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_camera),
            tooltip: 'Switch Camera',
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return GestureDetector(
              onScaleStart: (details) {
                _baseZoom = _currentZoom;
              },
              onScaleUpdate: (details) {
                double newZoom = (_baseZoom * details.scale).clamp(
                  _minZoom,
                  _maxZoom,
                );
                setState(() {
                  _currentZoom = newZoom;
                });
                _controller.setZoomLevel(newZoom);
              },
              child: Stack(
                children: [
                  CameraPreview(_controller),
                  Positioned(
                    bottom: 80,
                    left: 20,
                    right: 20,
                    child: Slider(
                      min: _minZoom,
                      max: _maxZoom,
                      value: _currentZoom.clamp(_minZoom, _maxZoom),
                      activeColor: Colors.blue.shade700,
                      inactiveColor: Colors.blue.shade200,
                      onChanged: (value) async {
                        await _controller.setZoomLevel(value);
                        setState(() {
                          _currentZoom = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureAndProcessImage,
        tooltip: 'Capture',
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        child: const Icon(Icons.camera),
      ),
    );
  }
}
