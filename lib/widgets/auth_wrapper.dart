import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_language.dart';
import '../app_theme_manager.dart';
import '../screens/login_page.dart';
import '../screens/user_home_page.dart';
import '../screens/dashboard_admin.dart';

class AuthWrapper extends StatelessWidget {
  final AppLanguage appLanguage;
  final AppThemeManager themeManager;

  const AuthWrapper({
    super.key,
    required this.appLanguage,
    required this.themeManager,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF386641)),
            ),
          );
        }

        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF386641)),
                  ),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final data = userSnapshot.data!.data() as Map<String, dynamic>?;
                final role = data?['role'] ?? 'user';

                if (role == 'admin') {
                  return DashboardAdmin(themeManager: themeManager);
                } else {
                  return UserHomePage(
                    appLanguage: appLanguage,
                    themeManager: themeManager,
                  );
                }
              }

              // If user document doesn't exist, sign out and go to login
              FirebaseAuth.instance.signOut();
              return LoginPage(
                appLanguage: appLanguage,
                themeManager: themeManager,
              );
            },
          );
        }

        return LoginPage(
          appLanguage: appLanguage,
          themeManager: themeManager,
        );
      },
    );
  }
}
