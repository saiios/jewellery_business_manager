class CustomerOrderItemAdmin {
  final String id;
  final String orderId;
  final String productId;
  final String itemCode;
  final String productName;
  final String? imageUrl;
  final double sellingPrice;
  final int quantity;
  final double lineTotal;
  final DateTime createdAt;

  CustomerOrderItemAdmin({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.itemCode,
    required this.productName,
    required this.imageUrl,
    required this.sellingPrice,
    required this.quantity,
    required this.lineTotal,
    required this.createdAt,
  });

  factory CustomerOrderItemAdmin.fromMap(Map<String, dynamic> map) {
    return CustomerOrderItemAdmin(
      id: map['id']?.toString() ?? '',
      orderId: map['order_id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      itemCode: map['item_code']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      imageUrl: map['image_url']?.toString(),
      sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      lineTotal: (map['line_total'] as num?)?.toDouble() ?? 0,
      createdAt: _parseDate(map['created_at']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.parse(value.toString());
  }
}

class CustomerOrderAdmin {
  final String id;
  final String orderNumber;
  final String userId;

  final String status;
  final String paymentStatus;

  final double subtotal;
  final double shippingFee;
  final double totalAmount;

  final String addressFullName;
  final String addressPhone;
  final String addressLine1;
  final String? addressLine2;
  final String addressCity;
  final String addressState;
  final String addressPincode;
  final String? addressLandmark;

  final String? gatewayOrderId;
  final String? gatewayPaymentId;
  final String? adminSaleId;

  final DateTime createdAt;
  final DateTime updatedAt;

  final List<CustomerOrderItemAdmin> items;

  CustomerOrderAdmin({
    required this.id,
    required this.orderNumber,
    required this.userId,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.shippingFee,
    required this.totalAmount,
    required this.addressFullName,
    required this.addressPhone,
    required this.addressLine1,
    required this.addressLine2,
    required this.addressCity,
    required this.addressState,
    required this.addressPincode,
    required this.addressLandmark,
    required this.gatewayOrderId,
    required this.gatewayPaymentId,
    required this.adminSaleId,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  factory CustomerOrderAdmin.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];

    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => CustomerOrderItemAdmin.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <CustomerOrderItemAdmin>[];

    return CustomerOrderAdmin(
      id: map['id']?.toString() ?? '',
      orderNumber: map['order_number']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      paymentStatus: map['payment_status']?.toString() ?? '',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      shippingFee: (map['shipping_fee'] as num?)?.toDouble() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      addressFullName: map['address_full_name']?.toString() ?? '',
      addressPhone: map['address_phone']?.toString() ?? '',
      addressLine1: map['address_line1']?.toString() ?? '',
      addressLine2: map['address_line2']?.toString(),
      addressCity: map['address_city']?.toString() ?? '',
      addressState: map['address_state']?.toString() ?? '',
      addressPincode: map['address_pincode']?.toString() ?? '',
      addressLandmark: map['address_landmark']?.toString(),
      gatewayOrderId: map['gateway_order_id']?.toString(),
      gatewayPaymentId: map['gateway_payment_id']?.toString(),
      adminSaleId: map['admin_sale_id']?.toString(),
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
      items: items,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.parse(value.toString());
  }
}
