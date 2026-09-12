import 'package:jewel_admin/models/inventory_summary.dart';
import 'package:jewel_admin/models/sale.dart';
import 'package:jewel_admin/models/sale_item.dart';
import 'package:jewel_admin/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';

class ProductRepository {
  final SupabaseClient supabase;

  ProductRepository(this.supabase);

  // ============================================================
  // PRODUCTS
  // ============================================================

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

  // ============================================================
  // INVENTORY SUMMARY
  // ============================================================

  Future<InventorySummary> getInventorySummary() async {
    // ------------------------------------------------------------
    // CURRENT STOCK
    // ------------------------------------------------------------

    final productsResponse = await supabase
        .from('products')
        .select('purchase_price, selling_price, quantity, category');

    final products = productsResponse as List;

    double currentStockPurchaseValue = 0;
    double currentStockSellingValue = 0;
    int itemsRemaining = 0;

    final categoriesWithStock = <String>{};

    for (final item in products) {
      final purchasePrice = (item['purchase_price'] as num).toDouble();

      final sellingPrice = (item['selling_price'] as num).toDouble();

      final quantity = item['quantity'] as int;

      final category = item['category'] as String;

      if (quantity > 0) {
        currentStockPurchaseValue += purchasePrice * quantity;

        currentStockSellingValue += sellingPrice * quantity;

        itemsRemaining += quantity;

        categoriesWithStock.add(category);
      }
    }

    // ------------------------------------------------------------
    // ACTUAL SALES
    // ------------------------------------------------------------

    final salesItemsResponse = await supabase
        .from('sale_items')
        .select('purchase_price, selling_price, quantity, line_total');

    final saleItems = salesItemsResponse as List;

    double totalSalesRevenue = 0;
    double totalCostOfSoldItems = 0;
    int itemsSold = 0;

    for (final item in saleItems) {
      final purchasePrice = (item['purchase_price'] as num).toDouble();

      final quantity = item['quantity'] as int;

      final lineTotal = (item['line_total'] as num).toDouble();

      totalSalesRevenue += lineTotal;

      totalCostOfSoldItems += purchasePrice * quantity;

      itemsSold += quantity;
    }

    final realizedProfit = totalSalesRevenue - totalCostOfSoldItems;

    // ------------------------------------------------------------
    // SALES COUNT
    // ------------------------------------------------------------

    final salesResponse = await supabase.from('sales').select('id');

    final totalSales = (salesResponse as List).length;

    // ------------------------------------------------------------
    // REMAINING STOCK PROFIT
    // ------------------------------------------------------------

    final potentialProfit =
        currentStockSellingValue - currentStockPurchaseValue;

    return InventorySummary(
      currentStockPurchaseValue: currentStockPurchaseValue,

      currentStockSellingValue: currentStockSellingValue,

      potentialProfit: potentialProfit,

      totalSalesRevenue: totalSalesRevenue,

      totalCostOfSoldItems: totalCostOfSoldItems,

      realizedProfit: realizedProfit,

      itemsRemaining: itemsRemaining,

      itemsSold: itemsSold,

      productDesigns: products.length,

      categories: categoriesWithStock.length,

      totalSales: totalSales,
    );
  }
  // ============================================================
  // SALES
  // ============================================================

  Future<Sale> createSale({
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    String? customerName,
    String? customerMobile,
    String? notes,
  }) async {
    final response = await supabase.rpc(
      'create_sale',
      params: {
        'p_items': items,
        'p_payment_method': paymentMethod,
        'p_customer_name': customerName,
        'p_customer_mobile': customerMobile,
        'p_notes': notes,
      },
    );

    return Sale.fromMap(Map<String, dynamic>.from(response as Map));
  }

  Future<List<Sale>> getSales() async {
    final response = await supabase
        .from('sales')
        .select()
        .order('sale_date', ascending: false);

    return (response as List)
        .map((item) => Sale.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Sale> getSale(String saleId) async {
    final saleResponse = await supabase
        .from('sales')
        .select()
        .eq('id', saleId)
        .single();

    final itemResponse = await supabase
        .from('sale_items')
        .select()
        .eq('sale_id', saleId)
        .order('created_at');

    final items = (itemResponse as List)
        .map((item) => SaleItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    return Sale.fromMap(Map<String, dynamic>.from(saleResponse), items: items);
  }

  Future<List<SaleItem>> getProductSales(String productId) async {
    final response = await supabase
        .from('sale_items')
        .select()
        .eq('product_id', productId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => SaleItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  // ============================================================
  // DELETE PRODUCT
  // ============================================================

  Future<void> deleteProduct(String id) async {
    final product = await getProduct(id);

    final storageService = StorageService(supabase);

    await storageService.deleteProductMedia(product.imageUrl);

    await storageService.deleteProductMedia(product.videoUrl);

    await supabase.from('products').delete().eq('id', id);
  }
}
