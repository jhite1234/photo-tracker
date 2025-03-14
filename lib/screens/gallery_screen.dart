import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

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
        if (await file.exists()) await file.delete();
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
