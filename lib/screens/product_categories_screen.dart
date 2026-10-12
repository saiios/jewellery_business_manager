import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_category.dart';
import '../repositories/product_category_repository.dart';

class ProductCategoriesScreen extends StatefulWidget {
  final ProductCategoryRepository repository;
  const ProductCategoriesScreen({super.key, required this.repository});

  @override
  State<ProductCategoriesScreen> createState() =>
      _ProductCategoriesScreenState();
}

class _ProductCategoriesScreenState extends State<ProductCategoriesScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  List<ProductCategory> _categories = [];
  bool _loading = false;
  bool _showInactive = true;
  String? _error;

  SupabaseClient get _auth => widget.repository.adminClient;
  bool get _signedIn => _auth.auth.currentUser != null;
  List<ProductCategory> get _groups =>
      _categories.where((c) => c.isGroup).toList();

  @override
  void initState() {
    super.initState();
    if (_signedIn) _loadCategories();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await _loadCategories();
    } catch (_) {
      if (mounted)
        setState(
          () =>
              _error = 'Sign-in failed. Verify the admin account and password.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCategories() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final rows = await widget.repository.getCategories(
        activeOnly: !_showInactive,
      );
      if (mounted) setState(() => _categories = rows);
    } catch (e) {
      if (mounted)
        setState(
          () => _error =
              'Unable to load categories. Confirm the hierarchy SQL migration was applied and this user is allow-listed. $e',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editCategory([ProductCategory? category]) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    final orderController = TextEditingController(
      text: (category?.displayOrder ?? ((_categories.length + 1) * 10))
          .toString(),
    );
    bool active = category?.isActive ?? true;
    bool isGroup = category?.isGroup ?? false;
    String? parentId = category?.parentCategoryId;
    final availableGroups = _groups.where((g) => g.id != category?.id).toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? 'Add category' : 'Edit category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Category name',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Display order',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Main category / group'),
                  subtitle: const Text(
                    'Groups are not selectable for products',
                  ),
                  value: isGroup,
                  onChanged: (value) => setDialogState(() {
                    isGroup = value;
                    if (value) parentId = null;
                  }),
                ),
                if (!isGroup) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: parentId,
                    decoration: const InputDecoration(
                      labelText: 'Parent category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No parent'),
                      ),
                      ...availableGroups.map(
                        (g) => DropdownMenuItem<String?>(
                          value: g.id,
                          child: Text(g.name),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => parentId = value),
                  ),
                ],
                if (category != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != true) {
      nameController.dispose();
      orderController.dispose();
      return;
    }
    final order = int.tryParse(orderController.text.trim());
    if (nameController.text.trim().isEmpty || order == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a category name and valid display order.'),
          ),
        );
      nameController.dispose();
      orderController.dispose();
      return;
    }
    if (isGroup &&
        category != null &&
        _categories.any((c) => c.parentCategoryId == category.id)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This group has subcategories. Keep it as a main category.',
            ),
          ),
        );
      nameController.dispose();
      orderController.dispose();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (category == null) {
        await widget.repository.createCategory(
          name: nameController.text,
          displayOrder: order,
          parentCategoryId: parentId,
          isGroup: isGroup,
        );
      } else {
        await widget.repository.updateCategory(
          category,
          name: nameController.text,
          displayOrder: order,
          isActive: active,
          parentCategoryId: parentId,
          isGroup: isGroup,
        );
      }
      await _loadCategories();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              category == null ? 'Category added.' : 'Category updated.',
            ),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to save category. Check for duplicate names and admin permissions. $e',
            ),
          ),
        );
    } finally {
      nameController.dispose();
      orderController.dispose();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Product Categories'),
      actions: [
        if (_signedIn)
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await _auth.auth.signOut();
              if (mounted)
                setState(() {
                  _categories = [];
                });
            },
            icon: const Icon(Icons.logout),
          ),
      ],
    ),
    body: !_signedIn ? _buildLogin() : _buildCategoryList(),
    floatingActionButton: _signedIn
        ? FloatingActionButton.extended(
            onPressed: _loading ? null : () => _editCategory(),
            icon: const Icon(Icons.add),
            label: const Text('Add category'),
          )
        : null,
  );

  Widget _buildLogin() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Admin sign-in',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'Admin email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _signIn(),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _signIn,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use the admin account created in Supabase. Public sign-up is not available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildCategoryList() {
    final rootItems = _categories
        .where((c) => c.isGroup || c.parentCategoryId == null)
        .toList();
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Show inactive categories'),
          value: _showInactive,
          onChanged: (value) {
            setState(() => _showInactive = value);
            _loadCategories();
          },
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCategories,
            child: _categories.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),
                      Center(child: Text('No categories found.')),
                    ],
                  )
                : ListView(
                    children: [
                      for (final item in rootItems) ...[
                        _categoryTile(item, isChild: false),
                        if (item.isGroup)
                          for (final child in _categories.where(
                            (c) => c.parentCategoryId == item.id,
                          ))
                            _categoryTile(child, isChild: true),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _categoryTile(ProductCategory c, {required bool isChild}) => ListTile(
    contentPadding: EdgeInsets.only(left: isChild ? 48 : 16, right: 16),
    leading: CircleAvatar(child: Text(c.displayOrder.toString())),
    title: Text(c.name),
    subtitle: Text(
      '${c.isGroup ? 'Main category' : (isChild ? 'Subcategory' : 'Standalone category')} • ${c.isActive ? 'Active' : 'Inactive'}',
    ),
    trailing: IconButton(
      tooltip: 'Edit category',
      icon: const Icon(Icons.edit_outlined),
      onPressed: () => _editCategory(c),
    ),
  );
}
