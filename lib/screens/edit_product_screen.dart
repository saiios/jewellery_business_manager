import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jewel_admin/services/storage_service.dart';

import '../models/product.dart';
import '../repositories/product_repository.dart';

class EditProductScreen extends StatefulWidget {
  final ProductRepository repository;
  final Product product;

  const EditProductScreen({
    super.key,
    required this.repository,
    required this.product,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _productNameController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _quantityController;

  bool _isSaving = false;
  final ImagePicker _imagePicker = ImagePicker();

  File? _newImage;
  File? _newVideo;

  bool _removeImage = false;
  bool _removeVideo = false;
  @override
  void initState() {
    super.initState();

    _productNameController = TextEditingController(
      text: widget.product.productName,
    );

    _purchasePriceController = TextEditingController(
      text: widget.product.purchasePrice.toStringAsFixed(2),
    );

    _sellingPriceController = TextEditingController(
      text: widget.product.sellingPrice.toStringAsFixed(2),
    );

    _quantityController = TextEditingController(
      text: widget.product.quantity.toString(),
    );
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();

    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        requestFullMetadata: false,
      );

      if (image == null) return;

      setState(() {
        _newImage = File(image.path);
        _removeImage = false;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to select image: $error')));
    }
  }

  Future<void> _pickVideo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Record Video'),
                onTap: () {
                  Navigator.pop(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final video = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30),
      );

      if (video == null) return;

      setState(() {
        _newVideo = File(video.path);
        _removeVideo = false;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to select video: $error')));
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedProduct = Product(
        id: widget.product.id,
        productName: _productNameController.text.trim(),
        imageUrl: widget.product.imageUrl,
        videoUrl: widget.product.videoUrl,
        purchasePrice: double.parse(_purchasePriceController.text.trim()),
        sellingPrice: double.parse(_sellingPriceController.text.trim()),
        quantity: int.parse(_quantityController.text.trim()),
        status: widget.product.status,
        createdAt: widget.product.createdAt,
        updatedAt: widget.product.updatedAt,
      );

      await widget.repository.updateProduct(updatedProduct);

      final storageService = StorageService(widget.repository.supabase);

      // -----------------------------
      // IMAGE
      // -----------------------------

      if (_newImage != null) {
        final oldImageUrl = widget.product.imageUrl;

        final newImageUrl = await storageService.uploadProductImage(
          productId: widget.product.id,
          imageFile: _newImage!,
        );

        await widget.repository.updateProductImage(
          productId: widget.product.id,
          imageUrl: newImageUrl,
        );

        if (oldImageUrl != null && oldImageUrl != newImageUrl) {
          await storageService.deleteProductMedia(oldImageUrl);
        }
      } else if (_removeImage) {
        final oldImageUrl = widget.product.imageUrl;

        await widget.repository.updateProductImage(
          productId: widget.product.id,
          imageUrl: null,
        );

        await storageService.deleteProductMedia(oldImageUrl);
      }

      // -----------------------------
      // VIDEO
      // -----------------------------

      if (_newVideo != null) {
        final oldVideoUrl = widget.product.videoUrl;

        final newVideoUrl = await storageService.uploadProductVideo(
          productId: widget.product.id,
          videoFile: _newVideo!,
        );

        await widget.repository.updateProductVideo(
          productId: widget.product.id,
          videoUrl: newVideoUrl,
        );

        if (oldVideoUrl != null && oldVideoUrl != newVideoUrl) {
          await storageService.deleteProductMedia(oldVideoUrl);
        }
      } else if (_removeVideo) {
        final oldVideoUrl = widget.product.videoUrl;

        await widget.repository.updateProductVideo(
          productId: widget.product.id,
          videoUrl: null,
        );

        await storageService.deleteProductMedia(oldVideoUrl);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product updated successfully')),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update product: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    return null;
  }

  String? _validatePrice(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    final price = double.tryParse(value.trim());

    if (price == null) {
      return 'Enter a valid $fieldName';
    }

    if (price < 0) {
      return '$fieldName cannot be negative';
    }

    return null;
  }

  String? _validateQuantity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Quantity is required';
    }

    final quantity = int.tryParse(value.trim());

    if (quantity == null) {
      return 'Enter a valid quantity';
    }

    if (quantity < 0) {
      return 'Quantity cannot be negative';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Product')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _productNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  return _validateRequired(value, 'Product name');
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _purchasePriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Purchase Price',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  return _validatePrice(value, 'purchase price');
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _sellingPriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Selling Price',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  return _validatePrice(value, 'selling price');
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                validator: _validateQuantity,
              ),
              const SizedBox(height: 24),

              Text(
                'Product Image',
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 8),

              if (_newImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _newImage!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else if (!_removeImage && widget.product.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.product.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        height: 180,
                        child: Center(
                          child: Icon(Icons.broken_image_outlined, size: 50),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        widget.product.imageUrl == null && _newImage == null
                            ? 'Add Image'
                            : 'Change Image',
                      ),
                    ),
                  ),
                  if (!_removeImage &&
                      (_newImage != null ||
                          widget.product.imageUrl != null)) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remove image',
                      onPressed: () {
                        setState(() {
                          _newImage = null;
                          _removeImage = true;
                        });
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),

              Text(
                'Product Video',
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 8),

              if (!_removeVideo &&
                  (_newVideo != null || widget.product.videoUrl != null))
                Row(
                  children: [
                    const Icon(Icons.video_file_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _newVideo != null
                            ? _newVideo!.path.split('/').last
                            : 'Existing product video',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.videocam_outlined),
                      label: Text(
                        widget.product.videoUrl == null && _newVideo == null
                            ? 'Add Video'
                            : 'Change Video',
                      ),
                    ),
                  ),
                  if (!_removeVideo &&
                      (_newVideo != null ||
                          widget.product.videoUrl != null)) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remove video',
                      onPressed: () {
                        setState(() {
                          _newVideo = null;
                          _removeVideo = true;
                        });
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),
              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProduct,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
