import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

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
  late Offset gpsOffset;
  late Offset dateOffset;
  late Offset descOffset;
  late bool showGPS;
  late bool showDate;
  late bool showDescription;
  late String descriptionText;
  bool _is24HourFormat = true;
  late TextEditingController _descriptionController;

  // Key to capture the full-screen image+overlays.
  final GlobalKey _captureKey = GlobalKey();

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
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime time, bool is24Hour) {
    try {
      return is24Hour
          ? DateFormat('MM-dd-yy HH:mm').format(time)
          : DateFormat('MM-dd-yy h:mm a').format(time);
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

  Future<void> _saveOverlayedImage() async {
    try {
      // Capture the full capture area regardless of the keyboard.
      RenderRepaintBoundary boundary =
          _captureKey.currentContext?.findRenderObject()
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
      // Automatically return to the Camera Screen.
      Navigator.pop(context);
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
    final screenSize = MediaQuery.of(context).size;
    final appBarHeight =
        AppBar().preferredSize.height + MediaQuery.of(context).padding.top;

    return Scaffold(
      // Prevent the keyboard from resizing the layout.
      resizeToAvoidBottomInset: false,
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
      body: Stack(
        children: [
          // Capture area: full screen, unaffected by the keyboard.
          RepaintBoundary(
            key: _captureKey,
            child: Stack(
              children: [
                // Full-screen InteractiveViewer for the image only.
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.cover,
                      width: screenSize.width,
                      height: screenSize.height,
                    ),
                  ),
                ),
                // Fixed overlays.
                if (showGPS)
                  DraggableTextOverlay(
                    text: 'GPS: ${widget.gpsData}',
                    initialOffset: gpsOffset,
                    maxX:
                        screenSize.width -
                        (_calculateTextWidth('GPS: ${widget.gpsData}') + 16),
                    maxY: screenSize.height - appBarHeight - 30,
                    onUpdate: (newOffset) {
                      setState(() {
                        gpsOffset = newOffset;
                      });
                    },
                  ),
                if (showDate)
                  DraggableTextOverlay(
                    text: 'Date: $formattedDateTime',
                    initialOffset: dateOffset,
                    maxX:
                        screenSize.width -
                        (_calculateTextWidth('Date: $formattedDateTime') + 16),
                    maxY: screenSize.height - appBarHeight - 30,
                    onUpdate: (newOffset) {
                      setState(() {
                        dateOffset = newOffset;
                      });
                    },
                  ),
                if (showDescription)
                  DraggableTextOverlay(
                    text: descriptionText,
                    initialOffset: descOffset,
                    maxX:
                        screenSize.width -
                        (_calculateTextWidth(descriptionText) + 16),
                    maxY: screenSize.height - appBarHeight - 30,
                    onUpdate: (newOffset) {
                      setState(() {
                        descOffset = newOffset;
                      });
                    },
                  ),
              ],
            ),
          ),
          // Editing controls are overlaid at the bottom.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              // Shift controls above the keyboard.
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.blueGrey.shade900
                        : Colors.blue.shade50,
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Checkboxes row.
                      Wrap(
                        spacing: 20,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                activeColor: Colors.blue.shade700,
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
                                activeColor: Colors.blue.shade700,
                                value: showDate,
                                onChanged:
                                    (value) =>
                                        setState(() => showDate = value!),
                              ),
                              const Text('Date'),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                activeColor: Colors.blue.shade700,
                                value: showDescription,
                                onChanged:
                                    (value) => setState(
                                      () => showDescription = value!,
                                    ),
                              ),
                              const Text('Description'),
                            ],
                          ),
                        ],
                      ),
                      // 24-Hour Time switch.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('24-Hour Time'),
                          Switch(
                            activeColor: Colors.blue.shade700,
                            value: _is24HourFormat,
                            onChanged:
                                (value) =>
                                    setState(() => _is24HourFormat = value),
                          ),
                        ],
                      ),
                      // Description TextField with updated text selection theme.
                      Theme(
                        data: Theme.of(context).copyWith(
                          textSelectionTheme: TextSelectionThemeData(
                            cursorColor: Colors.white,
                            selectionColor: Colors.blue.withOpacity(
                              0.3,
                            ), // Transparent light blue highlight.
                            selectionHandleColor: Colors.white,
                          ),
                        ),
                        child: TextField(
                          cursorColor: Colors.white,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            labelStyle: TextStyle(color: Colors.white),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                          controller: _descriptionController,
                        ),
                      ),
                      // Save settings button with white text.
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DraggableTextOverlay extends StatefulWidget {
  final String text;
  final Offset initialOffset;
  final double maxX;
  final double maxY;
  final ValueChanged<Offset> onUpdate;
  const DraggableTextOverlay({
    required this.text,
    required this.initialOffset,
    required this.maxX,
    required this.maxY,
    required this.onUpdate,
    Key? key,
  }) : super(key: key);

  @override
  _DraggableTextOverlayState createState() => _DraggableTextOverlayState();
}

class _DraggableTextOverlayState extends State<DraggableTextOverlay> {
  late Offset offset;
  Offset? dragStart;
  Offset? startOffset;

  @override
  void initState() {
    super.initState();
    offset = widget.initialOffset;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(color: Colors.white, fontSize: 15);
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onPanStart: (details) {
          dragStart = details.globalPosition;
          startOffset = offset;
        },
        onPanUpdate: (details) {
          final dx = details.globalPosition.dx - dragStart!.dx;
          final dy = details.globalPosition.dy - dragStart!.dy;
          final newOffset = Offset(
            (startOffset!.dx + dx).clamp(0.0, widget.maxX),
            (startOffset!.dy + dy).clamp(0.0, widget.maxY),
          );
          setState(() {
            offset = newOffset;
          });
          widget.onUpdate(newOffset);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(widget.text, style: textStyle),
        ),
      ),
    );
  }
}
