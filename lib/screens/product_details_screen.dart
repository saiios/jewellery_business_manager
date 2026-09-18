import 'package:flutter/material.dart';
import 'package:jewel_admin/screens/product_media_screen.dart';
import 'package:video_player/video_player.dart';

import '../models/product.dart';
import '../models/sale_item.dart';
import '../repositories/product_repository.dart';
import '../services/whatsapp_service.dart';
import 'edit_product_screen.dart';
import 'sale_details_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final ProductRepository repository;
  final Product product;
  final bool showPurchasePrice;

  const ProductDetailsScreen({
    super.key,
    required this.repository,
    required this.product,
    required this.showPurchasePrice,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  VideoPlayerController? _videoController;
  Future<void>? _videoInitialization;

  List<SaleItem> _sales = [];
  bool _salesLoading = true;
  String? _salesError;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _loadSalesHistory();
  }

  void _initializeVideo() {
    final videoUrl = widget.product.videoUrl;

    if (videoUrl == null || videoUrl.trim().isEmpty) {
      return;
    }

    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

    _videoInitialization = _videoController!.initialize();
  }

  Future<void> _loadSalesHistory() async {
    setState(() {
      _salesLoading = true;
      _salesError = null;
    });

    try {
      final sales = await widget.repository.getProductSales(widget.product.id);

      if (!mounted) return;

      setState(() {
        _sales = sales;
        _salesLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _salesLoading = false;
        _salesError = error.toString();
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _shareProduct() async {
    try {
      await WhatsAppService.shareProduct(widget.product);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to share product: $error')),
      );
    }
  }

  Future<void> _editProduct() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductScreen(
          repository: widget.repository,
          product: widget.product,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _openSaleDetails(String saleId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SaleDetailsScreen(repository: widget.repository, saleId: saleId),
      ),
    );
  }

  void _openFullImage() {
    final imageUrl = widget.product.imageUrl;

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 64,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImage() {
    final imageUrl = widget.product.imageUrl;

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return Container(
        height: 320,
        width: double.infinity,
        color: Colors.grey.shade100,
        child: const Icon(Icons.image_outlined, size: 80, color: Colors.grey),
      );
    }

    return GestureDetector(
      onTap: _openFullImage,
      child: SizedBox(
        height: 320,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade100,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text(
                      'View full image',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (_videoController == null || _videoInitialization == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Product Video',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        FutureBuilder<void>(
          future: _videoInitialization,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError || !_videoController!.value.isInitialized) {
              return Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey.shade100,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Unable to play video'),
                  ],
                ),
              );
            }

            return Column(
              children: [
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
                VideoProgressIndicator(
                  _videoController!,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 36,
                      icon: Icon(
                        _videoController!.value.isPlaying
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_videoController!.value.isPlaying) {
                            _videoController!.pause();
                          } else {
                            _videoController!.play();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildInformation() {
    final product = widget.product;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.productName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Text(
            'Item Code',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            product.itemCode,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),

          Text(
            'Category',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            product.category,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),

          if (widget.showPurchasePrice) ...[
            Text(
              'Purchase Price',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              '₹${product.purchasePrice.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 14),
          ],

          Text(
            'Selling Price',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            '₹${product.sellingPrice.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),

          Text(
            'Quantity',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            '${product.quantity} pieces',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Icon(
                product.quantity > 0 ? Icons.check_circle : Icons.cancel,
                size: 20,
                color: product.quantity > 0 ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                product.quantity > 0 ? 'Available' : 'Sold Out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: product.quantity > 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesHistory() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sales History',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (_sales.isNotEmpty)
                Text(
                  '${_sales.fold<int>(0, (sum, item) => sum + item.quantity)} sold',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_salesLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_salesError != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Unable to load sales history.')),
                    TextButton(
                      onPressed: _loadSalesHistory,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_sales.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No sales recorded for this product yet.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._sales.map(_buildSaleHistoryItem),
        ],
      ),
    );
  }

  Widget _buildSaleHistoryItem(SaleItem saleItem) {
    final saleDate = saleItem.createdAt.toLocal();

    final saleDateText =
        '${saleDate.day.toString().padLeft(2, '0')}/'
        '${saleDate.month.toString().padLeft(2, '0')}/'
        '${saleDate.year}';

    final profit = saleItem.profit;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openSaleDetails(saleItem.saleId),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      saleDateText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '₹${saleItem.lineTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(child: Text('Qty: ${saleItem.quantity}')),
                  Expanded(
                    child: Text(
                      'Sold: ₹${saleItem.sellingPrice.toStringAsFixed(0)}',
                    ),
                  ),
                ],
              ),

              if (widget.showPurchasePrice) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cost: ₹${saleItem.purchasePrice.toStringAsFixed(0)}',
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Profit: ₹${profit.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: profit >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 8),

              Row(
                children: [
                  Text(
                    'View sale details',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _manageMedia() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductMediaScreen(
          repository: widget.repository,
          product: widget.product,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _manageMedia,
              icon: const Icon(Icons.perm_media_outlined),
              label: const Text('Manage Media'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareProduct,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _editProduct,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: RefreshIndicator(
        onRefresh: _loadSalesHistory,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(),
              _buildVideo(),
              _buildInformation(),
              _buildSalesHistory(),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }
}
