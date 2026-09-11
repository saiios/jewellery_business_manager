import 'package:jewel_admin/models/inventory_summary.dart';
import 'package:jewel_admin/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';

class ProductRepository {
  final SupabaseClient supabase;

  ProductRepository(this.supabase);

  Future<List<Product>> getProducts() async {
    final response = await supabase
        .from('products')
        .select()
        .order('created_at', ascending: false);

    return (response as List).map((item) => Product.fromMap(item)).toList();
  }

  Future<Product> getProduct(String id) async {
    final response = await supabase
        .from('products')
        .select()
        .eq('id', id)
        .single();

    return Product.fromMap(response);
  }

  Future<Product> createProduct(Product product) async {
    final response = await supabase
        .from('products')
        .insert(product.toInsertMap())
        .select()
        .single();

    return Product.fromMap(response);
  }

  Future<Product> updateProduct(Product product) async {
    final response = await supabase
        .from('products')
        .update(product.toUpdateMap())
        .eq('id', product.id)
        .select()
        .single();

    return Product.fromMap(response);
  }

  Future<Product> updateProductImage({
    required String productId,
    required String? imageUrl,
  }) async {
    final response = await supabase
        .from('products')
        .update({'image_url': imageUrl})
        .eq('id', productId)
        .select()
        .single();

    return Product.fromMap(response);
  }

  Future<Product> updateProductVideo({
    required String productId,
    required String? videoUrl,
  }) async {
    final response = await supabase
        .from('products')
        .update({'video_url': videoUrl})
        .eq('id', productId)
        .select()
        .single();

    return Product.fromMap(response);
  }

  Future<InventorySummary> getInventorySummary() async {
    final response = await supabase
        .from('products')
        .select('purchase_price, selling_price, quantity, category');

    final products = response as List;

    double currentStockPurchaseValue = 0;
    double expectedSalesValue = 0;
    int itemsRemaining = 0;

    final categoriesWithStock = <String>{};

    for (final item in products) {
      final purchasePrice = (item['purchase_price'] as num).toDouble();
      final sellingPrice = (item['selling_price'] as num).toDouble();
      final quantity = item['quantity'] as int;
      final category = item['category'] as String;

      if (quantity > 0) {
        currentStockPurchaseValue += purchasePrice * quantity;
        expectedSalesValue += sellingPrice * quantity;
        itemsRemaining += quantity;

        categoriesWithStock.add(category);
      }
    }

    return InventorySummary(
      currentStockPurchaseValue: currentStockPurchaseValue,
      expectedSalesValue: expectedSalesValue,
      potentialProfit: expectedSalesValue - currentStockPurchaseValue,
      itemsRemaining: itemsRemaining,
      productDesigns: products.length,
      categories: categoriesWithStock.length,
    );
  }

  Future<void> deleteProduct(String id) async {
    final product = await getProduct(id);

    final storageService = StorageService(supabase);

    await storageService.deleteProductMedia(product.imageUrl);

    await storageService.deleteProductMedia(product.videoUrl);

    await supabase.from('products').delete().eq('id', id);
  }
}
