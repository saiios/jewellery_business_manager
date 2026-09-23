import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:jewel_admin/screens/add_sale_screen.dart';
import 'package:jewel_admin/screens/business_summary_screen.dart';
import 'package:jewel_admin/screens/edit_product_screen.dart';
import 'package:jewel_admin/screens/product_details_screen.dart';
import 'package:jewel_admin/screens/product_media_screen.dart';
import 'package:jewel_admin/services/notification_service.dart';
import 'package:jewel_admin/services/whatsapp_service.dart';
import 'package:jewel_admin/screens/customer_orders_screen.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import 'add_product_screen.dart';

class ProductListScreen extends StatefulWidget {
  final ProductRepository repository;

  const ProductListScreen({super.key, required this.repository});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<Product> _products = [];

  final TextEditingController _searchController = TextEditingController();

  final NotificationService _notificationService = NotificationService();

  String _searchQuery = '';

  bool _isLoading = true;
  String? _errorMessage;

  bool _showPurchasePrice = false;

  String? _selectedCategory;

  String _stockFilter = 'All';

  String _sortOption = 'Newest';

  static const List<String> _categories = [
    'Earrings',
    'Jhumkas',
    'Necklaces',
    'Necklace Sets',
    'Bangles',
    'Bracelets',
    'Rings',
    'Black Beads',
    'Mangalsutra',
    'Temple Jewellery',
    'Antique Jewellery',
    'Bridal',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = _products.where((product) {
      final matchesSearch =
          query.isEmpty ||
          product.itemCode.toLowerCase().contains(query) ||
          product.productName.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);

      final matchesCategory =
          _selectedCategory == null || product.category == _selectedCategory;

      final matchesStock = switch (_stockFilter) {
        'Available' => product.quantity > 0,
        'Sold Out' => product.quantity == 0,
        _ => true,
      };

      return matchesSearch && matchesCategory && matchesStock;
    }).toList();

    switch (_sortOption) {
      case 'Price: Low → High':
        filtered.sort((a, b) => a.sellingPrice.compareTo(b.sellingPrice));
        break;

      case 'Price: High → Low':
        filtered.sort((a, b) => b.sellingPrice.compareTo(a.sellingPrice));
        break;

      case 'Newest':
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return filtered;
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products = await widget.repository.getProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load products.\n$error';
      });
    }
  }

  Future<void> _manageMedia(Product product) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProductMediaScreen(repository: widget.repository, product: product),
      ),
    );

    if (result == true) {
      await _loadProducts();
    }
  }

  Future<void> _editProduct(Product product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditProductScreen(repository: widget.repository, product: product),
      ),
    );

    if (result == true) {
      await _loadProducts();
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Product?'),
          content: Text(
            'Are you sure you want to delete '
            '"${product.productName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await widget.repository.deleteProduct(product.id);

      if (!mounted) return;

      setState(() {
        _products.removeWhere((item) => item.id == product.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete product: $error')),
      );
    }
  }

  Future<void> _sendProductNotification(Product product) async {
    final titleController = TextEditingController(text: '✨ New Jewellery Pick');

    final messageController = TextEditingController(
      text:
          '${product.productName} is available now at Devi Jewels. Tap to view.',
    );

    bool isSending = false;

    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final hasOffer = product.mrp > product.sellingPrice;

              final discount = hasOffer && product.mrp > 0
                  ? ((product.mrp - product.sellingPrice) / product.mrp * 100)
                        .round()
                  : 0;

              return AlertDialog(
                title: const Text('Send Product Notification?'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product.imageUrl != null &&
                          product.imageUrl!.trim().isNotEmpty)
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: product.imageUrl!,
                              width: 140,
                              height: 140,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const SizedBox(
                                width: 140,
                                height: 140,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 140,
                                height: 140,
                                color: Colors.grey.shade100,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      Text(
                        product.productName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Item: ${product.itemCode}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),

                      const SizedBox(height: 8),

                      if (hasOffer)
                        Row(
                          children: [
                            Text(
                              '₹${product.mrp.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${product.sellingPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$discount% OFF',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'Price: ₹${product.sellingPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: titleController,
                        enabled: !isSending,
                        decoration: const InputDecoration(
                          labelText: 'Notification title',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: messageController,
                        enabled: !isSending,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notification message',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSending
                        ? null
                        : () {
                            Navigator.pop(dialogContext, false);
                          },
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: isSending
                        ? null
                        : () async {
                            final title = titleController.text.trim();

                            final message = messageController.text.trim();

                            if (title.isEmpty || message.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Title and message are required.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              isSending = true;
                            });

                            try {
                              final result = await _notificationService
                                  .sendProductNotification(
                                    productId: product.id,
                                    itemCode: product.itemCode,
                                    title: title,
                                    message: message,
                                  );

                              if (!context.mounted) {
                                return;
                              }

                              Navigator.pop(dialogContext, true);

                              if (result.recipientCount == 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Notification saved, but no Android customers are registered for push notifications yet.',
                                    ),
                                  ),
                                );
                              } else if (result.failedCount > 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Notification sent to '
                                      '${result.successCount} customers. '
                                      '${result.failedCount} failed.',
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Notification sent to '
                                      '${result.successCount} customers.',
                                    ),
                                  ),
                                );
                              }
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }

                              setDialogState(() {
                                isSending = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Unable to send notification: $error',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.notifications_active_outlined),
                    label: Text(isSending ? 'Sending...' : 'Send Notification'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      titleController.dispose();
      messageController.dispose();
    }
  }

  Future<void> _addProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(repository: widget.repository),
      ),
    );

    if (result == true) {
      await _loadProducts();
    }
  }

  Future<void> _openProductDetails(Product product) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(
          repository: widget.repository,
          product: product,
          showPurchasePrice: _showPurchasePrice,
        ),
      ),
    );

    if (result == true) {
      await _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jewellery Products'),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Purchase', style: TextStyle(fontSize: 12)),
              Switch(
                value: _showPurchasePrice,
                onChanged: (value) {
                  setState(() {
                    _showPurchasePrice = value;
                  });
                },
              ),
            ],
          ),
          IconButton(
            tooltip: 'Customer Orders',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CustomerOrdersScreen(repository: widget.repository),
                ),
              );
            },
            icon: const Icon(Icons.shopping_bag_outlined),
          ),
          IconButton(
            tooltip: 'New Sale',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddSaleScreen(repository: widget.repository),
                ),
              );

              if (result == true && mounted) {
                await _loadProducts();
              }
            },
            icon: const Icon(Icons.point_of_sale_outlined),
          ),

          IconButton(
            tooltip: 'Business Summary',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BusinessSummaryScreen(repository: widget.repository),
                ),
              );
            },
            icon: const Icon(Icons.analytics_outlined),
          ),

          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadProducts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search item code or product name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();

                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          /*
           * ------------------------------------------------------
           * STOCK FILTER
           * ------------------------------------------------------
           */
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildStockChip('All'),
                _buildStockChip('Available'),
                _buildStockChip('Sold Out'),
              ],
            ),
          ),

          /*
           * ------------------------------------------------------
           * CATEGORY FILTER
           * ------------------------------------------------------
           */
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All Categories'),
                    selected: _selectedCategory == null,
                    onSelected: (_) {
                      setState(() {
                        _selectedCategory = null;
                      });
                    },
                  ),
                ),
                ..._categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          /*
           * ------------------------------------------------------
           * SORT
           * ------------------------------------------------------
           */
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.sort, size: 20),
                const SizedBox(width: 8),
                const Text('Sort by'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sortOption,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Newest', child: Text('Newest')),
                      DropdownMenuItem(
                        value: 'Price: Low → High',
                        child: Text('Price: Low → High'),
                      ),
                      DropdownMenuItem(
                        value: 'Price: High → Low',
                        child: Text('Price: High → Low'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _sortOption = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        tooltip: 'Add Product',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStockChip(String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(value),
        selected: _stockFilter == value,
        onSelected: (_) {
          setState(() {
            _stockFilter = value;
          });
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProducts,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadProducts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(Icons.inventory_2_outlined, size: 64),
            SizedBox(height: 16),
            Center(
              child: Text(
                'No products yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Tap + to add your first '
                'jewellery product.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    final filteredProducts = _filteredProducts;

    if (filteredProducts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.search_off, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Center(
            child: Text(
              'No matching products',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: filteredProducts.length,
        itemBuilder: (context, index) {
          final product = filteredProducts[index];

          return _ProductCard(
            product: product,
            showPurchasePrice: _showPurchasePrice,
            onEdit: () => _editProduct(product),
            onManageMedia: () => _manageMedia(product),
            onDelete: () => _deleteProduct(product),
            onSendNotification: () => _sendProductNotification(product),
            onTap: () => _openProductDetails(product),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool showPurchasePrice;

  final VoidCallback onEdit;
  final VoidCallback onManageMedia;
  final VoidCallback onDelete;
  final VoidCallback onSendNotification;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.showPurchasePrice,
    required this.onTap,
    required this.onEdit,
    required this.onManageMedia,
    required this.onDelete,
    required this.onSendNotification,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = product.quantity > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductImage(imageUrl: product.imageUrl),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.itemCode,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      product.category,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      product.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    if (showPurchasePrice) ...[
                      Text(
                        'Purchase: ₹${product.purchasePrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                    ],

                    if (product.mrp > product.sellingPrice) ...[
                      Row(
                        children: [
                          Text(
                            '₹${product.mrp.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),

                          const SizedBox(width: 8),

                          Text(
                            '₹${product.sellingPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(width: 8),

                          _DiscountBadge(
                            mrp: product.mrp,
                            sellingPrice: product.sellingPrice,
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'MRP: ₹${product.mrp.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],

                    const SizedBox(height: 6),

                    Text(
                      product.quantity > 0
                          ? '${product.quantity} ${product.quantity == 1 ? 'piece' : 'pieces'}'
                          : 'Sold Out',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isAvailable ? Colors.green : Colors.red,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Share',
                          icon: const Icon(Icons.share_outlined),
                          onPressed: () async {
                            try {
                              await WhatsAppService.shareProduct(product);
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Unable to share product: $error',
                                  ),
                                ),
                              );
                            }
                          },
                        ),

                        IconButton(
                          tooltip: 'Send Notification',
                          icon: const Icon(Icons.notifications_active_outlined),
                          onPressed: onSendNotification,
                        ),

                        IconButton(
                          tooltip: 'Edit',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),

                        IconButton(
                          tooltip: 'Manage Media',
                          onPressed: onManageMedia,
                          icon: const Icon(Icons.perm_media_outlined),
                        ),

                        IconButton(
                          tooltip: 'Delete',
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  final double mrp;
  final double sellingPrice;

  const _DiscountBadge({required this.mrp, required this.sellingPrice});

  @override
  Widget build(BuildContext context) {
    if (mrp <= 0 || sellingPrice >= mrp) {
      return const SizedBox.shrink();
    }

    final discount = ((mrp - sellingPrice) / mrp * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$discount% OFF',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.green.shade700,
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;

  const _ProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_outlined, size: 36, color: Colors.grey),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        placeholder: (context, url) => const SizedBox(
          width: 90,
          height: 90,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) {
          return Container(
            width: 90,
            height: 90,
            color: Colors.grey.shade100,
            child: const Icon(
              Icons.broken_image_outlined,
              size: 36,
              color: Colors.grey,
            ),
          );
        },
      ),
    );
  }
}
