class CustomerOrderStatusUpdate {
  final String id;
  final String orderNumber;
  final String oldStatus;
  final String newStatus;
  final String paymentStatus;
  final double totalAmount;
  final String? adminSaleId;
  final DateTime? updatedAt;

  const CustomerOrderStatusUpdate({
    required this.id,
    required this.orderNumber,
    required this.oldStatus,
    required this.newStatus,
    required this.paymentStatus,
    required this.totalAmount,
    required this.adminSaleId,
    required this.updatedAt,
  });

  factory CustomerOrderStatusUpdate.fromMap(Map<String, dynamic> map) {
    return CustomerOrderStatusUpdate(
      id: map['id']?.toString() ?? '',
      orderNumber: map['order_number']?.toString() ?? '',
      oldStatus: map['old_status']?.toString() ?? '',
      newStatus: map['new_status']?.toString() ?? '',
      paymentStatus: map['payment_status']?.toString() ?? '',
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      adminSaleId: map['admin_sale_id']?.toString(),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}
