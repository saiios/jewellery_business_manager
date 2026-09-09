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

  Future<void> deleteProduct(String id) async {
    final product = await getProduct(id);

    final storageService = StorageService(supabase);

    // Delete image from Storage if it exists.
    await storageService.deleteProductMedia(product.imageUrl);

    // Delete video from Storage if it exists.
    await storageService.deleteProductMedia(product.videoUrl);

    // Finally delete the database record.
    await supabase.from('products').delete().eq('id', id);
  }
}
