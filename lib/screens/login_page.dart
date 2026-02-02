import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_language.dart';
import '../app_strings.dart';
import '../app_theme_manager.dart';

class LoginPage extends StatefulWidget {
  final AppLanguage appLanguage;
  final AppThemeManager themeManager;

  const LoginPage({
    super.key,
    required this.appLanguage,
    required this.themeManager,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  String? error;
  bool loading = false;

  static const Color primaryGreen = Color(0xFF386641);

  @override
  Widget build(BuildContext context) {
    final lang = widget.appLanguage.code;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF386641), // Vert principal comme premier couleur
              Color(0xFF4A8C5D), // Une teinte légèrement plus claire
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [

              // 🔝 TOP BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.language, color: Colors.white),
                      onPressed: widget.appLanguage.toggle,
                    ),
                    IconButton(
                      icon: Icon(
                        widget.themeManager.themeMode == ThemeMode.dark
                            ? Icons.light_mode
                            : Icons.dark_mode,
                        color: Colors.white,
                      ),
                      onPressed: widget.themeManager.toggleTheme,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 🧊 GLASS CONTAINER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85), // Augmenté l'opacité pour mieux contraster avec le fond vert
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                          Text(
                            AppStrings.get('welcome', lang),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppStrings.get('login', lang),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 24),

                          if (error != null)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                error!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          _field(
                            controller: email,
                            label: AppStrings.get('email', lang),
                            icon: Icons.email,
                          ),

                          const SizedBox(height: 16),

                          _field(
                            controller: password,
                            label: AppStrings.get('password', lang),
                            icon: Icons.lock,
                            obscure: true,
                          ),

                          const SizedBox(height: 10),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _resetPassword,
                              child: Text(
                                AppStrings.get('forgot_password', lang),
                                style: const TextStyle(color: primaryGreen),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: loading
                                  ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                                  : Text(
                                AppStrings.get('login', lang),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/register'),
                            child: Text(
                              AppStrings.get('register', lang),
                              style: const TextStyle(color: primaryGreen),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // 🔐 LOGIN
  Future<void> _login() async {
    setState(() {
      error = null;
      loading = true;
    });

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        Navigator.pushReplacementNamed(
          context,
          doc['role'] == 'admin' ? '/admin' : '/user',
        );
      } else {
        // Handle case where user exists in Auth but not in Firestore
        setState(() {
          error = "Profil utilisateur non trouvé";
        });
        await FirebaseAuth.instance.signOut();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Login error: ${e.code}");
      setState(() {
        if (e.code == 'user-not-found') {
          error = 'Compte inexistant';
        } else if (e.code == 'wrong-password') {
          error = 'Mot de passe incorrect';
        } else if (e.code == 'network-request-failed') {
          error = 'Problème de connexion internet';
        } else if (e.code == 'too-many-requests') {
          error = 'Trop de tentatives, réessayez plus tard';
        } else {
          error = 'Erreur de connexion (${e.code})';
        }
      });
    } catch (e) {
      debugPrint("Unexpected login error: $e");
      setState(() {
        error = 'Une erreur inattendue est survenue';
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ✉️ RESET PASSWORD
  void _resetPassword() async {
    if (email.text.isEmpty) {
      setState(() => error = 'Veuillez entrer votre email');
      return;
    }

    await FirebaseAuth.instance
        .sendPasswordResetEmail(email: email.text.trim());

    setState(() {
      error = 'Email de réinitialisation envoyé';
    });
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryGreen.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.black54),
      ),
    );
  }
}