import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/catalog/domain/models/product.dart';
import 'package:shopping_app/features/catalog/presentation/controllers/product_catalog.dart';
import 'package:shopping_app/features/catalog/presentation/controllers/product_filter.dart';
import 'package:shopping_app/features/catalog/presentation/screens/product_search_screen.dart';
import 'package:shopping_app/features/catalog/presentation/widgets/product_card.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: const _ProductCatalog(),
    );
  }
}

class _ProductCatalog extends StatefulWidget {
  const _ProductCatalog();

  @override
  State<_ProductCatalog> createState() => _ProductCatalogState();
}

class _ProductCatalogState extends State<_ProductCatalog> {
  static const _pageSize = 8;

  int _visibleProductCount = _pageSize;
  String? _filterSignature;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<ProductCatalog>();

    if (catalog.isLoading && catalog.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (catalog.errorMessage != null && catalog.products.isEmpty) {
      return _CatalogError(message: catalog.errorMessage!);
    }

    if (catalog.products.isEmpty) {
      return const _EmptyCatalog();
    }

    final filter = context.watch<ProductFilter>();
    final visibleProducts = filter.applyTo(catalog.products);
    final filterSignature =
        '${filter.query}|${filter.category.name}|${filter.sort.name}';
    if (_filterSignature != filterSignature) {
      _filterSignature = filterSignature;
      _visibleProductCount = _pageSize;
    }

    final displayedProducts = visibleProducts
        .take(_visibleProductCount)
        .toList(growable: false);
    final remainingProductCount =
        visibleProducts.length - displayedProducts.length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _SearchAndFilterHeader(
            visibleCount: visibleProducts.length,
            sort: filter.sort,
          ),
        ),
        if (visibleProducts.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyProductResults(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverGrid.builder(
              itemCount: displayedProducts.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.52,
              ),
              itemBuilder: (context, index) {
                return ProductCard(product: displayedProducts[index]);
              },
            ),
          ),
        if (remainingProductCount > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _visibleProductCount += _pageSize);
                },
                icon: const Icon(Icons.expand_more),
                label: Text(
                  'Show ${remainingProductCount < _pageSize ? remainingProductCount : _pageSize} more products',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchAndFilterHeader extends StatelessWidget {
  const _SearchAndFilterHeader({
    required this.visibleCount,
    required this.sort,
  });

  final int visibleCount;
  final ProductSort sort;

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = context.select<ProductFilter, bool>(
      (filter) => filter.hasActiveFilters,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProductSearchField(),
          const SizedBox(height: 12),
          const _CategoryFilters(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$visibleCount ${visibleCount == 1 ? 'product' : 'products'} found',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (hasActiveFilters)
                TextButton.icon(
                  onPressed: context.read<ProductFilter>().clear,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Reset'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Sort by', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(width: 8),
              Flexible(child: _SortMenu(sort: sort)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _CatalogMessage(
      icon: Icons.cloud_off,
      title: 'Could not load products',
      message: message,
      action: FilledButton.icon(
        onPressed: context.read<ProductCatalog>().load,
        icon: const Icon(Icons.refresh),
        label: const Text('Try again'),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return const _CatalogMessage(
      icon: Icons.inventory_2_outlined,
      title: 'The catalog is empty',
      message: 'Products will appear here when they become available.',
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class _ProductSearchField extends StatelessWidget {
  const _ProductSearchField();

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ProductSearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = context.select<ProductFilter, String>(
      (filter) => filter.query,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final hasQuery = query.isNotEmpty;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _openSearch(context),
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasQuery ? query : 'Search products',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: hasQuery
                        ? colorScheme.onSurface
                        : colorScheme.outline,
                  ),
                ),
              ),
              if (hasQuery)
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    context.read<ProductFilter>().setQuery('');
                  },
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear search',
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort});

  final ProductSort sort;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ProductSort>(
      tooltip: 'Sort products',
      onSelected: context.read<ProductFilter>().setSort,
      itemBuilder: (context) {
        return ProductSort.values
            .map(
              (option) => PopupMenuItem(
                value: option,
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: option == sort
                          ? const Icon(Icons.check, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(option.label),
                  ],
                ),
              ),
            )
            .toList(growable: false);
      },
      child: Chip(
        avatar: const Icon(Icons.sort, size: 18),
        label: Text(sort.label),
      ),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters();

  @override
  Widget build(BuildContext context) {
    final selectedCategory = context.select<ProductFilter, ProductCategory>(
      (filter) => filter.category,
    );
    final categories = context.select<ProductCatalog, List<ProductCategory>>((
      catalog,
    ) {
      final includedCategories = catalog.products
          .map((product) => product.category)
          .toSet();
      return ProductCategory.values
          .where(
            (category) =>
                category == ProductCategory.all ||
                includedCategories.contains(category),
          )
          .toList(growable: false);
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories
            .map((category) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category.label),
                  selected: category == selectedCategory,
                  onSelected: (_) {
                    context.read<ProductFilter>().setCategory(category);
                  },
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _EmptyProductResults extends StatelessWidget {
  const _EmptyProductResults();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search or category.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: context.read<ProductFilter>().clear,
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}
