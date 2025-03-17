import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    List<FileSystemEntity> files =
        imageDir
            .listSync()
            .where((file) => file.path.endsWith('.png'))
            .toList();

    // Sort images in descending order (most recent first) based on the timestamp in the filename.
    files.sort((a, b) {
      DateTime? dateA = _getDateFromFile(a);
      DateTime? dateB = _getDateFromFile(b);
      if (dateA == null || dateB == null) return 0;
      return dateB.compareTo(dateA);
    });
    setState(() {
      _images = files;
      _selectedImages.clear();
    });
  }

  // Extracts DateTime from filename (assuming the filename is the milliseconds since epoch)
  DateTime? _getDateFromFile(FileSystemEntity file) {
    String fileName = file.path.split('/').last;
    String timestampStr = fileName.replaceAll('.png', '');
    try {
      int timestamp = int.parse(timestampStr);
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      return null;
    }
  }

  // Helper to get the start of the week using Sunday as the start.
  DateTime _getWeekStart(DateTime date) {
    // In Dart, weekday is 1 for Monday and 7 for Sunday.
    // For Sunday as start, subtract date.weekday % 7 days.
    int daysToSubtract = date.weekday % 7;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: daysToSubtract));
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  bool _isThisWeek(DateTime date, DateTime now) {
    DateTime weekStart = _getWeekStart(now);
    DateTime weekEnd = weekStart.add(Duration(days: 7));
    return !date.isBefore(weekStart) && date.isBefore(weekEnd);
  }

  bool _isLastWeek(DateTime date, DateTime now) {
    DateTime weekStart = _getWeekStart(now);
    DateTime lastWeekStart = weekStart.subtract(Duration(days: 7));
    return !date.isBefore(lastWeekStart) && date.isBefore(weekStart);
  }

  // Returns a section title based on the image's capture date.
  String _getSectionName(DateTime date) {
    final now = DateTime.now();
    if (_isToday(date)) {
      return "Today";
    } else if (_isYesterday(date)) {
      return "Yesterday";
    } else if (_isThisWeek(date, now)) {
      return "This Week";
    } else if (_isLastWeek(date, now)) {
      return "Last Week";
    } else if (date.year == now.year && date.month == now.month) {
      return "This Month";
    } else if (date.year == now.year) {
      // For previous months in the current year, show the month name.
      return DateFormat.MMMM().format(date);
    } else {
      // For images from previous years, use the year.
      return date.year.toString();
    }
  }

  // Groups the loaded images by section.
  Map<String, List<FileSystemEntity>> _groupImages() {
    Map<String, List<FileSystemEntity>> groups = {};
    for (var image in _images) {
      DateTime? date = _getDateFromFile(image);
      if (date == null) continue;
      String section = _getSectionName(date);
      groups.putIfAbsent(section, () => []);
      groups[section]!.add(image);
    }
    // Sort images in each section in descending order.
    groups.forEach((key, list) {
      list.sort((a, b) {
        DateTime dateA = _getDateFromFile(a)!;
        DateTime dateB = _getDateFromFile(b)!;
        return dateB.compareTo(dateA);
      });
    });
    return groups;
  }

  // Determines a sort order for section keys so that fixed groups come first,
  // then previous month groups (in descending order), and finally older years.
  int _orderForSection(String section, List<FileSystemEntity> images) {
    final now = DateTime.now();
    if (section == "Today") return 0;
    if (section == "Yesterday") return 1;
    if (section == "This Week") return 2;
    if (section == "Last Week") return 3;
    if (section == "This Month") return 4;
    // For month groups in the current year:
    DateTime? dt = _getDateFromFile(images.first);
    if (dt != null && dt.year == now.year) {
      return 5 + (12 - dt.month); // Lower number means more recent month.
    }
    // For year groups, assign a high order number so they appear after current-year groups.
    int year = int.tryParse(section) ?? now.year;
    return 10000 - year;
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
    Map<String, List<FileSystemEntity>> groups = _groupImages();
    // Sort the section keys using our custom order.
    List<String> sectionKeys = groups.keys.toList();
    sectionKeys.sort(
      (a, b) =>
          _orderForSection(a, groups[a]!) - _orderForSection(b, groups[b]!),
    );

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
              : ListView.builder(
                itemCount: sectionKeys.length,
                itemBuilder: (context, index) {
                  String section = sectionKeys[index];
                  List<FileSystemEntity> sectionImages = groups[section]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section header.
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          section,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Display images in a grid.
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                            ),
                        itemCount: sectionImages.length,
                        itemBuilder: (context, imgIndex) {
                          final file = sectionImages[imgIndex];
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
                                        (context) =>
                                            FullImageScreen(imagePath: path),
                                  ),
                                );
                              }
                            },
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.file(
                                    File(path),
                                    fit: BoxFit.cover,
                                  ),
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
                    ],
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
