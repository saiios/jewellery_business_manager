import 'package:flutter/material.dart';
import 'package:jewel_admin/screens/sale_details_screen.dart';

import '../models/sale.dart';
import '../repositories/product_repository.dart';

class SalesHistoryScreen extends StatefulWidget {
  final ProductRepository repository;

  const SalesHistoryScreen({super.key, required this.repository});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<Sale> _sales = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sales = await widget.repository.getSales();

      if (!mounted) return;

      setState(() {
        _sales = sales;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load sales history.';
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
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadSales,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadSales, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _sales.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _sales.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Center(child: Text(_errorMessage!, textAlign: TextAlign.center)),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _loadSales,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ),
        ],
      );
    }

    if (_sales.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 100),
          Icon(Icons.receipt_long_outlined, size: 64),
          SizedBox(height: 16),
          Center(
            child: Text(
              'No sales yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'Completed sales will appear here.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: _sales.length,
      itemBuilder: (context, index) {
        final sale = _sales[index];

        return _buildSaleCard(sale);
      },
    );
  }

  Widget _buildSaleCard(Sale sale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SaleDetailsScreen(
                repository: widget.repository,
                saleId: sale.id,
              ),
            ),
          );

          if (mounted) {
            await _loadSales();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sale.saleNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    _formatAmount(sale.totalAmount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(_formatDate(sale.saleDate)),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(sale.paymentMethod),
                  const Spacer(),
                  if (sale.customerName != null &&
                      sale.customerName!.trim().isNotEmpty)
                    Flexible(
                      child: Text(
                        sale.customerName!,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              const Divider(height: 1),

              const SizedBox(height: 10),

              Row(
                children: [
                  Text(
                    'Tap to view details',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
