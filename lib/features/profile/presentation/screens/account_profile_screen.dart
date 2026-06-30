import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:shopping_app/features/profile/domain/models/user_profile.dart';
import 'package:shopping_app/features/profile/presentation/controllers/user_profile_controller.dart';

class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({super.key});

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _syncNameFromUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncNameFromUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _syncNameFromUser() {
    final auth = context.read<AuthController>();
    final user = auth.user;
    final displayName = user?.displayName ?? '';
    final userChanged = user?.uid != _userId;
    final savedNameChanged =
        !_nameFocusNode.hasFocus && _nameController.text != displayName;

    if (!userChanged && !savedNameChanged) return;

    _userId = user?.uid;
    _nameController.text = displayName;
  }

  Future<void> _saveProfile() async {
    final form = _profileFormKey.currentState;
    if (form == null || !form.validate()) return;

    final auth = context.read<AuthController>();
    await auth.updateDisplayName(_nameController.text);
    if (!mounted) return;

    final userProfile = context.read<UserProfileController>();
    await userProfile.save(
      UserProfile(
        displayName: _nameController.text,
        fullName: userProfile.profile.fullName,
        phoneNumber: userProfile.profile.phoneNumber,
        deliveryAddress: userProfile.profile.deliveryAddress,
      ),
    );
    _nameFocusNode.unfocus();
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Required';
    if (name.length < 2) return 'Use at least 2 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _profileFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    textInputAction: TextInputAction.done,
                    validator: _validateName,
                    onChanged: (_) => auth.clearMessages(),
                    onFieldSubmitted: (_) => _saveProfile(),
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      auth.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ] else if (auth.successMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      auth.successMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: auth.isBusy ? null : _saveProfile,
                    icon: auth.isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save profile'),
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
