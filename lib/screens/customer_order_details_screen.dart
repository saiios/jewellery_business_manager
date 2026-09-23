import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_order_admin.dart';
import '../models/customer_order_status_update.dart';
import '../repositories/product_repository.dart';

class CustomerOrderDetailsScreen extends StatefulWidget {
  final CustomerOrderAdmin order;

  const CustomerOrderDetailsScreen({super.key, required this.order});

  @override
  State<CustomerOrderDetailsScreen> createState() =>
      _CustomerOrderDetailsScreenState();
}

class _CustomerOrderDetailsScreenState
    extends State<CustomerOrderDetailsScreen> {
  late String _currentStatus;
  late DateTime _updatedAt;

  bool _isUpdatingStatus = false;

  late final ProductRepository _repository;

  @override
  void initState() {
    super.initState();

    _currentStatus = widget.order.status;
    _updatedAt = widget.order.updatedAt;

    _repository = ProductRepository(Supabase.instance.client);
  }

  // ---------------------------------------------------------------------------
  // ORDER STATUS
  // ---------------------------------------------------------------------------

  List<String> _availableNextStatuses() {
    switch (_currentStatus.toLowerCase()) {
      case 'confirmed':
        return ['processing'];

      case 'processing':
        return ['ready_to_ship'];

      case 'ready_to_ship':
        return ['shipped'];

      case 'shipped':
        return ['delivered'];

      case 'pending_payment':
      case 'cancelled':
      case 'delivered':
      default:
        return [];
    }
  }

  Future<void> _changeOrderStatus() async {
    if (_isUpdatingStatus) {
      return;
    }

    final nextStatuses = _availableNextStatuses();

    if (nextStatuses.isEmpty) {
      _showMessage(_statusChangeUnavailableMessage());
      return;
    }

    final selectedStatus = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Change Order Status',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Current status: ${_prettyStatus(_currentStatus)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ...nextStatuses.map((status) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: _statusColor(
                        status,
                      ).withValues(alpha: 0.12),
                      child: Icon(
                        _statusIcon(status),
                        color: _statusColor(status),
                      ),
                    ),
                    title: Text(
                      _prettyStatus(status),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Move order to ${_prettyStatus(status)}'),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                    ),
                    onTap: () {
                      Navigator.of(context).pop(status);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selectedStatus == null) {
      return;
    }

    await _confirmAndUpdateStatus(selectedStatus);
  }

  Future<void> _confirmAndUpdateStatus(String newStatus) async {
    final currentStatusText = _prettyStatus(_currentStatus);
    final newStatusText = _prettyStatus(newStatus);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Order Status?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_horiz_rounded, size: 48),
              const SizedBox(height: 14),
              Text(
                widget.order.orderNumber,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatusChangeBox(
                      label: 'Current',
                      value: currentStatusText,
                      color: _statusColor(_currentStatus),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 20),
                  ),
                  Expanded(
                    child: _StatusChangeBox(
                      label: 'New',
                      value: newStatusText,
                      color: _statusColor(newStatus),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'This status change will be saved to the customer order.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _updateOrderStatus(newStatus);
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    if (_isUpdatingStatus) {
      return;
    }

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final CustomerOrderStatusUpdate result = await _repository
          .updateCustomerOrderStatus(
            orderId: widget.order.id,
            status: newStatus,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentStatus = result.newStatus;

        if (result.updatedAt != null) {
          _updatedAt = result.updatedAt!;
        }
      });

      _showMessage(
        'Order status updated to ${_prettyStatus(result.newStatus)}.',
        success: true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(_cleanErrorMessage(error), success: false);
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  String _statusChangeUnavailableMessage() {
    switch (_currentStatus.toLowerCase()) {
      case 'pending_payment':
        return 'This order is waiting for payment. '
            'The customer must complete payment before fulfilment can start.';

      case 'cancelled':
        return 'Cancelled orders cannot be moved to another status.';

      case 'delivered':
        return 'This order has already been delivered.';

      default:
        return 'No further status change is available for this order.';
    }
  }

  String _cleanErrorMessage(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }

    return text;
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green.shade700 : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.order.orderNumber)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOrderHeader(),
          const SizedBox(height: 16),
          _buildCustomerSection(),
          const SizedBox(height: 16),
          _buildAddressSection(),
          const SizedBox(height: 16),
          _buildProductsSection(),
          const SizedBox(height: 16),
          _buildPaymentSection(),
          const SizedBox(height: 16),
          _buildTechnicalSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ORDER HEADER
  // ---------------------------------------------------------------------------

  Widget _buildOrderHeader() {
    final status = _currentStatus.trim().isEmpty ? 'Unknown' : _currentStatus;

    final paymentStatus = widget.order.paymentStatus.trim().isEmpty
        ? 'Unknown'
        : widget.order.paymentStatus;

    final nextStatuses = _availableNextStatuses();

    final canChangeStatus = nextStatuses.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.order.orderNumber,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    label: 'Order Status',
                    value: _prettyStatus(status),
                    valueColor: _statusColor(status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    label: 'Payment',
                    value: _prettyStatus(paymentStatus),
                    valueColor: _paymentStatusColor(paymentStatus),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Created',
              value: _formatDate(widget.order.createdAt),
            ),

            const SizedBox(height: 8),

            _InfoRow(
              icon: Icons.update_outlined,
              label: 'Updated',
              value: _formatDate(_updatedAt),
            ),

            const SizedBox(height: 16),

            // ---------------------------------------------------------------
            // CHANGE STATUS BUTTON
            // ---------------------------------------------------------------
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUpdatingStatus || !canChangeStatus
                    ? null
                    : _changeOrderStatus,
                icon: _isUpdatingStatus
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_alt_rounded),
                label: Text(
                  _isUpdatingStatus
                      ? 'Updating...'
                      : canChangeStatus
                      ? 'Change Order Status'
                      : _statusButtonDisabledText(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusButtonDisabledText() {
    switch (_currentStatus.toLowerCase()) {
      case 'pending_payment':
        return 'Waiting for Payment';

      case 'cancelled':
        return 'Order Cancelled';

      case 'delivered':
        return 'Order Delivered';

      default:
        return 'Status Update Unavailable';
    }
  }

  // ---------------------------------------------------------------------------
  // CUSTOMER
  // ---------------------------------------------------------------------------

  Widget _buildCustomerSection() {
    return _SectionCard(
      title: 'Customer',
      icon: Icons.person_outline,
      children: [
        _InfoRow(
          icon: Icons.person_outline,
          label: 'Name',
          value: widget.order.addressFullName.isEmpty
              ? 'Not available'
              : widget.order.addressFullName,
        ),
        const SizedBox(height: 10),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: widget.order.addressPhone.isEmpty
              ? 'Not available'
              : widget.order.addressPhone,
        ),
        const SizedBox(height: 10),
        _InfoRow(
          icon: Icons.badge_outlined,
          label: 'Customer ID',
          value: widget.order.userId,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ADDRESS
  // ---------------------------------------------------------------------------

  Widget _buildAddressSection() {
    final addressLines = <String>[];

    if (widget.order.addressLine1.trim().isNotEmpty) {
      addressLines.add(widget.order.addressLine1.trim());
    }

    if (widget.order.addressLine2 != null &&
        widget.order.addressLine2!.trim().isNotEmpty) {
      addressLines.add(widget.order.addressLine2!.trim());
    }

    final cityState = [
      if (widget.order.addressCity.trim().isNotEmpty)
        widget.order.addressCity.trim(),
      if (widget.order.addressState.trim().isNotEmpty)
        widget.order.addressState.trim(),
    ].join(', ');

    if (cityState.isNotEmpty) {
      addressLines.add(cityState);
    }

    if (widget.order.addressPincode.trim().isNotEmpty) {
      addressLines.add(widget.order.addressPincode.trim());
    }

    if (widget.order.addressLandmark != null &&
        widget.order.addressLandmark!.trim().isNotEmpty) {
      addressLines.add('Landmark: ${widget.order.addressLandmark!.trim()}');
    }

    final fullAddress = addressLines.isEmpty
        ? 'Address not available'
        : addressLines.join('\n');

    return _SectionCard(
      title: 'Delivery Address',
      icon: Icons.location_on_outlined,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on_outlined, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fullAddress,
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PRODUCTS
  // ---------------------------------------------------------------------------

  Widget _buildProductsSection() {
    return _SectionCard(
      title: 'Products',
      icon: Icons.inventory_2_outlined,
      children: [
        if (widget.order.items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No product items found for this order.'),
          )
        else
          ...widget.order.items.map((item) => _ProductItemCard(item: item)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ORDER SUMMARY
  // ---------------------------------------------------------------------------

  Widget _buildPaymentSection() {
    return _SectionCard(
      title: 'Order Summary',
      icon: Icons.receipt_long_outlined,
      children: [
        _SummaryRow(label: 'Subtotal', value: _currency(widget.order.subtotal)),
        const SizedBox(height: 10),
        _SummaryRow(
          label: 'Delivery',
          value: widget.order.shippingFee <= 0
              ? 'FREE'
              : _currency(widget.order.shippingFee),
          valueColor: widget.order.shippingFee <= 0 ? Colors.green : null,
        ),
        const Divider(height: 24),
        _SummaryRow(
          label: 'Total',
          value: _currency(widget.order.totalAmount),
          bold: true,
          fontSize: 19,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TECHNICAL
  // ---------------------------------------------------------------------------

  Widget _buildTechnicalSection() {
    final hasGatewayOrder =
        widget.order.gatewayOrderId != null &&
        widget.order.gatewayOrderId!.trim().isNotEmpty;

    final hasGatewayPayment =
        widget.order.gatewayPaymentId != null &&
        widget.order.gatewayPaymentId!.trim().isNotEmpty;

    final hasSale =
        widget.order.adminSaleId != null &&
        widget.order.adminSaleId!.trim().isNotEmpty;

    return _SectionCard(
      title: 'Payment / System Details',
      icon: Icons.settings_outlined,
      children: [
        _TechnicalRow(
          label: 'Razorpay Order ID',
          value: hasGatewayOrder
              ? widget.order.gatewayOrderId!
              : 'Not available',
        ),
        const SizedBox(height: 12),
        _TechnicalRow(
          label: 'Razorpay Payment ID',
          value: hasGatewayPayment
              ? widget.order.gatewayPaymentId!
              : 'Not available',
        ),
        const SizedBox(height: 12),
        _TechnicalRow(
          label: 'Admin Sale ID',
          value: hasSale ? widget.order.adminSaleId! : 'Not created',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _currency(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  String _prettyStatus(String value) {
    final cleaned = value.trim().replaceAll('_', ' ');

    if (cleaned.isEmpty) {
      return 'Unknown';
    }

    return cleaned
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}'
                    '${word.substring(1).toLowerCase()}',
        )
        .join(' ');
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

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle_outline;

      case 'processing':
        return Icons.inventory_2_outlined;

      case 'ready_to_ship':
        return Icons.inventory_2;

      case 'shipped':
        return Icons.local_shipping_outlined;

      case 'delivered':
        return Icons.done_all;

      default:
        return Icons.sync_alt_rounded;
    }
  }

  Color _paymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;

      case 'pending':
        return Colors.orange;

      case 'failed':
        return Colors.red;

      case 'cancelled':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) {
      return 'Not available';
    }

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

// ============================================================================
// STATUS CHANGE BOX
// ============================================================================

class _StatusChangeBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatusChangeBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PRODUCT ITEM
// ============================================================================

class _ProductItemCard extends StatelessWidget {
  final CustomerOrderItemAdmin item;

  const _ProductItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImage(imageUrl: item.imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName.isEmpty ? 'Product' : item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),

                if (item.itemCode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.itemCode,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                Row(
                  children: [
                    Text(
                      'Qty: ${item.quantity}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '₹${item.sellingPrice.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Text(
                  'Line total: ₹${item.lineTotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PRODUCT IMAGE
// ============================================================================

class _ProductImage extends StatelessWidget {
  final String? imageUrl;

  const _ProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';

    if (url.isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey.shade500,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        placeholder: (context, url) {
          return Container(
            width: 72,
            height: 72,
            color: Colors.grey.shade100,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorWidget: (context, url, error) {
          return Container(
            width: 72,
            height: 72,
            color: Colors.grey.shade100,
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.grey.shade500,
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// SECTION CARD
// ============================================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// INFO TILE
// ============================================================================

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: valueColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// INFO ROW
// ============================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: Colors.grey.shade700),
        const SizedBox(width: 9),
        SizedBox(
          width: 75,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TECHNICAL ROW
// ============================================================================

class _TechnicalRow extends StatelessWidget {
  final String label;
  final String value;

  const _TechnicalRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ============================================================================
// SUMMARY ROW
// ============================================================================

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final double fontSize;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.fontSize = 15,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            color: valueColor,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
