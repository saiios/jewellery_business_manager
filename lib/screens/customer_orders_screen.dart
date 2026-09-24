import 'package:flutter/material.dart';

import '../models/customer_order_admin.dart';
import '../repositories/product_repository.dart';
import 'customer_order_details_screen.dart';

class CustomerOrdersScreen extends StatefulWidget {
  final ProductRepository repository;
  final String? initialOrderId;

  const CustomerOrdersScreen({
    super.key,
    required this.repository,
    this.initialOrderId,
  });

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  List<CustomerOrderAdmin> _orders = [];

  bool _isLoading = true;
  String? _errorMessage;

  int _selectedTab = 0;

  static const List<_OrderFilter> _filters = [
    _OrderFilter(label: 'All', icon: Icons.all_inbox_outlined),
    _OrderFilter(label: 'New', icon: Icons.fiber_new_outlined),
    _OrderFilter(label: 'Processing', icon: Icons.inventory_2_outlined),
    _OrderFilter(label: 'Ready', icon: Icons.inventory_outlined),
    _OrderFilter(label: 'Shipped', icon: Icons.local_shipping_outlined),
    _OrderFilter(label: 'Delivered', icon: Icons.check_circle_outline),
    _OrderFilter(label: 'Cancelled', icon: Icons.cancel_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final orders = await widget.repository.getCustomerOrders();

      if (!mounted) {
        return;
      }

      setState(() {
        _orders = orders;
        _isLoading = false;
      });

      // If notification tap supplied a specific order,
      // open it after the list has loaded.
      final initialOrderId = widget.initialOrderId?.trim();

      if (initialOrderId != null && initialOrderId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openInitialOrder(initialOrderId);
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load customer orders.\n$error';
      });
    }
  }

  void _openInitialOrder(String orderId) {
    if (!mounted) {
      return;
    }

    CustomerOrderAdmin? matchingOrder;

    for (final order in _orders) {
      if (order.id == orderId) {
        matchingOrder = order;
        break;
      }
    }

    if (matchingOrder == null) {
      // The notification may contain an order that is no longer
      // available in the returned list.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The order could not be found in the order list.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerOrderDetailsScreen(order: matchingOrder!),
      ),
    );
  }

  List<CustomerOrderAdmin> get _filteredOrders {
    if (_selectedTab == 0) {
      return _orders;
    }

    return _orders.where((order) {
      final status = order.status.trim().toLowerCase();

      switch (_selectedTab) {
        case 1:
          // New orders.
          return status == 'pending_payment' || status == 'confirmed';

        case 2:
          return status == 'processing';

        case 3:
          return status == 'ready_to_ship';

        case 4:
          return status == 'shipped';

        case 5:
          return status == 'delivered';

        case 6:
          return status == 'cancelled';

        default:
          return true;
      }
    }).toList();
  }

  int _countForTab(int tab) {
    if (tab == 0) {
      return _orders.length;
    }

    return _orders.where((order) {
      final status = order.status.trim().toLowerCase();

      switch (tab) {
        case 1:
          return status == 'pending_payment' || status == 'confirmed';

        case 2:
          return status == 'processing';

        case 3:
          return status == 'ready_to_ship';

        case 4:
          return status == 'shipped';

        case 5:
          return status == 'delivered';

        case 6:
          return status == 'cancelled';

        default:
          return false;
      }
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final orders = _filteredOrders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Orders'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadOrders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody(orders)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected = _selectedTab == index;
          final count = _countForTab(index);

          return ChoiceChip(
            selected: selected,
            avatar: Icon(
              filter.icon,
              size: 18,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
            label: Text('${filter.label} $count'),
            selectedColor: Theme.of(context).colorScheme.primary,
            onSelected: (_) {
              setState(() {
                _selectedTab = index;
              });
            },
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(List<CustomerOrderAdmin> orders) {
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
                onPressed: _loadOrders,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadOrders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 160),
            Icon(
              _filters[_selectedTab].icon,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _selectedTab == 0
                    ? 'No customer orders yet'
                    : 'No ${_filters[_selectedTab].label.toLowerCase()} orders',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];

          return _OrderCard(
            order: order,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerOrderDetailsScreen(order: order),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _OrderFilter {
  final String label;
  final IconData icon;

  const _OrderFilter({required this.label, required this.icon});
}

class _OrderCard extends StatelessWidget {
  final CustomerOrderAdmin order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPaid = order.paymentStatus.toLowerCase() == 'paid';

    final status = order.status.trim().isEmpty ? 'Unknown' : order.status;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StatusBadge(
                    text: _displayStatus(status),
                    color: _statusColor(status),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                order.addressFullName.isEmpty
                    ? 'Customer'
                    : order.addressFullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),

              if (order.addressPhone.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(order.addressPhone),
              ],

              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(Icons.currency_rupee, size: 18),
                  Text(
                    order.totalAmount.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Icon(
                    isPaid ? Icons.check_circle : Icons.pending_outlined,
                    size: 18,
                    color: isPaid ? Colors.green : Colors.orange,
                  ),

                  const SizedBox(width: 5),

                  Text(
                    order.paymentStatus,
                    style: TextStyle(
                      color: isPaid
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const Spacer(),

                  Icon(Icons.chevron_right, color: Colors.grey.shade500),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                _formatDate(order.createdAt),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
        return 'Payment Pending';

      case 'ready_to_ship':
        return 'Ready to Ship';

      case 'confirmed':
        return 'Confirmed';

      case 'processing':
        return 'Processing';

      case 'shipped':
        return 'Shipped';

      case 'delivered':
        return 'Delivered';

      case 'cancelled':
        return 'Cancelled';

      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.blue;

      case 'processing':
        return Colors.orange;

      case 'ready_to_ship':
        return Colors.deepPurple;

      case 'shipped':
        return Colors.indigo;

      case 'delivered':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      case 'pending_payment':
        return Colors.orange;

      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/'
        '${local.year} '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
