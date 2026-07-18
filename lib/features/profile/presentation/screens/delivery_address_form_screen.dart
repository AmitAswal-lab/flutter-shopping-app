import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/profile/domain/models/delivery_address.dart';
import 'package:shopping_app/features/profile/presentation/controllers/delivery_addresses_controller.dart';

class DeliveryAddressFormScreen extends StatefulWidget {
  const DeliveryAddressFormScreen({super.key, required this.address});

  final DeliveryAddress address;

  @override
  State<DeliveryAddressFormScreen> createState() =>
      _DeliveryAddressFormScreenState();
}

class _DeliveryAddressFormScreenState extends State<DeliveryAddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.address.label);
    _nameController = TextEditingController(text: widget.address.fullName);
    _phoneController = TextEditingController(text: widget.address.phoneNumber);
    _addressController = TextEditingController(text: widget.address.address);
    _isDefault = widget.address.isDefault;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final controller = context.read<DeliveryAddressesController>();
    await controller.save(
      widget.address.copyWith(
        label: _labelController.text,
        fullName: _nameController.text,
        phoneNumber: _phoneController.text,
        address: _addressController.text,
        isDefault: _isDefault,
      ),
    );
    if (mounted && controller.errorMessage == null) Navigator.of(context).pop();
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeliveryAddressesController>();
    final isNew = widget.address.id.isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'Add address' : 'Edit address')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _labelController,
                    decoration: const InputDecoration(
                      labelText: 'Address label',
                      hintText: 'Home, Work, or Other',
                      prefixIcon: Icon(Icons.bookmark_outline),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Delivery address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    maxLines: 4,
                    validator: _required,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isDefault,
                    onChanged: widget.address.isDefault
                        ? null
                        : (value) => setState(() => _isDefault = value),
                    title: const Text('Use as default address'),
                  ),
                  if (controller.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        controller.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: controller.isSaving ? null : _save,
                      icon: controller.isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(isNew ? 'Save address' : 'Save changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
