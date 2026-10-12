class ProductCategory {
  final String id;
  final String name;
  final String? imageUrl;
  final bool isActive;
  final int displayOrder;
  final String? parentCategoryId;
  final bool isGroup;

  const ProductCategory({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.isActive,
    required this.displayOrder,
    this.parentCategoryId,
    this.isGroup = false,
  });

  factory ProductCategory.fromMap(Map<String, dynamic> map) => ProductCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        imageUrl: map['image_url'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        displayOrder: map['display_order'] as int? ?? 0,
        parentCategoryId: map['parent_category_id'] as String?,
        isGroup: map['is_group'] as bool? ?? false,
      );
}
