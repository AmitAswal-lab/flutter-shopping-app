import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:shopping_app/features/profile/presentation/controllers/user_profile_controller.dart';
import 'package:shopping_app/features/profile/presentation/screens/account_profile_screen.dart';
import 'package:shopping_app/features/profile/presentation/screens/delivery_profile_screen.dart';
import 'package:shopping_app/features/settings/presentation/screens/settings_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final deliveryProfile = context.watch<UserProfileController>().profile;
    final user = auth.user;
    final displayName = user?.displayName?.trim();
    final profileName = displayName == null || displayName.isEmpty
        ? 'Shopper'
        : displayName;
    final deliverySummary = deliveryProfile.hasDeliveryDetails
        ? deliveryProfile.deliveryAddress
        : 'Add delivery details';

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _AccountHeader(
              name: profileName,
              email: user?.email ?? 'No email available',
              onSignOut: auth.isBusy ? null : auth.signOut,
            ),
            const SizedBox(height: 16),
            _AccountActionTile(
              icon: Icons.account_circle_outlined,
              title: 'Profile',
              subtitle: profileName,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountProfileScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _AccountActionTile(
              icon: Icons.local_shipping_outlined,
              title: 'Delivery',
              subtitle: deliverySummary,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DeliveryProfileScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _AccountActionTile(
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Theme and app preferences',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback? onSignOut;

  const _AccountHeader({
    required this.name,
    required this.email,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(email),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
