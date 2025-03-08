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

class _StoreManagementPageState extends State<StoreManagementPage> {
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

  Stream<QuerySnapshot> _getProductsStream() {
    return _firestore.collection('store').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("Store Management"),
            actions: [
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => setState(() {})),
              IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showProductDialog()),
            ],
          ),
          body: StreamBuilder(
            stream: _getProductsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  _isLoading) {
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
                              onPressed: () =>
                                  _showProductDialog(product: product)),
                          IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteProduct(product.id)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
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
    );
  }
}
