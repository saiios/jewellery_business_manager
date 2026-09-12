class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final String itemCode;
  final String productName;
  final double purchasePrice;
  final double sellingPrice;
  final int quantity;
  final double lineTotal;
  final DateTime createdAt;

  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.itemCode,
    required this.productName,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    required this.lineTotal,
    required this.createdAt,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as String,
      saleId: map['sale_id'] as String,
      productId: map['product_id'] as String,
      itemCode: map['item_code'] as String,
      productName: map['product_name'] as String,
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      lineTotal: (map['line_total'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  double get profit {
    return lineTotal - (purchasePrice * quantity);
  }
}
