import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [_AccountProfile(auth: auth)],
        ),
      ),
    );
  }
}

class _AccountProfile extends StatefulWidget {
  final AuthController auth;

  const _AccountProfile({required this.auth});

  @override
  State<_AccountProfile> createState() => _AccountProfileState();
}

class _AccountProfileState extends State<_AccountProfile> {
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
  void didUpdateWidget(covariant _AccountProfile oldWidget) {
    super.didUpdateWidget(oldWidget);

    final user = widget.auth.user;
    final displayName = user?.displayName ?? '';
    final userChanged = user?.uid != _userId;
    final savedNameChanged =
        !_nameFocusNode.hasFocus && _nameController.text != displayName;

    if (userChanged || savedNameChanged) {
      _syncNameFromUser();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _syncNameFromUser() {
    final user = widget.auth.user;
    _userId = user?.uid;
    _nameController.text = user?.displayName ?? '';
  }

  Future<void> _saveProfile() async {
    final form = _profileFormKey.currentState;
    if (form == null || !form.validate()) return;

    await widget.auth.updateDisplayName(_nameController.text);
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
    final auth = widget.auth;
    final user = auth.user;
    final displayName = user?.displayName?.trim();
    final profileName = displayName == null || displayName.isEmpty
        ? 'Shopper'
        : displayName;

    return Column(
      children: [
        Card(
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
                Text(
                  profileName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(user?.email ?? 'No email available'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: auth.isBusy ? null : auth.signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _profileFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
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
          ),
        ),
      ],
    );
  }
}
