class Product {
  final String id;
  final String itemCode;
  final String productName;
  final String category;
  final String? imageUrl;
  final String? videoUrl;
  final double purchasePrice;
  final double sellingPrice;
  final int quantity;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.itemCode,
    required this.productName,
    required this.category,
    this.imageUrl,
    this.videoUrl,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      itemCode: map['item_code'] as String,
      productName: map['product_name'] as String,
      category: map['category'] as String,
      imageUrl: map['image_url'] as String?,
      videoUrl: map['video_url'] as String?,
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'item_code': itemCode,
      'product_name': productName,
      'category': category,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'quantity': quantity,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'item_code': itemCode,
      'product_name': productName,
      'category': category,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'quantity': quantity,
    };
  }
}
