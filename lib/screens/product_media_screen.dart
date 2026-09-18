import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../services/storage_service.dart';

class ProductMediaScreen extends StatefulWidget {
  final ProductRepository repository;
  final Product product;

  const ProductMediaScreen({
    super.key,
    required this.repository,
    required this.product,
  });

  @override
  State<ProductMediaScreen> createState() => _ProductMediaScreenState();
}

class _ProductMediaScreenState extends State<ProductMediaScreen> {
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _images = [];

  bool _loading = true;
  bool _saving = false;

  String? _videoUrl;

  @override
  void initState() {
    super.initState();

    _videoUrl = widget.product.videoUrl;

    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() {
      _loading = true;
    });

    try {
      final images = await widget.repository.getProductImages(
        widget.product.id,
      );

      if (!mounted) return;

      setState(() {
        _images = images;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load product media: $error')),
      );
    }
  }

  Future<void> _addImages() async {
    if (_saving) return;

    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
        requestFullMetadata: false,
      );

      if (files.isEmpty) return;

      setState(() {
        _saving = true;
      });

      final storage = StorageService(widget.repository.supabase);

      var sortOrder = _images.length;

      for (final pickedFile in files) {
        final file = File(pickedFile.path);

        final imageUrl = await storage.uploadAdditionalProductImage(
          productId: widget.product.id,
          imageFile: file,
        );

        final image = await widget.repository.addProductImage(
          productId: widget.product.id,
          imageUrl: imageUrl,
          sortOrder: sortOrder,
        );

        _images.add(image);

        sortOrder++;
      }

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${files.length} image${files.length == 1 ? '' : 's'} added',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to add images: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _deleteImage(int index) async {
    if (_saving) return;

    final image = _images[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Image?'),
          content: const Text('This additional product image will be deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _saving = true;
      });

      final imageUrl = image['image_url'] as String;

      final storage = StorageService(widget.repository.supabase);

      await widget.repository.deleteProductImage(image['id'] as String);

      await storage.deleteProductMedia(imageUrl);

      _images.removeAt(index);

      await widget.repository.updateProductImageOrders(_images);

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image deleted')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to delete image: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    if (_saving) return;

    try {
      final video = await _picker.pickVideo(source: ImageSource.gallery);

      if (video == null) return;

      setState(() {
        _saving = true;
      });

      final storage = StorageService(widget.repository.supabase);

      final oldVideoUrl = _videoUrl;

      final newVideoUrl = await storage.uploadProductVideo(
        productId: widget.product.id,
        videoFile: File(video.path),
      );

      await widget.repository.updateProductVideo(
        productId: widget.product.id,
        videoUrl: newVideoUrl,
      );

      if (oldVideoUrl != null &&
          oldVideoUrl.trim().isNotEmpty &&
          oldVideoUrl != newVideoUrl) {
        await storage.deleteProductMedia(oldVideoUrl);
      }

      if (!mounted) return;

      setState(() {
        _videoUrl = newVideoUrl;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product video updated')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to upload video: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _deleteVideo() async {
    if (_saving || _videoUrl == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Video?'),
          content: const Text('The product video will be removed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _saving = true;
      });

      final oldVideoUrl = _videoUrl;

      await widget.repository.updateProductVideo(
        productId: widget.product.id,
        videoUrl: null,
      );

      final storage = StorageService(widget.repository.supabase);

      await storage.deleteProductMedia(oldVideoUrl);

      if (!mounted) return;

      setState(() {
        _videoUrl = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product video deleted')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to delete video: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _saveOrder() async {
    try {
      setState(() {
        _saving = true;
      });

      await widget.repository.updateProductImageOrders(_images);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image order saved')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save image order: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildPrimaryImage() {
    final imageUrl = widget.product.imageUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            leading: Icon(Icons.star_outline),
            title: Text('Primary Image'),
            subtitle: Text('This is the existing product image.'),
          ),
          if (imageUrl == null || imageUrl.trim().isEmpty)
            const SizedBox(
              height: 180,
              child: Center(child: Icon(Icons.image_outlined, size: 60)),
            )
          else
            SizedBox(
              height: 220,
              width: double.infinity,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.broken_image_outlined, size: 50),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdditionalImages() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Additional Images',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _addImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _images.isEmpty
                  ? 'No additional images yet.'
                  : 'Drag images to change their order.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            if (_images.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.collections_outlined, size: 42),
                    SizedBox(height: 8),
                    Text('No additional images'),
                  ],
                ),
              )
            else
              SizedBox(
                height: 430,
                child: ReorderableListView.builder(
                  itemCount: _images.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex--;
                      }

                      final item = _images.removeAt(oldIndex);

                      _images.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final image = _images[index];

                    return Card(
                      key: ValueKey(image['id']),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: SizedBox(
                          width: 70,
                          height: 70,
                          child: Image.network(
                            image['image_url'] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.broken_image_outlined);
                            },
                          ),
                        ),
                        title: Text('Image ${index + 2}'),
                        subtitle: Text('Sort order: $index'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.drag_handle),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: _saving
                                  ? null
                                  : () => _deleteImage(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _saveOrder,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Image Order'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Product Video',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _pickVideo,
                  icon: const Icon(Icons.video_library_outlined),
                  label: Text(_videoUrl == null ? 'Add' : 'Replace'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_videoUrl == null || _videoUrl!.trim().isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.video_library_outlined, size: 42),
                    SizedBox(height: 8),
                    Text('No product video'),
                  ],
                ),
              )
            else
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.video_file_outlined, size: 40),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Product video uploaded',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete video',
                          onPressed: _saving ? null : _deleteVideo,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Product Media')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMedia,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.product.itemCode,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.product.productName),
                  const SizedBox(height: 16),
                  _buildPrimaryImage(),
                  const SizedBox(height: 16),
                  _buildAdditionalImages(),
                  const SizedBox(height: 16),
                  _buildVideo(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
