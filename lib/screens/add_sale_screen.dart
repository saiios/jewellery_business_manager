import 'package:flutter/material.dart';

import '../models/product.dart';
import '../repositories/product_repository.dart';

class AddSaleScreen extends StatefulWidget {
  final ProductRepository repository;

  const AddSaleScreen({super.key, required this.repository});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _SaleLine {
  final Product product;
  int quantity;
  final TextEditingController priceController;

  _SaleLine({required this.product, this.quantity = 1})
    : priceController = TextEditingController(
        text: product.sellingPrice.toStringAsFixed(2),
      );

  double get actualSoldPrice =>
      double.tryParse(priceController.text.trim()) ?? 0;

  double get lineTotal => actualSoldPrice * quantity;

  void dispose() {
    priceController.dispose();
  }
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final _formKey = GlobalKey<FormState>();

  final _customerNameController = TextEditingController();
  final _customerMobileController = TextEditingController();
  final _notesController = TextEditingController();

  final List<_SaleLine> _lines = [];

  List<Product> _products = [];
  bool _isLoadingProducts = true;
  bool _isSaving = false;
  String? _errorMessage;

  String _paymentMethod = 'Cash';

  static const List<String> _paymentMethods = [
    'Cash',
    'UPI',
    'Card',
    'Bank Transfer',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerMobileController.dispose();
    _notesController.dispose();

    for (final line in _lines) {
      line.dispose();
    }

    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _errorMessage = null;
    });

    try {
      final products = await widget.repository.getProducts();

      if (!mounted) return;

      setState(() {
        _products = products.where((product) => product.quantity > 0).toList();
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _selectProduct() async {
    if (_isLoadingProducts) return;

    final availableProducts = _products.where((product) {
      return !_lines.any((line) => line.product.id == product.id);
    }).toList();

    if (availableProducts.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No more products available to add.')),
      );
      return;
    }

    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select Product',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: availableProducts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final product = availableProducts[index];

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            product.itemCode.substring(
                              0,
                              product.itemCode.length > 2
                                  ? 2
                                  : product.itemCode.length,
                            ),
                          ),
                        ),
                        title: Text(
                          product.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${product.itemCode} • ${product.category}\n'
                          'Stock: ${product.quantity} • '
                          'Selling price: ₹${product.sellingPrice.toStringAsFixed(2)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context, product);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (product == null || !mounted) return;

    setState(() {
      _lines.add(_SaleLine(product: product));
    });
  }

  void _removeLine(_SaleLine line) {
    setState(() {
      _lines.remove(line);
      line.dispose();
    });
  }

  void _changeQuantity(_SaleLine line, int newQuantity) {
    if (newQuantity < 1) return;

    if (newQuantity > line.product.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only ${line.product.quantity} available for '
            '${line.product.itemCode}.',
          ),
        ),
      );
      return;
    }

    setState(() {
      line.quantity = newQuantity;
    });
  }

  double get _totalAmount {
    return _lines.fold(0, (total, line) => total + line.lineTotal);
  }

  int get _totalQuantity {
    return _lines.fold(0, (total, line) => total + line.quantity);
  }

  Future<void> _completeSale() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product to the sale.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    for (final line in _lines) {
      final price = line.actualSoldPrice;

      if (price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid actual sold price for ${line.product.itemCode}.',
            ),
          ),
        );
        return;
      }

      if (line.quantity > line.product.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient stock for ${line.product.itemCode}.'),
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final sale = await widget.repository.createSale(
        items: _lines.map((line) {
          return {
            'product_id': line.product.id,
            'quantity': line.quantity,
            'selling_price': line.actualSoldPrice,
          };
        }).toList(),
        paymentMethod: _paymentMethod,
        customerName: _customerNameController.text.trim().isEmpty
            ? null
            : _customerNameController.text.trim(),
        customerMobile: _customerMobileController.text.trim().isEmpty
            ? null
            : _customerMobileController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text('Sale Completed'),
              ],
            ),
            content: Text('Sale ${sale.saleNumber} was recorded successfully.'),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to complete sale: ${_cleanError(e)}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _cleanError(Object error) {
    final text = error.toString();

    if (text.contains('Insufficient stock')) {
      return text.replaceFirst(
        RegExp(r'^.*Insufficient stock'),
        'Insufficient stock',
      );
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Sale')),
      body: _isLoadingProducts
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildError()
          : _buildContent(),
      bottomNavigationBar: _isLoadingProducts || _errorMessage != null
          ? null
          : _buildBottomBar(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Unable to load products.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage ?? '', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _buildProductsSection(),
          const SizedBox(height: 20),
          _buildCustomerSection(),
          const SizedBox(height: 20),
          _buildPaymentSection(),
          const SizedBox(height: 20),
          _buildNotesSection(),
        ],
      ),
    );
  }

  Widget _buildProductsSection() {
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
                    'Products',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _selectProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_lines.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 40),
                    SizedBox(height: 8),
                    Text(
                      'No products added',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap Add Product to start the sale.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._lines.map(_buildSaleLine),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleLine(_SaleLine line) {
    final product = line.product;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.itemCode,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        product.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('Available stock: ${product.quantity}'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: _isSaving ? null : () => _removeLine(line),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: line.priceController,
                    enabled: !_isSaving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Actual Sold Price',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      setState(() {});
                    },
                    validator: (value) {
                      final price = double.tryParse(value?.trim() ?? '');

                      if (price == null || price < 0) {
                        return 'Enter valid price';
                      }

                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    const Text('Quantity', style: TextStyle(fontSize: 12)),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _isSaving || line.quantity <= 1
                              ? null
                              : () {
                                  _changeQuantity(line, line.quantity - 1);
                                },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '${line.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        IconButton(
                          onPressed:
                              _isSaving || line.quantity >= product.quantity
                              ? null
                              : () {
                                  _changeQuantity(line, line.quantity + 1);
                                },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Line Total: ₹${line.lineTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerNameController,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                hintText: 'Optional',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerMobileController,
              enabled: !_isSaving,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                hintText: 'Optional',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
              items: _paymentMethods.map((method) {
                return DropdownMenuItem(value: method, child: Text(method));
              }).toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _paymentMethod = value;
                      });
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          controller: _notesController,
          enabled: !_isSaving,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'Optional',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.notes_outlined),
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_totalQuantity item(s)',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '₹${_totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _isSaving ? null : _completeSale,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isSaving ? 'Saving...' : 'Complete Sale'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
