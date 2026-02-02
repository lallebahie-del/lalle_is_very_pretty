import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_language.dart';
import '../app_strings.dart';

class RegisterPage extends StatefulWidget {
  final AppLanguage appLanguage;
  const RegisterPage({super.key, required this.appLanguage});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  bool isEmailValid = false;
  bool isPasswordValid = false;
  bool isConfirmPasswordValid = false;

  String? error;
  bool loading = false;

  static const headerColor = Color(0xFF386641);

  bool validateEmail(String value) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value);
  }

  bool validatePassword(String value) {
    return value.length >= 6;
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.appLanguage.code;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.language, color: Colors.white),
            onPressed: widget.appLanguage.toggle,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF386641), Color(0xFF6A994E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.get('register', lang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Créez votre compte pour commencer",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(top: 30),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        if (error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 20),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Text(
                              error!,
                              style: TextStyle(color: Colors.red.shade700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        _field(firstName, AppStrings.get('first_name', lang), icon: Icons.person_outline),
                        _field(lastName, AppStrings.get('last_name', lang), icon: Icons.person_outline),
                        _field(phone, AppStrings.get('phone', lang), type: TextInputType.phone, icon: Icons.phone_outlined),
                        _field(
                          email,
                          AppStrings.get('email', lang),
                          icon: Icons.email_outlined,
                          onChanged: (v) {
                            setState(() => isEmailValid = validateEmail(v));
                          },
                          suffixIcon: email.text.isEmpty ? null : _icon(isEmailValid),
                        ),
                        _field(
                          password,
                          AppStrings.get('password', lang),
                          obscure: true,
                          icon: Icons.lock_outline,
                          onChanged: (v) {
                            setState(() {
                              isPasswordValid = validatePassword(v);
                              isConfirmPasswordValid = confirmPassword.text == v && v.isNotEmpty;
                            });
                          },
                          suffixIcon: password.text.isEmpty ? null : _icon(isPasswordValid),
                        ),
                        _field(
                          confirmPassword,
                          AppStrings.get('confirm_password', lang),
                          obscure: true,
                          icon: Icons.lock_reset_outlined,
                          onChanged: (v) {
                            setState(() {
                              isConfirmPasswordValid = v == password.text && v.isNotEmpty;
                            });
                          },
                          suffixIcon: confirmPassword.text.isEmpty ? null : _icon(isConfirmPasswordValid),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: loading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF386641),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 5,
                            ),
                            child: loading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    AppStrings.get('register', lang),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(color: Colors.grey),
                              children: [
                                TextSpan(text: "Vous avez déjà un compte ? "),
                                TextSpan(
                                  text: "Se connecter",
                                  style: TextStyle(
                                    color: Color(0xFF386641),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  }

  Widget _icon(bool ok) {
    return Icon(
      ok ? Icons.check_circle : Icons.cancel,
      color: ok ? Colors.green : Colors.red,
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    TextInputType type = TextInputType.text,
    void Function(String)? onChanged,
    Widget? suffixIcon,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: type,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF386641).withOpacity(0.7)) : null,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.grey.shade50,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          floatingLabelStyle: const TextStyle(
            color: Color(0xFF386641),
            fontWeight: FontWeight.bold,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF386641), width: 2),
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!isEmailValid || !isPasswordValid || !isConfirmPasswordValid) {
      setState(() => error = "Veuillez corriger les champs");
      return;
    }

    setState(() {
      error = null;
      loading = true;
    });

    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email.text.trim().toLowerCase(),
        password: password.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim(),
        'phone': phone.text.trim(),
        'email': email.text.trim().toLowerCase(),
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
    } catch (e) {
      setState(() => error = "Erreur lors de l'inscription");
    } finally {
      setState(() => loading = false);
    }
  }
}
