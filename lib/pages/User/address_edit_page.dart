// address_edit.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class AddressEditPage extends StatefulWidget {
  final String? address;
  final Function(String) onRemove;

  const AddressEditPage(
      {super.key, required this.address, required this.onRemove});

  @override
  State<AddressEditPage> createState() => _AddressEditPageState();
}

class _AddressEditPageState extends State<AddressEditPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _altPhoneController;
  late TextEditingController _pincodeController;
  late TextEditingController _stateController;
  late TextEditingController _cityController;
  late TextEditingController _houseNoController;
  late TextEditingController _roadController;
  String? _addressType;

  @override
  void initState() {
    super.initState();
    if (widget.address != null) {
      // Editing an existing address
      final addressParts = widget.address!.split('\n');
      _fullNameController = TextEditingController(text: addressParts[0]);
      _phoneController = TextEditingController(
          text: addressParts[2].replaceFirst('Phone: ', ''));
      _altPhoneController = TextEditingController();
      _pincodeController =
          TextEditingController(text: addressParts[1].split(' - ')[1]);
      _stateController = TextEditingController(
          text: addressParts[1].split(', ')[2].split(' - ')[0]);
      _cityController =
          TextEditingController(text: addressParts[1].split(', ')[1]);
      _houseNoController =
          TextEditingController(text: addressParts[1].split(', ')[0]);
      _roadController = TextEditingController(
          text: addressParts[1].split(', ')[1].split(', ')[0]);
      _addressType = addressParts[3].replaceFirst('Type: ', '');
    } else {
      // Adding a new address
      _fullNameController = TextEditingController();
      _phoneController = TextEditingController();
      _altPhoneController = TextEditingController();
      _pincodeController = TextEditingController();
      _stateController = TextEditingController();
      _cityController = TextEditingController();
      _houseNoController = TextEditingController();
      _roadController = TextEditingController();
      _addressType = 'Home';
    }
  }

  String _formatAddress(Map<String, dynamic> addressData) {
    return '${addressData['fullName']}\n'
        '${addressData['houseNo']}, ${addressData['road']}, '
        '${addressData['city']}, ${addressData['state']} - '
        '${addressData['pincode']}\n'
        'Phone: ${addressData['phone']}\n'
        'Type: ${addressData['type']}\n';
  }

  Future<void> _updateAddress() async {
    if (_fullNameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _pincodeController.text.isEmpty ||
        _stateController.text.isEmpty ||
        _cityController.text.isEmpty ||
        _houseNoController.text.isEmpty ||
        _roadController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All required fields must be filled.')),
      );
      return;
    }

    final updatedAddress = _formatAddress({
      'fullName': _fullNameController.text,
      'phone': _phoneController.text,
      'altPhone': _altPhoneController.text,
      'pincode': _pincodeController.text,
      'state': _stateController.text,
      'city': _cityController.text,
      'houseNo': _houseNoController.text,
      'road': _roadController.text,
      'type': _addressType ?? 'Home',
    });

    String userId = _auth.currentUser!.uid;
    DocumentReference userRef = _firestore.collection('users').doc(userId);

    if (widget.address != null) {
      // Remove the old address if editing
      await userRef.update({
        'saved_addresses': FieldValue.arrayRemove([widget.address]),
      });
    }

    // Add the new/updated address
    await userRef.update({
      'saved_addresses': FieldValue.arrayUnion([updatedAddress]),
    });

    Navigator.pop(context);
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Location permissions are permanently denied, we cannot request permissions.')),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    List<Placemark> placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);

    if (placemarks.isNotEmpty) {
      Placemark placemark = placemarks.first;
      setState(() {
        _pincodeController.text = placemark.postalCode ?? '';
        _stateController.text = placemark.administrativeArea ?? '';
        _cityController.text = placemark.locality ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.address == null ? "Add Address" : "Edit Address"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _fullNameController,
              decoration:
                  const InputDecoration(labelText: 'Full Name (Required)*'),
            ),
            TextFormField(
              controller: _phoneController,
              decoration:
                  const InputDecoration(labelText: 'Phone number (Required)*'),
              keyboardType: TextInputType.phone,
            ),
            TextFormField(
              controller: _altPhoneController,
              decoration:
                  const InputDecoration(labelText: 'Alternate Phone Number'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pincodeController,
                    decoration:
                        const InputDecoration(labelText: 'Pincode (Required)*'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _getLocation,
                  child: const Text('Use my location'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration:
                        const InputDecoration(labelText: 'State (Required)*'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration:
                        const InputDecoration(labelText: 'City (Required)*'),
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: _houseNoController,
              decoration: const InputDecoration(
                  labelText: 'House No., Building Name (Required)*'),
            ),
            TextFormField(
              controller: _roadController,
              decoration: const InputDecoration(
                  labelText: 'Road name, Area, Colony (Required)*'),
            ),
            Row(
              children: [
                const Text('Type of address'),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Home'),
                  selected: _addressType == 'Home',
                  onSelected: (selected) {
                    setState(() {
                      _addressType = 'Home';
                    });
                  },
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Work'),
                  selected: _addressType == 'Work',
                  onSelected: (selected) {
                    setState(() {
                      _addressType = 'Work';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _updateAddress,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Save Address'),
                ),
                if (widget.address != null)
                  ElevatedButton(
                    onPressed: () {
                      widget.onRemove(widget.address!);
                      Navigator.pop(context);
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Remove Address'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
