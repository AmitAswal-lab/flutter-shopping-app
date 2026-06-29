import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!auth.isConfigured)
              _FirebaseSetupMessage(setupError: auth.setupError)
            else
              const _AuthForm(),
          ],
        ),
      ),
    );
  }
}

class _FirebaseSetupMessage extends StatelessWidget {
  final String? setupError;

  const _FirebaseSetupMessage({required this.setupError});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Firebase setup needed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Email and password auth is available, but Firebase could not initialize on this device.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Check that this platform has the correct Firebase configuration file and that its app identifier matches the build.',
            ),
            if (setupError != null) ...[
              const SizedBox(height: 16),
              Text(
                setupError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuthForm extends StatefulWidget {
  const _AuthForm();

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCreatingAccount = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final auth = context.read<AuthController>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isCreatingAccount) {
      await auth.createAccount(
        email: email,
        password: password,
        displayName: _nameController.text,
      );
    } else {
      await auth.signIn(email: email, password: password);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Required';
    if (!email.contains('@')) return 'Enter a valid email';
    return null;
  }

  String? _validateName(String? value) {
    if (!_isCreatingAccount) return null;

    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Required';
    if (name.length < 2) return 'Use at least 2 characters';
    return null;
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
    final title = _isCreatingAccount ? 'Create account' : 'Sign in';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            _isCreatingAccount
                ? 'Create an account with email and password.'
                : 'Sign in to manage your shopping account.',
          ),
          const SizedBox(height: 24),
          if (_isCreatingAccount) ...[
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              textInputAction: TextInputAction.next,
              validator: _validateName,
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _isPasswordVisible = !_isPasswordVisible);
                },
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
              ),
            ),
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            validator: _validatePassword,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (auth.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              auth.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: auth.isBusy ? null : _submit,
            icon: auth.isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isCreatingAccount ? Icons.person_add_alt : Icons.login),
            label: Text(title),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: auth.isBusy
                ? null
                : () {
                    auth.clearMessages();
                    setState(() => _isCreatingAccount = !_isCreatingAccount);
                  },
            child: Text(
              _isCreatingAccount
                  ? 'Already have an account? Sign in'
                  : 'New here? Create an account',
            ),
          ),
        ],
      ),
    );
  }
}
