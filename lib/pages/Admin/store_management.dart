import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

class StoreManagementPage extends StatefulWidget {
  const StoreManagementPage({super.key});

  @override
  State<StoreManagementPage> createState() => _StoreManagementPageState();
}

class _StoreManagementPageState extends State<StoreManagementPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  List<dynamic> _imageFiles = [];
  bool _isUploading = false;
  bool _isLoading = false;
  final int _maxImageLimit = 3; // Maximum image limit

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _requestStoragePermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
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

  Future<void> _uploadImagesAndSaveProduct(String? docId) async {
    if (_isUploading) return;

    setState(() => _isUploading = true);
    Navigator.pop(context);

    String name = _nameController.text.trim();
    String price = _priceController.text.trim();
    String quantity = _quantityController.text.trim();

    if (name.isEmpty || price.isEmpty || quantity.isEmpty) {
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
              "store/${DateTime.now().millisecondsSinceEpoch}.jpg";
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
      Map<String, dynamic> productData = {
        'name': name,
        'price': price,
        'quantity': quantity,
        'images': imageUrls,
      };

      if (docId == null) {
        await _firestore.collection('store').add(productData);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Product added successfully!")));
      } else {
        await _firestore.collection('store').doc(docId).update(productData);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Product updated successfully!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save product: ${e.toString()}")));
    } finally {
      setState(() {
        _isUploading = false;
        _imageFiles.clear();
        _nameController.clear();
        _priceController.clear();
        _quantityController.clear();
      });
    }
  }

  Future<void> _deleteProduct(String docId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text(
            "Are you sure you want to delete this product? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await _firestore.collection('store').doc(docId).delete();
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product deleted successfully!")));
    }
  }

  void _showProductDialog({DocumentSnapshot? product}) {
    if (product != null) {
      _nameController.text = product['name'];
      _priceController.text = product['price'];
      _quantityController.text = product['quantity'];
      _imageFiles = List.from(product['images'] ?? []);
    } else {
      _nameController.clear();
      _priceController.clear();
      _quantityController.clear();
      _imageFiles.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        List<dynamic> dialogImageFiles = List.from(_imageFiles);

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(product == null ? "Add Product" : "Edit Product"),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                        controller: _nameController,
                        decoration:
                            const InputDecoration(labelText: "Product Name")),
                    TextField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: "Price"),
                        keyboardType: TextInputType.number),
                    TextField(
                        controller: _quantityController,
                        decoration:
                            const InputDecoration(labelText: "Quantity"),
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 10),
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
                              IconButton(
                                icon: const Icon(Icons.add_a_photo),
                                onPressed: () async {
                                  await _requestStoragePermission();
                                  final XFile? selectedImage = await _picker
                                      .pickImage(source: ImageSource.gallery);
                                  if (selectedImage != null) {
                                    setDialogState(() {
                                      dialogImageFiles.add(selectedImage);
                                      _imageFiles = List.from(dialogImageFiles);
                                    });
                                  }
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 100,
                      width: double.infinity,
                      child: dialogImageFiles.isEmpty
                          ? Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text("No Image Available"),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: dialogImageFiles.map((image) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            border:
                                                Border.all(color: Colors.grey),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: image is String
                                              ? Image.network(image,
                                                  fit: BoxFit.cover)
                                              : Image.file(
                                                  File((image as XFile).path),
                                                  fit: BoxFit.cover),
                                        ),
                                        Positioned(
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () {
                                              setDialogState(() {
                                                dialogImageFiles.remove(image);
                                              });
                                            },
                                            child: const Icon(Icons.close,
                                                color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              TextButton(
                onPressed: _isUploading
                    ? null
                    : () {
                        _imageFiles = List.from(dialogImageFiles);
                        _uploadImagesAndSaveProduct(product?.id);
                      },
                child: Text(product == null ? "Add" : "Update"),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text("Store Management"),
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Products'),
                  Tab(text: 'Store Bookings'),
                ],
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => setState(() {}),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _tabController.index == 0
                      ? () => _showProductDialog()
                      : null, // Only enable "Add" for the Products tab
                ),
              ],
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                ProductsTab(
                  firestore: _firestore,
                  isLoading: _isLoading,
                  onEdit: (product) => _showProductDialog(product: product),
                  onDelete: _deleteProduct,
                  setLoading: (value) => setState(() => _isLoading = value),
                ),
                StoreBookingsTab(firestore: _firestore),
              ],
            ),
          ),
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

// Widget for the Products Tab
class ProductsTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  final bool isLoading;
  final Function(DocumentSnapshot) onEdit;
  final Function(String) onDelete;
  final Function(bool) setLoading;

  const ProductsTab({
    Key? key,
    required this.firestore,
    required this.isLoading,
    required this.onEdit,
    required this.onDelete,
    required this.setLoading,
  }) : super(key: key);

  Stream<QuerySnapshot> _getProductsStream() {
    return firestore.collection('store').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _getProductsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No products found"));
        }

        var products = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          itemBuilder: (context, index) {
            var product = products[index];
            List<dynamic> imageUrls = product['images'] ?? [];

            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: imageUrls.isNotEmpty
                    ? Image.network(imageUrls.first,
                        width: 50, height: 50, fit: BoxFit.cover)
                    : Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(child: Text("No Image"))),
                title: Text(product['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    "Price: ₹${product['price']}\nQuantity: ${product['quantity']}",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => onEdit(product)),
                    IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => onDelete(product.id)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Widget for the Store Bookings Tab
class StoreBookingsTab extends StatefulWidget {
  final FirebaseFirestore firestore;

  const StoreBookingsTab({Key? key, required this.firestore})
      : super(key: key);

  @override
  _StoreBookingsTabState createState() => _StoreBookingsTabState();
}

class _StoreBookingsTabState extends State<StoreBookingsTab> {
  final TextEditingController _trackingIdController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'Order Placed';
  String _sortOption = 'Purchase Date (Newest First)';

  // List of possible statuses for the dropdown
  final List<String> _statusOptions = [
    'Order Placed',
    'Shipped',
    'In Transit',
    'Delivered',
    'completed',
    'Cancelled',
  ];

  // Sort options
  final List<String> _sortOptions = [
    'Purchase Date (Newest First)',
    'Purchase Date (Oldest First)',
    'Status (A-Z)',
  ];

  // Extract phone number from address (assuming format: "Phone: 1234567890" at the end)
  String _extractPhoneNumber(String? address) {
    if (address == null) return 'N/A';
    final phoneMatch = RegExp(r'Phone:\s*(\d+)').firstMatch(address);
    return phoneMatch?.group(1) ?? 'N/A';
  }

  void _showTrackingDialog(DocumentSnapshot booking) {
    final bookingData = booking.data() as Map<String, dynamic>;
    _trackingIdController.text = bookingData['tracking_id'] ?? '';
    _selectedStatus = _statusOptions.contains(bookingData['status']?.toLowerCase())
        ? bookingData['status']?.toLowerCase() ?? 'Order Placed'
        : 'Order Placed';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Update Tracking Details"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _trackingIdController,
                  decoration: const InputDecoration(labelText: "Tracking ID"),
                ),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  value: _selectedStatus,
                  isExpanded: true,
                  items: _statusOptions.map((String status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setDialogState(() {
                        _selectedStatus = newValue;
                      });
                    }
                  },
                  hint: const Text('Select Status'),
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
              onPressed: () async {
                try {
                  await widget.firestore
                      .collection('store_bookings')
                      .doc(booking.id)
                      .update({
                    'tracking_id': _trackingIdController.text.trim().isNotEmpty
                        ? _trackingIdController.text.trim()
                        : FieldValue.delete(),
                    'status': _selectedStatus,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Tracking details updated successfully!")),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text("Failed to update tracking details: $e")),
                  );
                }
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort By'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _sortOptions.map((String option) {
              return RadioListTile<String>(
                title: Text(option),
                value: option,
                groupValue: _sortOption,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _sortOption = newValue;
                    });
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _trackingIdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search by User ID, Booking ID, or Phone',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showSortDialog,
                tooltip: 'Sort',
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.firestore
                .collection('store_bookings')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No store bookings found.'));
              }

              var bookings = snapshot.data!.docs;

              // Filter bookings based on search
              String searchQuery = _searchController.text.toLowerCase();
              if (searchQuery.isNotEmpty) {
                bookings = bookings.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final userId = data['user_id']?.toString().toLowerCase() ?? '';
                  final bookingId = data['booking_id']?.toString().toLowerCase() ?? '';
                  final phone = _extractPhoneNumber(data['address'])?.toLowerCase() ?? '';
                  return userId.contains(searchQuery) ||
                      bookingId.contains(searchQuery) ||
                      phone.contains(searchQuery);
                }).toList();
              }

              // Sort bookings
              if (_sortOption == 'Purchase Date (Oldest First)') {
                bookings.sort((a, b) {
                  final aDate = (a.data() as Map<String, dynamic>)['purchase_date'] as Timestamp?;
                  final bDate = (b.data() as Map<String, dynamic>)['purchase_date'] as Timestamp?;
                  return (aDate?.toDate() ?? DateTime(0)).compareTo(bDate?.toDate() ?? DateTime(0));
                });
              } else if (_sortOption == 'Purchase Date (Newest First)') {
                bookings.sort((a, b) {
                  final aDate = (a.data() as Map<String, dynamic>)['purchase_date'] as Timestamp?;
                  final bDate = (b.data() as Map<String, dynamic>)['purchase_date'] as Timestamp?;
                  return (bDate?.toDate() ?? DateTime(0)).compareTo(aDate?.toDate() ?? DateTime(0));
                });
              } else if (_sortOption == 'Status (A-Z)') {
                bookings.sort((a, b) {
                  final aStatus = (a.data() as Map<String, dynamic>)['status'] ?? '';
                  final bStatus = (b.data() as Map<String, dynamic>)['status'] ?? '';
                  return aStatus.toString().compareTo(bStatus.toString());
                });
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  final booking = bookings[index];
                  final bookingData = booking.data() as Map<String, dynamic>;

                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ExpansionTile(
                      leading: const Icon(Icons.receipt, color: Colors.blue),
                      title: Text(
                        bookingData['item_name'] ?? 'Unnamed Order',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'User: ${bookingData['user_id'] ?? 'N/A'}, '
                        'Booking: ${bookingData['booking_id'] ?? 'N/A'}, '
                        'Phone: ${_extractPhoneNumber(bookingData['address'])}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      children: [
                        ListTile(
                          title: Text('Address: ${bookingData['address'] ?? 'N/A'}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Item ID: ${bookingData['item_id'] ?? 'N/A'}'),
                              Text('Quantity: ${bookingData['quantity'] ?? 0}'),
                              Text('Amount: ₹${bookingData['total_amount'] ?? 0}'),
                              Text(
                                'Date: ${bookingData['purchase_date'] != null ? (bookingData['purchase_date'] as Timestamp).toDate().toString().split(' ')[0] : 'N/A'}',
                              ),
                              Text('Payment ID: ${bookingData['payment_id'] ?? 'N/A'}'),
                              Text('Status: ${bookingData['status'] ?? 'Order Placed'}'),
                              if (bookingData.containsKey('tracking_id') &&
                                  bookingData['tracking_id'] != null &&
                                  bookingData['tracking_id'].toString().isNotEmpty)
                                Text('Tracking ID: ${bookingData['tracking_id']}'),
                            ],
                          ),
                        ),
                      ],
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showTrackingDialog(booking),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}