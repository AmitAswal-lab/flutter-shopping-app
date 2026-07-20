import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/features/auth/presentation/controllers/auth_controller.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshVerificationStatus();
    }
  }

  Future<void> _refreshVerificationStatus() async {
    final auth = context.read<AuthController>();
    if (auth.isBusy) return;
    await auth.refreshCurrentUser();
  }

  Future<void> _resendVerificationEmail() async {
    await context.read<AuthController>().sendEmailVerification();
  }

  Future<void> _signOut() async {
    await context.read<AuthController>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final colorScheme = Theme.of(context).colorScheme;
    final email = auth.user?.email ?? 'your email address';

    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.mark_email_unread_outlined,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Check your inbox',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We sent a verification link to $email. Verify that '
                        'address before continuing to the shop.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: auth.isBusy
                            ? null
                            : _refreshVerificationStatus,
                        icon: auth.isBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('I have verified my email'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: auth.isBusy
                            ? null
                            : _resendVerificationEmail,
                        icon: const Icon(Icons.forward_to_inbox_outlined),
                        label: const Text('Resend verification email'),
                      ),
                      TextButton.icon(
                        onPressed: auth.isBusy ? null : _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Use a different account'),
                      ),
                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          auth.errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ] else if (auth.successMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          auth.successMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.primary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
