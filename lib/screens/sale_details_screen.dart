import 'package:flutter/material.dart';

import '../models/sale.dart';
import '../models/sale_item.dart';
import '../repositories/product_repository.dart';

class SaleDetailsScreen extends StatefulWidget {
  final ProductRepository repository;
  final String saleId;

  const SaleDetailsScreen({
    super.key,
    required this.repository,
    required this.saleId,
  });

  @override
  State<SaleDetailsScreen> createState() => _SaleDetailsScreenState();
}

class _SaleDetailsScreenState extends State<SaleDetailsScreen> {
  Sale? _sale;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSale();
  }

  Future<void> _loadSale() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sale = await widget.repository.getSale(widget.saleId);

      if (!mounted) return;

      setState(() {
        _sale = sale;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load sale details.';
      });
    }
  }

  String _formatAmount(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    final year = local.year.toString();

    final hour = local.hour == 0 ? 12 : local.hour % 12;

    final minute = local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year '
        '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_sale?.saleNumber ?? 'Sale Details')),
      body: _buildBody(),
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
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadSale,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final sale = _sale!;

    return RefreshIndicator(
      onRefresh: _loadSale,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildSaleHeader(sale),

          const SizedBox(height: 16),

          Text('Products Sold', style: Theme.of(context).textTheme.titleLarge),

          const SizedBox(height: 10),

          ...sale.items.map(_buildSaleItem),

          const SizedBox(height: 16),

          _buildProfitCard(sale),

          const SizedBox(height: 16),

          _buildTotalCard(sale),
        ],
      ),
    );
  }

  Widget _buildSaleHeader(Sale sale) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sale Number',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sale.saleNumber,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.receipt_long,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Divider(),

            const SizedBox(height: 12),

            _buildInfoRow(
              Icons.calendar_today_outlined,
              'Date',
              _formatDate(sale.saleDate),
            ),

            const SizedBox(height: 10),

            _buildInfoRow(
              Icons.payments_outlined,
              'Payment',
              sale.paymentMethod,
            ),

            if (sale.customerName != null &&
                sale.customerName!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInfoRow(
                Icons.person_outline,
                'Customer',
                sale.customerName!,
              ),
            ],

            if (sale.customerMobile != null &&
                sale.customerMobile!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInfoRow(
                Icons.phone_outlined,
                'Mobile',
                sale.customerMobile!,
              ),
            ],

            if (sale.notes != null && sale.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInfoRow(Icons.notes_outlined, 'Notes', sale.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        SizedBox(
          width: 75,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildSaleItem(SaleItem item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemCode,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatAmount(item.lineTotal),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Divider(height: 1),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildItemValue('Quantity', item.quantity.toString()),
                ),
                Expanded(
                  child: _buildItemValue(
                    'Purchase',
                    _formatAmount(item.purchasePrice),
                  ),
                ),
                Expanded(
                  child: _buildItemValue(
                    'Actual Sold',
                    _formatAmount(item.sellingPrice),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Profit: ${_formatAmount(item.profit)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: item.profit >= 0
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildProfitCard(Sale sale) {
    final profit = sale.realizedProfit;

    return Card(
      color: profit >= 0
          ? Colors.green.withValues(alpha: 0.08)
          : Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              profit >= 0 ? Icons.trending_up : Icons.trending_down,
              size: 32,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Realized Profit',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatAmount(profit),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard(Sale sale) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _buildTotalRow('Subtotal', sale.subtotal),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),
            _buildTotalRow('Total', sale.totalAmount, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool bold = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 18 : 15,
            fontWeight: bold ? FontWeight.bold : null,
          ),
        ),
        const Spacer(),
        Text(
          _formatAmount(amount),
          style: TextStyle(
            fontSize: bold ? 20 : 16,
            fontWeight: bold ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }
}
