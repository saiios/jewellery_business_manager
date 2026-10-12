import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_category.dart';

/// Uses a dedicated Supabase client for admin authentication so category login
/// does not change the existing ProductRepository client's auth role/session.
class ProductCategoryRepository {
  final SupabaseClient publicClient;
  final SupabaseClient adminClient;

  ProductCategoryRepository({required this.publicClient, required this.adminClient});

  Future<List<ProductCategory>> getCategories({bool activeOnly = true}) async {
    var query = adminClient.from('product_categories').select();
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('display_order').order('name');
    return (rows as List)
        .map((row) => ProductCategory.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> createCategory({
    required String name,
    required int displayOrder,
    String? parentCategoryId,
    bool isGroup = false,
  }) async {
    _requireAdmin();
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('Category name is required.');
    if (isGroup && parentCategoryId != null) {
      throw ArgumentError('A main category cannot have a parent.');
    }
    await adminClient.from('product_categories').insert({
      'name': normalized,
      'display_order': displayOrder,
      'is_active': true,
      'parent_category_id': parentCategoryId,
      'is_group': isGroup,
    });
  }

  Future<void> updateCategory(
    ProductCategory category, {
    required String name,
    required int displayOrder,
    required bool isActive,
    required String? parentCategoryId,
    required bool isGroup,
  }) async {
    _requireAdmin();
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('Category name is required.');
    if (isGroup && parentCategoryId != null) {
      throw ArgumentError('A main category cannot have a parent.');
    }
    if (parentCategoryId == category.id) {
      throw ArgumentError('A category cannot be its own parent.');
    }
    await adminClient.from('product_categories').update({
      'name': normalized,
      'display_order': displayOrder,
      'is_active': isActive,
      'parent_category_id': parentCategoryId,
      'is_group': isGroup,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', category.id);
  }

  void _requireAdmin() {
    if (adminClient.auth.currentUser == null) {
      throw StateError('Sign in to the authorized admin account first.');
    }
  }
}
