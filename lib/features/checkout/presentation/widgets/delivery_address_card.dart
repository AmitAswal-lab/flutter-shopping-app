import 'package:flutter/material.dart';

import 'package:shopping_app/features/profile/domain/models/delivery_address.dart';

class DeliveryAddressCard extends StatelessWidget {
  const DeliveryAddressCard({
    super.key,
    required this.address,
    required this.onChange,
    required this.onAdd,
  });

  final DeliveryAddress? address;
  final VoidCallback? onChange;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (address == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivery address',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text('Add a saved address before continuing to payment.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add delivery address'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Delivery address',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(onPressed: onChange, child: const Text('Change')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              address!.label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(address!.formattedAddress),
          ],
        ),
      ),
    );
  }
}
