import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_preferences.dart';
import '../providers/product_catalog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<AppPreferences>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<AppThemePreference>(
                        segments: AppThemePreference.values.map((preference) {
                          return ButtonSegment<AppThemePreference>(
                            value: preference,
                            label: Text(preference.label),
                          );
                        }).toList(),
                        selected: {preferences.themePreference},
                        onSelectionChanged: (selection) {
                          preferences.setThemePreference(selection.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              const _CatalogDeveloperCard(),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatalogDeveloperCard extends StatelessWidget {
  const _CatalogDeveloperCard();

  Future<void> _syncCatalog(BuildContext context) async {
    final succeeded = await context.read<ProductCatalog>().syncSampleProducts();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            succeeded
                ? 'Sample catalog synced with Firestore.'
                : context.read<ProductCatalog>().errorMessage ??
                      'Could not sync the sample catalog.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<ProductCatalog>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Developer', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Batch-merge the bundled sample catalog into Firestore.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: catalog.isSyncing
                    ? null
                    : () => _syncCatalog(context),
                icon: catalog.isSyncing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(
                  catalog.isSyncing ? 'Syncing catalog...' : 'Sync catalog',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
