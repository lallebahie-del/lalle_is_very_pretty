import 'dart:io';
import 'dart:convert'; // Pour Base64
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_language.dart';
import '../app_theme_manager.dart';

class ReportPage extends StatefulWidget {
  final AppLanguage appLanguage;
  final AppThemeManager themeManager;

  const ReportPage({
    super.key,
    required this.appLanguage,
    required this.themeManager,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  File? _imageFile;
  String? _imageFileName;
  String? _selectedCategory;
  bool _loading = false;
  Position? _currentPosition;
  String? _error;
  String? _imageBase64; // ✅ Stockage de l'image en Base64

  final List<String> _categories = [
    'Voirie',
    'Éclairage',
    'Déchets',
    'Eau',
    'Électricité',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _descriptionController.text = prefs.getString('draft_desc') ?? '';
      _selectedCategory = prefs.getString('draft_cat');
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('draft_desc', _descriptionController.text);
    if (_selectedCategory != null) {
      await prefs.setString('draft_cat', _selectedCategory!);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Brouillon sauvegardé")),
      );
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('draft_desc');
    await prefs.remove('draft_cat');
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _error = "Le GPS est désactivé sur votre téléphone.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _error = "Permission GPS refusée.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _error = "Les permissions GPS sont bloquées. Veuillez les activer dans les réglages.");
        return;
      }

      // 🔹 Recherche de la position avec un délai d'attente
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium, // Plus rapide et précis pour ce besoin
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        // En cas de timeout ou erreur, on tente la dernière position connue
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          setState(() => _error = "Impossible de trouver votre position. Vérifiez votre connexion.");
        }
      }

      if (position != null) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
            _error = null;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = "Erreur GPS : $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _loading = true; // Optionnel: montrer un loader pendant la compression
      _error = null;
    });

    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // 🔹 Conversion immédiate en Base64 pour éviter de perdre le fichier temporaire
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);

        if (mounted) {
          setState(() {
            _imageFile = File(pickedFile.path);
            _imageFileName = pickedFile.name;
            _imageBase64 = base64String;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = "Erreur lors de la sélection de l'image : $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitReport() async {
    if (_selectedCategory == null || _descriptionController.text.isEmpty) {
      setState(() => _error = "Veuillez remplir tous les champs");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      // 🔹 Récupération du nom depuis Firestore /users
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();
      final nom = data?['nom'] ?? '';
      final prenom = data?['prenom'] ?? '';
      final fullName = ('$nom $prenom').trim();
      final userName = fullName.isEmpty ? 'Anonyme' : fullName;

      // ✅ Utilisation du Base64 déjà calculé
      final imageBase64Data = _imageBase64;

      // Enregistrement Firestore
      await FirebaseFirestore.instance.collection('signalements').add({
        'userId': user.uid,
        'userName': userName, // ✅ vrai nom maintenant
        'type': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'imageBase64': imageBase64Data, // ✅ Nouveau nom de variable
        'imageFileName': _imageFileName,
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
        'status': 'En attente',
        'date': FieldValue.serverTimestamp(),
      });

      await _clearDraft();

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.network(
                  'https://assets2.lottiefiles.com/packages/lf20_7W0ppo.json',
                  repeat: false,
                  height: 150,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.check_circle, color: Colors.green, size: 80),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Merci !",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Votre signalement a bien été reçu.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = "Erreur lors de l'envoi : $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeManager.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nouveau Signalement"),
        backgroundColor: const Color(0xFF386641),
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _saveDraft,
            icon: const Icon(Icons.save_outlined, color: Colors.white),
            label: const Text("Brouillon", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            GestureDetector(
              onTap: () => _showImageSourceModal(context),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _imageFile != null ? const Color(0xFF386641) : Colors.transparent,
                    width: 2,
                  ),
                  image: _imageFile != null
                      ? DecorationImage(
                    image: FileImage(_imageFile!),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: _imageFile == null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_rounded,
                      size: 48,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Ajouter une photo",
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                )
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _currentPosition != null
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _currentPosition != null ? Icons.location_on : Icons.location_off,
                    color: _currentPosition != null ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentPosition != null
                          ? "Position GPS acquise"
                          : "Recherche de la position...",
                      style: TextStyle(
                        color: _currentPosition != null ? Colors.green : Colors.orange[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_currentPosition == null)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: "Catégorie",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF386641), width: 2),
                ),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: "Description du problème",
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF386641), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF386641),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "ENVOYER LE SIGNALEMENT",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Caméra'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }
}
