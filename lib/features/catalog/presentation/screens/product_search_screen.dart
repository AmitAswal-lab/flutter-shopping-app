import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/catalog/presentation/controllers/product_filter.dart';
import 'package:shopping_app/features/settings/presentation/controllers/app_preferences.dart';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleSearchTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    _controller.text = context.read<ProductFilter>().query;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _initialized = true;
  }

  @override
  void dispose() {
    _controller.removeListener(_handleSearchTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSearchTextChanged() {
    setState(() {});
  }

  Future<void> _search(String query) async {
    final nextQuery = query.trim();
    context.read<ProductFilter>().setQuery(nextQuery);

    if (nextQuery.isNotEmpty) {
      await context.read<AppPreferences>().addRecentSearch(nextQuery);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentSearches = context.select<AppPreferences, List<String>>(
      (preferences) => preferences.recentSearches,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: Navigator.of(context).pop,
                    icon: const Icon(Icons.arrow_back_ios_new),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SearchInput(
                      controller: _controller,
                      focusNode: _focusNode,
                      onSubmitted: _search,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: recentSearches.isEmpty
                  ? const _EmptySearchHistory()
                  : ListView.separated(
                      itemCount: recentSearches.length,
                      separatorBuilder: (context, index) {
                        return const Divider(height: 1);
                      },
                      itemBuilder: (context, index) {
                        final search = recentSearches[index];
                        return _RecentSearchTile(
                          search: search,
                          onSelected: () => _search(search),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Search products',
        prefixIcon: const Icon(Icons.search),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close),
                tooltip: 'Clear search',
              ),
      ),
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  const _RecentSearchTile({required this.search, required this.onSelected});

  final String search;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 24, right: 24),
      onTap: onSelected,
      leading: const Icon(Icons.history),
      title: Text(
        search,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      trailing: IconButton(
        onPressed: () {
          context.read<AppPreferences>().removeRecentSearch(search);
        },
        icon: const Icon(Icons.close),
        tooltip: 'Remove search',
      ),
    );
  }
}

class _EmptySearchHistory extends StatelessWidget {
  const _EmptySearchHistory();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_search, size: 56, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'No recent searches',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
