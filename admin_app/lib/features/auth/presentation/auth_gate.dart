import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../common/loading_scaffold.dart';
import '../../shell/presentation/admin_shell.dart';
import 'access_message_page.dart';
import 'sign_in_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScaffold(message: 'Checking session');
        }

        final user = snapshot.data;
        if (user == null) return const SignInPage();

        return AdminAccessGate(user: user);
      },
    );
  }
}

class AdminAccessGate extends StatelessWidget {
  const AdminAccessGate({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScaffold(message: 'Checking admin access');
        }

        if (snapshot.hasError) {
          return AccessMessagePage(
            title: 'Could not verify admin access',
            body: snapshot.error.toString(),
            uid: user.uid,
          );
        }

        if (snapshot.data?.exists != true) {
          return AccessMessagePage(
            title: 'No admin access',
            body:
                'Create a Firestore document at admins/${user.uid}, then sign in again.',
            uid: user.uid,
          );
        }

        return AdminShell(user: user);
      },
    );
  }
}
