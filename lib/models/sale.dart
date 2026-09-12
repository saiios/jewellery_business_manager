import 'sale_item.dart';

class Sale {
  final String id;
  final String saleNumber;
  final DateTime saleDate;
  final String? customerName;
  final String? customerMobile;
  final String paymentMethod;
  final double subtotal;
  final double totalAmount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SaleItem> items;

  const Sale({
    required this.id,
    required this.saleNumber,
    required this.saleDate,
    this.customerName,
    this.customerMobile,
    required this.paymentMethod,
    required this.subtotal,
    required this.totalAmount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory Sale.fromMap(
    Map<String, dynamic> map, {
    List<SaleItem> items = const [],
  }) {
    return Sale(
      id: map['id'] as String,
      saleNumber: map['sale_number'] as String,
      saleDate: DateTime.parse(map['sale_date'] as String),
      customerName: map['customer_name'] as String?,
      customerMobile: map['customer_mobile'] as String?,
      paymentMethod: map['payment_method'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      items: items,
    );
  }

  int get totalItems {
    return items.fold(0, (total, item) => total + item.quantity);
  }

  double get totalCost {
    return items.fold(
      0,
      (total, item) => total + (item.purchasePrice * item.quantity),
    );
  }

  double get realizedProfit {
    return totalAmount - totalCost;
  }
}
