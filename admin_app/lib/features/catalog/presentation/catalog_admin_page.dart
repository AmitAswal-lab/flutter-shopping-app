import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../common/centered_message.dart';
import '../domain/admin_product.dart';
import 'product_admin_card.dart';
import 'product_editor_dialog.dart';

class CatalogAdminPage extends StatefulWidget {
  const CatalogAdminPage({super.key, required this.user});

  final User user;

  @override
  State<CatalogAdminPage> createState() => _CatalogAdminPageState();
}

class _CatalogAdminPageState extends State<CatalogAdminPage> {
  final _searchController = TextEditingController();
  String _visibility = 'active';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<AdminProduct>> _products() {
    return FirebaseFirestore.instance
        .collection('products')
        .orderBy('sortOrder')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => AdminProduct.fromDoc(doc)).toList(),
        );
  }

  List<AdminProduct> _filter(List<AdminProduct> products) {
    final query = _searchController.text.trim().toLowerCase();
    return products.where((product) {
      final visibilityMatches = switch (_visibility) {
        'archived' => !product.isActive,
        'all' => true,
        _ => product.isActive,
      };
      final queryMatches =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.brand.toLowerCase().contains(query) ||
          product.categoryLabel.toLowerCase().contains(query);
      return visibilityMatches && queryMatches;
    }).toList();
  }

  Future<void> _openEditor([AdminProduct? product]) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProductEditorDialog(product: product),
    );

    if (!mounted || result != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(product == null ? 'Product added' : 'Product saved'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<AdminProduct>>(
        stream: _products(),
        builder: (context, snapshot) {
          final products = snapshot.data ?? const <AdminProduct>[];
          final filtered = _filter(products);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: _Header(
                    email: widget.user.email ?? widget.user.uid,
                    onAdd: () => _openEditor(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 360,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            labelText: 'Search catalog',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'active',
                            label: Text('Active'),
                            icon: Icon(Icons.storefront_outlined),
                          ),
                          ButtonSegment(
                            value: 'archived',
                            label: Text('Archived'),
                            icon: Icon(Icons.archive_outlined),
                          ),
                          ButtonSegment(
                            value: 'all',
                            label: Text('All'),
                            icon: Icon(Icons.inventory_2_outlined),
                          ),
                        ],
                        selected: {_visibility},
                        onSelectionChanged: (values) =>
                            setState(() => _visibility = values.first),
                      ),
                    ],
                  ),
                ),
              ),
              if (snapshot.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: CenteredMessage(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load catalog',
                    body: snapshot.error.toString(),
                  ),
                )
              else if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: CenteredMessage(
                    icon: Icons.hourglass_empty,
                    title: 'Loading catalog',
                  ),
                )
              else if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: CenteredMessage(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products found',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 360,
                          mainAxisExtent: 430,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      return ProductAdminCard(
                        product: product,
                        onEdit: () => _openEditor(product),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.email, required this.onAdd});

  final String email;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Catalog', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 4),
              Text(email, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add product'),
        ),
      ],
    );
  }
}
