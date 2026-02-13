import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/signalement.dart';
import '../widgets/premium_layout.dart';
import '../widgets/status_chip.dart';
import '../app_theme_manager.dart';
import 'signalement_detail.dart';

class SignalementListScreen extends StatefulWidget {
  final AppThemeManager themeManager;

  const SignalementListScreen({
    super.key,
    required this.themeManager,
  });

  @override
  State<SignalementListScreen> createState() =>
      _SignalementListScreenState();
}

class _SignalementListScreenState
    extends State<SignalementListScreen> {
  final List<Signalement> _signalements = [];
  final Map<String, String> _userNamesCache = {};

  @override
  void initState() {
    super.initState();
    _loadSignalements();
  }

  Future<String> _getUserName(String userId) async {
    if (_userNamesCache.containsKey(userId)) {
      return _userNamesCache[userId]!;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final data = userDoc.data();
    final nom = data?['nom'] ?? '';
    final prenom = data?['prenom'] ?? '';
    final fullName = ('$prenom $nom').trim();

    final name = fullName.isEmpty ? 'Anonyme' : fullName;
    _userNamesCache[userId] = name;
    return name;
  }

  Future<void> _loadSignalements() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('signalements')
        .orderBy('date', descending: true)
        .get();

    final loaded = snapshot.docs.map((doc) {
      final data = doc.data();
      return Signalement(
        id: doc.id,
        userName: '',
        type: data['type'] ?? 'Autre',
        date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        status: data['status'] ?? 'En attente',
        description: data['description'] ?? '',
      );
    }).toList();

    setState(() {
      _signalements.clear();
      _signalements.addAll(loaded);
    });

    // Charger les noms
    for (int i = 0; i < snapshot.docs.length; i++) {
      final userId = snapshot.docs[i]['userId'];
      final name = await _getUserName(userId);
      setState(() {
        _signalements[i].userName = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumLayout(
      title: "Signalements",
      themeManager: widget.themeManager,
      child: ListView.builder(
        itemCount: _signalements.length,
        itemBuilder: (_, i) {
          final s = _signalements[i];
          return ListTile(
            title: Text(s.type),
            subtitle: Text(
              "Utilisateur : ${s.userName.isEmpty ? 'Chargement...' : s.userName}",
            ),
            trailing: StatusChip(status: s.status),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SignalementDetailScreen(
                  signalement: s,
                  themeManager: widget.themeManager,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
