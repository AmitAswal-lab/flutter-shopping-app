import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/profile/domain/models/delivery_address.dart';
import 'package:shopping_app/features/profile/presentation/controllers/delivery_addresses_controller.dart';
import 'package:shopping_app/features/profile/presentation/controllers/user_profile_controller.dart';
import 'package:shopping_app/features/profile/presentation/screens/delivery_address_form_screen.dart';

class DeliveryProfileScreen extends StatelessWidget {
  const DeliveryProfileScreen({super.key});

  Future<void> _openEditor(
    BuildContext context, {
    DeliveryAddress? address,
  }) async {
    final addresses = context.read<DeliveryAddressesController>();
    final profile = context.read<UserProfileController>().profile;
    final draft =
        address ??
        DeliveryAddress(
          id: '',
          label: 'Home',
          fullName: profile.fullName,
          phoneNumber: profile.phoneNumber,
          address: profile.deliveryAddress,
          isDefault: addresses.addresses.isEmpty,
        );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeliveryAddressFormScreen(address: draft),
      ),
    );
  }

  Future<void> _deleteAddress(
    BuildContext context,
    DeliveryAddress address,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove ${address.label} from your saved addresses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true && context.mounted) {
      await context.read<DeliveryAddressesController>().delete(address.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = context.watch<DeliveryAddressesController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery addresses'),
        actions: [
          IconButton(
            tooltip: 'Add address',
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
      body: addresses.isLoading
          ? const Center(child: CircularProgressIndicator())
          : addresses.addresses.isEmpty
          ? const _EmptyAddresses()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.addresses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final address = addresses.addresses[index];
                return Card(
                  child: ListTile(
                    onTap: () => _openEditor(context, address: address),
                    leading: Icon(
                      address.isDefault
                          ? Icons.home_outlined
                          : Icons.location_on_outlined,
                    ),
                    title: Row(
                      children: [
                        Flexible(child: Text(address.label)),
                        if (address.isDefault) ...[
                          const SizedBox(width: 8),
                          const Chip(label: Text('Default')),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${address.fullName}\n${address.summary}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'default') {
                          await addresses.setDefault(address.id);
                        } else if (value == 'delete') {
                          await _deleteAddress(context, address);
                        }
                      },
                      itemBuilder: (_) => [
                        if (!address.isDefault)
                          const PopupMenuItem(
                            value: 'default',
                            child: Text('Make default'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyAddresses extends StatelessWidget {
  const _EmptyAddresses();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_outlined, size: 48),
            SizedBox(height: 16),
            Text('No delivery addresses yet'),
            SizedBox(height: 8),
            Text(
              'Add an address before checkout.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
