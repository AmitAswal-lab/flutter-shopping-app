import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:shopping_app/features/profile/domain/models/user_profile.dart';
import 'package:shopping_app/features/profile/presentation/controllers/user_profile_controller.dart';

class DeliveryProfileScreen extends StatefulWidget {
  const DeliveryProfileScreen({super.key});

  @override
  State<DeliveryProfileScreen> createState() => _DeliveryProfileScreenState();
}

class _DeliveryProfileScreenState extends State<DeliveryProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _hasSyncedProfile = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final controller = context.watch<UserProfileController>();
    final profile = controller.profile;

    if (!_hasSyncedProfile && !controller.isLoading) {
      _syncFields(profile);
      _hasSyncedProfile = true;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _syncFields(UserProfile profile) {
    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phoneNumber;
    _addressController.text = profile.deliveryAddress;
  }

  Future<void> _saveDeliveryProfile() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final auth = context.read<AuthController>();
    final userProfile = context.read<UserProfileController>();
    final displayName = auth.user?.displayName ?? '';

    await userProfile.save(
      UserProfile(
        displayName: displayName,
        fullName: _fullNameController.text,
        phoneNumber: _phoneController.text,
        deliveryAddress: _addressController.text,
      ),
    );
  }

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return null;
    if (phone.length < 7) return 'Enter a valid phone number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = context.watch<UserProfileController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: _requiredField,
                    onChanged: (_) => userProfile.clearMessages(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: _validatePhone,
                    onChanged: (_) => userProfile.clearMessages(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Default delivery address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    validator: _requiredField,
                    onChanged: (_) => userProfile.clearMessages(),
                  ),
                  if (userProfile.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      userProfile.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ] else if (userProfile.successMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      userProfile.successMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: userProfile.isSaving
                        ? null
                        : _saveDeliveryProfile,
                    icon: userProfile.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.local_shipping_outlined),
                    label: const Text('Save delivery profile'),
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
