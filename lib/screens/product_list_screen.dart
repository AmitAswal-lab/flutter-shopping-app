import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart.dart';
import '../models/product.dart';
import '../models/product_filter.dart';
import '../models/wishlist.dart';
import '../widgets/product_card.dart';
import 'cart_screen.dart';
import 'wishlist_screen.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: const [_WishlistBadge(), _CartBadge()],
      ),
      body: const _ProductCatalog(),
    );
  }
}

class _ProductCatalog extends StatelessWidget {
  const _ProductCatalog();

  @override
  Widget build(BuildContext context) {
    final visibleProducts = context.select<ProductFilter, List<Product>>(
      (filter) => filter.applyTo(kProducts),
    );

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: _SearchAndFilterHeader()),
        if (visibleProducts.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyProductResults(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverGrid.builder(
              itemCount: visibleProducts.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                return ProductCard(product: visibleProducts[index]);
              },
            ),
          ),
      ],
    );
  }
}

class _SearchAndFilterHeader extends StatelessWidget {
  const _SearchAndFilterHeader();

  @override
  Widget build(BuildContext context) {
    final visibleCount = context.select<ProductFilter, int>(
      (filter) => filter.applyTo(kProducts).length,
    );
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
                  label: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductSearchField extends StatefulWidget {
  const _ProductSearchField();

  @override
  State<_ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends State<_ProductSearchField> {
  final _controller = TextEditingController();
  ProductFilter? _filter;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextFilter = context.read<ProductFilter>();
    if (_filter == nextFilter) return;

    _filter?.removeListener(_syncFromFilter);
    _filter = nextFilter..addListener(_syncFromFilter);
    _syncFromFilter();
  }

  @override
  void dispose() {
    _filter?.removeListener(_syncFromFilter);
    _controller
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    context.read<ProductFilter>().setQuery(_controller.text);
    setState(() {});
  }

  void _syncFromFilter() {
    final filterQuery = _filter?.query ?? '';
    if (filterQuery.isEmpty && _controller.text.isNotEmpty) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search products',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: _controller.clear,
                icon: const Icon(Icons.close),
                tooltip: 'Clear search',
              ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ProductCategory.values
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

class _WishlistBadge extends StatelessWidget {
  const _WishlistBadge();

  @override
  Widget build(BuildContext context) {
    final count = context.select<Wishlist, int>((wishlist) => wishlist.count);
    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.favorite_border),
      ),
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const WishlistScreen()));
      },
    );
  }
}

class _CartBadge extends StatelessWidget {
  const _CartBadge();

  @override
  Widget build(BuildContext context) {
    final count = context.select<Cart, int>((cart) => cart.totalCount);
    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CartScreen()));
      },
    );
  }
}
