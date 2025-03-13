import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as img;

class EditRoomPage extends StatefulWidget {
  final DocumentSnapshot room;

  const EditRoomPage({super.key, required this.room});

  @override
  State<EditRoomPage> createState() => _EditRoomPageState();
}

class _EditRoomPageState extends State<EditRoomPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  late TextEditingController _titleController;
  late TextEditingController _totalRoomsController;
  late TextEditingController
      _roomNosController; // New controller for room numbers
  late TextEditingController _amountController;
  late String _selectedOccupancy;
  late String _selectedType;
  late Map<String, bool> _features;
  List<dynamic> _imageFiles = []; // Mix of String (URLs) and XFile (new images)
  bool _isUploading = false;
  final int _maxImageLimit = 5;

  final List<String> _occupancyOptions = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10'
  ];
  final List<String> _typeOptions = ['AC', 'Non AC'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.room['title']);
    _totalRoomsController =
        TextEditingController(text: widget.room['total_rooms']);
    _roomNosController = TextEditingController(
        text: (widget.room['room_nos'] as List<dynamic>?)?.join(', ') ?? '');
    _amountController = TextEditingController(text: widget.room['amount']);
    _selectedOccupancy = widget.room['occupancy'].toString();
    _selectedType = widget.room['type'];
    final List<String> existingFeatures =
        List<String>.from(widget.room['features'] ?? []);
    _features = {
      'WiFi': existingFeatures.contains('WiFi'),
      'Free Breakfast': existingFeatures.contains('Free Breakfast'),
      'TV': existingFeatures.contains('TV'),
      'Hot Water': existingFeatures.contains('Hot Water'),
    };
    _imageFiles = List.from(widget.room['images'] ?? []);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image compression failed: $e")),
      );
      return file;
    }
  }

  Future<void> _uploadImagesAndSaveRoom() async {
    if (_isUploading) return;

    setState(() => _isUploading = true);

    String title = _titleController.text.trim();
    String totalRooms = _totalRoomsController.text.trim();
    String roomNosInput = _roomNosController.text.trim();
    String amountInput = _amountController.text.trim();

    if (title.isEmpty ||
        totalRooms.isEmpty ||
        roomNosInput.isEmpty ||
        amountInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      setState(() => _isUploading = false);
      return;
    }

    List<String> roomNos =
        roomNosInput.split(',').map((s) => s.trim()).toList();
    if (roomNos.length != int.parse(totalRooms)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Number of room numbers must match total rooms")),
      );
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
              "rooms/${widget.room.id}_${DateTime.now().millisecondsSinceEpoch}.jpg";
          UploadTask uploadTask =
              _storage.ref(fileName).putFile(compressedFile);
          TaskSnapshot snapshot = await uploadTask;
          String downloadUrl = await snapshot.ref.getDownloadURL();
          imageUrls.add(downloadUrl);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to upload an image: $e")),
          );
        }
      }
    }

    List<String> selectedFeatures =
        _features.entries.where((e) => e.value).map((e) => e.key).toList();

    try {
      await _firestore.collection('room').doc(widget.room.id).update({
        'title': title,
        'total_rooms': totalRooms,
        'room_nos': roomNos, // Update room numbers as a list
        'amount': amountInput,
        'occupancy': int.parse(_selectedOccupancy),
        'type': _selectedType,
        'features': selectedFeatures,
        'images': imageUrls,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Room type updated successfully!")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating room type: $e")),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _pickImage() async {
    if (_imageFiles.length >= _maxImageLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 5 images allowed")),
      );
      return;
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFiles.add(pickedFile);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Room Type"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Room Title"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _totalRoomsController,
              decoration: const InputDecoration(labelText: "Total Rooms"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomNosController,
              decoration: const InputDecoration(
                labelText: "Room Numbers (comma-separated, e.g., Room1, Room2)",
                hintText: "Room1, Room2, Room3",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: "Amount"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedOccupancy,
              items: _occupancyOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedOccupancy = newValue!;
                });
              },
              decoration: const InputDecoration(labelText: "Occupancy"),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              items: _typeOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedType = newValue!;
                });
              },
              decoration: const InputDecoration(labelText: "Type"),
            ),
            const SizedBox(height: 16),
            const Text("Features:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            ..._features.keys.map((feature) {
              return CheckboxListTile(
                title: Text(feature),
                value: _features[feature],
                onChanged: (bool? value) {
                  setState(() {
                    _features[feature] = value!;
                  });
                },
              );
            }).toList(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Images:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text(
                      "${_imageFiles.length}/$_maxImageLimit",
                      style: TextStyle(
                        color: _imageFiles.length >= _maxImageLimit
                            ? Colors.red
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_imageFiles.length < _maxImageLimit)
                      ElevatedButton(
                        onPressed: _pickImage,
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
              children: _imageFiles.asMap().entries.map((entry) {
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
                              : FileImage(File(image.path)) as ImageProvider,
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
                            _imageFiles.removeAt(index);
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadImagesAndSaveRoom,
              child: _isUploading
                  ? const CircularProgressIndicator()
                  : const Text("Update Room Type"),
            ),
          ],
        ),
      ),
    );
  }
}
