import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AccessMessagePage extends StatelessWidget {
  const AccessMessagePage({
    super.key,
    required this.title,
    required this.body,
    required this.uid,
  });

  final String title;
  final String body;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 44),
                  const SizedBox(height: 16),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(body),
                  const SizedBox(height: 16),
                  SelectableText('UID: $uid'),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
