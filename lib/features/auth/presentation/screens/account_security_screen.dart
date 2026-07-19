import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/auth/data/services/account_security_service.dart';
import 'package:shopping_app/features/auth/presentation/controllers/auth_controller.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthController>().clearMessages();
    });
  }

  Future<void> _refreshVerificationStatus() async {
    await context.read<AuthController>().refreshCurrentUser();
  }

  Future<void> _sendVerificationEmail() async {
    await context.read<AuthController>().sendEmailVerification();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final emailVerified = user?.emailVerified ?? false;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
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
                      'Email verification',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(user?.email ?? 'No email available'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          emailVerified
                              ? Icons.verified_outlined
                              : Icons.mark_email_unread_outlined,
                          color: emailVerified
                              ? colorScheme.primary
                              : colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            emailVerified
                                ? 'Your email is verified.'
                                : 'Your email has not been verified yet.',
                          ),
                        ),
                      ],
                    ),
                    if (!emailVerified) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: auth.isBusy ? null : _sendVerificationEmail,
                        icon: const Icon(Icons.forward_to_inbox_outlined),
                        label: const Text('Send verification email'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: auth.isBusy
                          ? null
                          : _refreshVerificationStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh verification status'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.password_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('Change password'),
                subtitle: const Text('Use your current password to continue'),
                trailing: const Icon(Icons.chevron_right),
                onTap: auth.isBusy
                    ? null
                    : () => _showChangePasswordDialog(context),
              ),
            ),
            const SizedBox(height: 24),
            Text('Danger zone', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: colorScheme.error,
                ),
                title: Text(
                  'Delete account',
                  style: TextStyle(color: colorScheme.error),
                ),
                subtitle: const Text(
                  'Permanently remove your shopping account and app data',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: auth.isBusy
                    ? null
                    : () => _showDeleteAccountDialog(context),
              ),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                auth.errorMessage!,
                style: TextStyle(color: colorScheme.error),
              ),
            ] else if (auth.successMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                auth.successMessage!,
                style: TextStyle(color: colorScheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final auth = context.read<AuthController>();
    auth.clearMessages();
    await auth.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );
    if (!mounted || auth.errorMessage != null) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password changed.')));
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Required';
    if (password.length < 6) return 'Use at least 6 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return AlertDialog(
      title: const Text('Change password'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PasswordField(
                controller: _currentPasswordController,
                label: 'Current password',
                isVisible: _isCurrentPasswordVisible,
                onVisibilityChanged: () {
                  setState(
                    () =>
                        _isCurrentPasswordVisible = !_isCurrentPasswordVisible,
                  );
                },
                validator: _validatePassword,
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _newPasswordController,
                label: 'New password',
                isVisible: _isNewPasswordVisible,
                onVisibilityChanged: () {
                  setState(
                    () => _isNewPasswordVisible = !_isNewPasswordVisible,
                  );
                },
                validator: _validatePassword,
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm new password',
                isVisible: _isNewPasswordVisible,
                onVisibilityChanged: () {
                  setState(
                    () => _isNewPasswordVisible = !_isNewPasswordVisible,
                  );
                },
                validator: (value) {
                  final error = _validatePassword(value);
                  if (error != null) return error;
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  auth.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: auth.isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: auth.isBusy ? null : _submit,
          child: auth.isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save password'),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _confirmationController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _confirmationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_confirmationController.text.trim() != 'DELETE') {
      setState(() {});
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() {});
      return;
    }

    final auth = context.read<AuthController>();
    auth.clearMessages();
    await auth.deleteAccount(
      currentPassword: _passwordController.text,
      securityService: context.read<AccountSecurityService>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final confirmationIsValid = _confirmationController.text.trim() == 'DELETE';
    final passwordIsValid = _passwordController.text.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Delete account?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your profile, delivery addresses, cart, wishlist, and order history from the app.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmationController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Type DELETE to confirm',
                errorText:
                    _confirmationController.text.isEmpty || confirmationIsValid
                    ? null
                    : 'Type DELETE exactly',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _passwordController,
              label: 'Current password',
              isVisible: _isPasswordVisible,
              onVisibilityChanged: () {
                setState(() => _isPasswordVisible = !_isPasswordVisible);
              },
              validator: (_) => null,
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                auth.errorMessage!,
                style: TextStyle(color: colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: auth.isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: auth.isBusy || !confirmationIsValid || !passwordIsValid
              ? null
              : _deleteAccount,
          icon: auth.isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_forever_outlined),
          label: const Text('Delete account'),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isVisible;
  final VoidCallback onVisibilityChanged;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.isVisible,
    required this.onVisibilityChanged,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: onVisibilityChanged,
          icon: Icon(
            isVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          tooltip: isVisible ? 'Hide password' : 'Show password',
        ),
      ),
      obscureText: !isVisible,
      validator: validator,
    );
  }
}
