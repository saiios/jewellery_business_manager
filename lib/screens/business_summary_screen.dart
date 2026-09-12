import 'package:flutter/material.dart';
import 'package:jewel_admin/screens/sales_history_screen.dart';

import '../models/inventory_summary.dart';
import '../repositories/product_repository.dart';

class BusinessSummaryScreen extends StatefulWidget {
  final ProductRepository repository;

  const BusinessSummaryScreen({super.key, required this.repository});

  @override
  State<BusinessSummaryScreen> createState() => _BusinessSummaryScreenState();
}

class _BusinessSummaryScreenState extends State<BusinessSummaryScreen> {
  InventorySummary? _summary;

  bool _isLoading = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary = await widget.repository.getInventorySummary();

      if (!mounted) return;

      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load business summary.';
      });
    }
  }

  String _formatAmount(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Summary'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadSummary,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadSummary, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _summary == null) {
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
              onPressed: _loadSummary,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ),
        ],
      );
    }

    final summary = _summary!;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // ========================================================
        // ACTUAL SALES
        // ========================================================
        Text('Sales', style: Theme.of(context).textTheme.titleLarge),

        const SizedBox(height: 12),

        _buildClickableMoneyCard(
          title: 'Total Sales Revenue',
          amount: _formatAmount(summary.totalSalesRevenue),
          subtitle: 'Actual money recorded from completed sales',
          icon: Icons.currency_rupee,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SalesHistoryScreen(repository: widget.repository),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        _buildClickableMoneyCard(
          title: 'Realized Profit',
          amount: _formatAmount(summary.realizedProfit),
          subtitle: 'Actual sales revenue minus cost of items sold',
          icon: Icons.trending_up,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SalesHistoryScreen(repository: widget.repository),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        _buildClickableMoneyCard(
          title: 'Cost of Sold Items',
          amount: _formatAmount(summary.totalCostOfSoldItems),
          subtitle: 'Purchase cost of jewellery already sold',
          icon: Icons.shopping_cart_checkout,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SalesHistoryScreen(repository: widget.repository),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildClickableOverviewCard(
                icon: Icons.receipt_long_outlined,
                value: summary.totalSales.toString(),
                label: 'Sales',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SalesHistoryScreen(repository: widget.repository),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildClickableOverviewCard(
                icon: Icons.sell_outlined,
                value: summary.itemsSold.toString(),
                label: 'Items Sold',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SalesHistoryScreen(repository: widget.repository),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ========================================================
        // CURRENT STOCK
        // ========================================================
        Text('Current Stock', style: Theme.of(context).textTheme.titleLarge),

        const SizedBox(height: 12),

        _buildMainMoneyCard(
          title: 'Current Stock Cost',
          amount: _formatAmount(summary.currentStockPurchaseValue),
          subtitle: 'Purchase cost of jewellery still in stock',
          icon: Icons.inventory_2_outlined,
        ),

        const SizedBox(height: 12),

        _buildMainMoneyCard(
          title: 'Current Stock Selling Value',
          amount: _formatAmount(summary.currentStockSellingValue),
          subtitle: 'Value using each product\'s current selling price',
          icon: Icons.sell_outlined,
        ),

        const SizedBox(height: 12),

        _buildMainMoneyCard(
          title: 'Potential Profit on Remaining Stock',
          amount: _formatAmount(summary.potentialProfit),
          subtitle: 'Current stock selling value minus stock cost',
          icon: Icons.trending_up,
        ),

        const SizedBox(height: 20),

        Text('Stock Overview', style: Theme.of(context).textTheme.titleLarge),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                icon: Icons.inventory_2_outlined,
                value: summary.itemsRemaining.toString(),
                label: 'Items Remaining',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOverviewCard(
                icon: Icons.category_outlined,
                value: summary.productDesigns.toString(),
                label: 'Product Designs',
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _buildOverviewCard(
          icon: Icons.category_outlined,
          value: summary.categories.toString(),
          label: 'Categories With Stock',
          fullWidth: true,
        ),

        const SizedBox(height: 24),

        _buildInfoCard(),
      ],
    );
  }

  Widget _buildClickableMoneyCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: _buildMainMoneyCard(
          title: title,
          amount: amount,
          subtitle: subtitle,
          icon: icon,
        ),
      ),
    );
  }

  Widget _buildClickableOverviewCard({
    required IconData icon,
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                icon,
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainMoneyCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    amount,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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

  Widget _buildOverviewCard({
    required IconData icon,
    required String value,
    required String label,
    bool fullWidth = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Realized Profit is based only on completed sales '
                'and the actual sold price recorded for each item. '
                'Remaining stock is valued using the current selling '
                'price entered for each product.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
