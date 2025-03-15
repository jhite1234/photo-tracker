import 'dart:async';
import 'dart:math'; // For the min() function.
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

  // For enhanced positioning: list to collect samples.
  List<Position> _positionSamples = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _checkPermissionsAndLocationServices();
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

  // Check if location services are enabled, then request permissions.
  Future<void> _checkPermissionsAndLocationServices() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Prompt the user to enable location services.
      await Geolocator.openLocationSettings();
      // Optionally, re-check service status or inform the user.
      return;
    }

    _locationPermissionGranted = await requestLocationPermission();
    if (_locationPermissionGranted) {
      _startEnhancedPositioning();
    } else {
      print("Location permission not granted.");
    }
  }

  // Subscribe to position updates and collect samples.
  void _startEnhancedPositioning() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1, // update when moving at least 1 meter.
      ),
    ).listen((Position position) {
      _positionSamples.add(position);
      // When we have enough samples, compute an average.
      if (_positionSamples.length >= 5) {
        Position averagedPosition = _getWeightedAveragePosition(
          _positionSamples,
        );
        setState(() {
          _currentPosition = averagedPosition;
        });
        _positionSamples.clear();
      }
      print("Collected position sample: $position");
    });
  }

  // Computes a weighted average based on positional accuracy.
  Position _getWeightedAveragePosition(List<Position> positions) {
    double sumLat = 0;
    double sumLng = 0;
    double sumWeights = 0;
    for (var pos in positions) {
      double weight = 1 / _positionalAccuracyOrDefault(pos);
      sumLat += pos.latitude * weight;
      sumLng += pos.longitude * weight;
      sumWeights += weight;
    }
    double avgLat = sumLat / sumWeights;
    double avgLng = sumLng / sumWeights;
    // Use the smallest reported accuracy among the samples.
    double bestAccuracy = positions.map((p) => p.accuracy).reduce(min);
    // Use the most recent timestamp.
    DateTime? latestTimestamp;
    for (var pos in positions) {
      if (latestTimestamp == null ||
          (pos.timestamp?.isAfter(latestTimestamp) ?? false)) {
        latestTimestamp = pos.timestamp;
      }
    }
    // Fallback to current time if no timestamp was available.
    latestTimestamp = latestTimestamp ?? DateTime.now();
    // Create a new Position with the averaged values, including required headingAccuracy.
    return Position(
      latitude: avgLat,
      longitude: avgLng,
      timestamp: latestTimestamp,
      accuracy: bestAccuracy,
      altitude: positions.last.altitude,
      altitudeAccuracy: positions.last.altitudeAccuracy,
      heading: positions.last.heading,
      headingAccuracy: positions.last.headingAccuracy,
      speed: positions.last.speed,
      speedAccuracy: positions.last.speedAccuracy,
      floor: positions.last.floor,
      isMocked: positions.last.isMocked,
    );
  }

  // Helper: returns the accuracy, or a default value if invalid.
  double _positionalAccuracyOrDefault(Position pos) {
    return pos.accuracy > 0 ? pos.accuracy : 1.0;
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
      // If _currentPosition is null, try to fetch a fresh position.
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
                  // Zoom slider.
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
                  // Display current position accuracy.
                  if (_currentPosition != null)
                    Positioned(
                      bottom: 40,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(0)} m',
                          style: const TextStyle(color: Colors.white),
                        ),
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
