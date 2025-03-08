import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

class EventManagementPage extends StatefulWidget {
  const EventManagementPage({super.key});

  @override
  State<EventManagementPage> createState() => _EventManagementPageState();
}

class _EventManagementPageState extends State<EventManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  List<dynamic> _imageFiles = [];
  bool _isUploading = false;
  bool _isMultiDay = false;
  final int _maxImageLimit = 3; // Set maximum image limit

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  Future<void> _pickDate(BuildContext context, bool isFromDate) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isFromDate
          ? (_fromDate ?? DateTime.now())
          : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = pickedDate;
          if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
            _toDate = _fromDate;
          }
        } else {
          _toDate = pickedDate;
          if (_fromDate != null && _fromDate!.isAfter(_toDate!)) {
            _fromDate = _toDate;
          }
        }
      });
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      final imageBytes = await file.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) return file;

      final resizedImage = img.copyResize(image, width: 800);
      final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      final compressedFile = File(file.path)..writeAsBytesSync(compressedBytes);
      return compressedFile;
    } catch (e) {
      print("Error compressing image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image compression failed: $e")));
      return file;
    }
  }

  Future<void> _uploadImagesAndSaveEvent(String? docId) async {
    if (_isUploading) return;

    setState(() => _isUploading = true);
    Navigator.pop(context);

    String title = _titleController.text.trim();
    String description = _descriptionController.text.trim();

    if (title.isEmpty ||
        description.isEmpty ||
        (_fromDate == null && !_isMultiDay) ||
        (_isMultiDay && (_fromDate == null || _toDate == null))) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All fields are required!")));
      setState(() => _isUploading = false);
      return;
    }

    List<String> imageUrls = [];
    for (var image in _imageFiles) {
      if (image is String) {
        imageUrls.add(image);
      } else if (image is XFile) {
        try {
          File file = File(image.path);
          File compressedFile = await _compressImage(file);
          String fileName =
              "events/${DateTime.now().millisecondsSinceEpoch}.jpg";
          UploadTask uploadTask =
              _storage.ref(fileName).putFile(compressedFile);
          TaskSnapshot snapshot = await uploadTask;
          String downloadUrl = await snapshot.ref.getDownloadURL();
          imageUrls.add(downloadUrl);
        } catch (e) {
          print("Error uploading image: $e");
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to upload an image: $e")));
        }
      }
    }

    try {
      Map<String, dynamic> eventData = {
        'title': title,
        'description': description,
        'fromDate': _fromDate?.toIso8601String(),
        'toDate': _isMultiDay
            ? _toDate?.toIso8601String()
            : _fromDate?.toIso8601String(),
        'images': imageUrls,
        'isMultiDay': _isMultiDay,
      };

      if (docId == null) {
        await _firestore.collection('events').add(eventData);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Event added successfully!")));
      } else {
        await _firestore.collection('events').doc(docId).update(eventData);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Event updated successfully!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save event: ${e.toString()}")));
    } finally {
      setState(() {
        _isUploading = false;
        _imageFiles.clear();
        _titleController.clear();
        _descriptionController.clear();
        _fromDate = null;
        _toDate = null;
        _isMultiDay = false;
      });
    }
  }

  Future<void> _deleteEvent(String docId) async {
    try {
      await _firestore.collection('events').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Event deleted successfully!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete event: ${e.toString()}")));
    }
  }

  void _clearFormFields() {
    _titleController.clear();
    _descriptionController.clear();
    _fromDate = null;
    _toDate = null;
    _isMultiDay = false;
    _imageFiles.clear();
  }

  void _showEventDialog({String? docId, Map<String, dynamic>? event}) {
    if (docId == null) {
      _clearFormFields();
    } else if (event != null) {
      _titleController.text = event['title'];
      _descriptionController.text = event['description'];
      _isMultiDay = event['isMultiDay'] ?? false;
      _fromDate =
          event['fromDate'] != null ? DateTime.parse(event['fromDate']) : null;
      _toDate =
          event['toDate'] != null ? DateTime.parse(event['toDate']) : null;
      _imageFiles = List.from(event['images'] ?? []);
    }

    showDialog(
      context: context,
      builder: (context) {
        List<dynamic> dialogImageFiles = List.from(_imageFiles);

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(docId == null ? "Add Event" : "Edit Event"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: "Title"),
                    ),
                    TextField(
                      controller: _descriptionController,
                      decoration:
                          const InputDecoration(labelText: "Description"),
                    ),
                    SwitchListTile(
                      title: const Text("Multi-day Event"),
                      value: _isMultiDay,
                      onChanged: (value) {
                        setState(() {
                          _isMultiDay = value;
                          if (!_isMultiDay) _toDate = null;
                        });
                      },
                    ),
                    ListTile(
                      title: Text(_fromDate == null
                          ? "Select From Date"
                          : "From: ${DateFormat('yyyy-MM-dd').format(_fromDate!)}"),
                      onTap: () =>
                          _pickDate(context, true).then((_) => setState(() {})),
                    ),
                    if (_isMultiDay)
                      ListTile(
                        title: Text(_toDate == null
                            ? "Select To Date"
                            : "To: ${DateFormat('yyyy-MM-dd').format(_toDate!)}"),
                        onTap: () => _pickDate(context, false)
                            .then((_) => setState(() {})),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Images:"),
                        Row(
                          children: [
                            Text(
                              "${dialogImageFiles.length}/$_maxImageLimit",
                              style: TextStyle(
                                color: dialogImageFiles.length >= _maxImageLimit
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (dialogImageFiles.length < _maxImageLimit)
                              ElevatedButton(
                                onPressed: () async {
                                  final pickedFile = await _picker.pickImage(
                                      source: ImageSource.gallery);
                                  if (pickedFile != null) {
                                    setState(() {
                                      dialogImageFiles.add(pickedFile);
                                      _imageFiles = List.from(dialogImageFiles);
                                    });
                                  }
                                },
                                child: const Text("Add Image"),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: dialogImageFiles.asMap().entries.map((entry) {
                        int index = entry.key;
                        var image = entry.value;
                        return Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: image is String
                                      ? NetworkImage(image)
                                      : FileImage(File(image.path))
                                          as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    dialogImageFiles.removeAt(index);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black54,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: _isUploading
                      ? null
                      : () {
                          _imageFiles = List.from(dialogImageFiles);
                          _uploadImagesAndSaveEvent(docId);
                        },
                  child: _isUploading
                      ? const CircularProgressIndicator()
                      : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Event Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEventDialog(),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _firestore.collection('events').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No events found"));
          }
          var events = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              var event = events[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(event['title'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(event['isMultiDay']
                      ? "From: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(event['fromDate']))} To: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(event['toDate']))}"
                      : "Date: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(event['fromDate']))}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEventDialog(
                            docId: event.id, event: event.data()),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteEvent(event.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
