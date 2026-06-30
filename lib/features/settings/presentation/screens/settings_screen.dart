import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/settings/presentation/controllers/app_preferences.dart';

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
          ],
        ),
      ),
    );
  }
}
