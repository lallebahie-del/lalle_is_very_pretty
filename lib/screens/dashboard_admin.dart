import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/signalement.dart';
import '../widgets/premium_layout.dart';
import '../widgets/status_chip.dart';
import '../app_theme_manager.dart';
import 'signalement_detail.dart';

class DashboardAdmin extends StatefulWidget {
  final AppThemeManager themeManager;

  const DashboardAdmin({
    super.key,
    required this.themeManager,
  });

  @override
  State<DashboardAdmin> createState() => _DashboardAdminState();
}

class _DashboardAdminState extends State<DashboardAdmin> {
  String _searchQuery = "";
  String _statusFilter = "Tous";
  late Stream<List<Signalement>> _signalementsStream;

  @override
  void initState() {
    super.initState();
    _signalementsStream = _getSignalements();
  }

  Stream<List<Signalement>> _getSignalements() {
    return FirebaseFirestore.instance
        .collection('signalements')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Signalement.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PremiumLayout(
      title: "Dashboard Admin",
      themeManager: widget.themeManager,
      actions: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            tooltip: "Déconnexion",
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
          ),
        ),
      ],
      child: StreamBuilder<List<Signalement>>(
        stream: _signalementsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF386641)));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text("Aucun signalement", style: TextStyle(color: Colors.black)),
            );
          }

          var signalements = snapshot.data!;

          // 🔍 Filtering Logic
          if (_searchQuery.isNotEmpty) {
            signalements = signalements.where((s) {
              final query = _searchQuery.toLowerCase();
              return s.type.toLowerCase().contains(query) ||
                  s.userName.toLowerCase().contains(query) ||
                  (s.description?.toLowerCase().contains(query) ?? false);
            }).toList();
          }

          if (_statusFilter != "Tous") {
            signalements = signalements.where((s) => s.status == _statusFilter).toList();
          }

          // Stats should reflect ALL data, not just filtered (standard dashboard behavior)
          // Or filtered? Let's do filtered to match user expectation of "Search"
          final total = signalements.length;
          final resolved = signalements.where((s) => s.status == 'Résolu').length;
          final inProgress = signalements.where((s) => s.status == 'En cours').length;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // 📊 Stats Cards
                    _buildStatsRow(context, total, inProgress, resolved),
                    
                    const SizedBox(height: 20),

                    // 🔍 Search & Filter Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (value) {
                              // Ensure set state updates the filtered list
                              setState(() => _searchQuery = value);
                            },
                            decoration: InputDecoration(
                              hintText: "Rechercher un signalement...",
                              prefixIcon: const Icon(Icons.search),
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                          const Divider(),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip("Tous"),
                                const SizedBox(width: 8),
                                _buildFilterChip("En attente"),
                                const SizedBox(width: 8),
                                _buildFilterChip("En cours"),
                                const SizedBox(width: 8),
                                _buildFilterChip("Résolu"),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // 📋 List
              if (signalements.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      "Aucun résultat trouvé",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final s = signalements[index];
                      return _buildSignalementCard(context, s, index);
                    },
                    childCount: signalements.length,
                  ),
                ),
              
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String status) {
    final isSelected = _statusFilter == status;
    return ChoiceChip(
      label: Text(status),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() => _statusFilter = selected ? status : "Tous");
      },
      selectedColor: const Color(0xFF386641),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey.shade200,
    );
  }

  Widget _buildStatsRow(BuildContext context, int total, int inProgress, int resolved) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatCard(context, "Total", "$total", Icons.list_alt_rounded, const Color(0xFF386641)),
          _buildStatCard(context, "En cours", "$inProgress", Icons.schedule_rounded, const Color(0xFF2196F3)),
          _buildStatCard(context, "Résolus", "$resolved", Icons.check_circle_rounded, const Color(0xFF4CAF50)),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalementCard(BuildContext context, Signalement s, int index) {
    final formattedDate = DateFormat('dd MMM yyyy', 'fr_FR').format(s.date);
    final formattedTime = DateFormat('HH:mm', 'fr_FR').format(s.date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTapDown: (_) => HapticFeedback.lightImpact(),
        onTap: () async {
          final newStatus = await Navigator.push<String>(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (_, __, ___) => SignalementDetailScreen(
                signalement: s,
                themeManager: widget.themeManager,
              ),
              transitionsBuilder: (_, animation, __, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                );
              },
            ),
          );

          if (newStatus != null) {
            FirebaseFirestore.instance
                .collection('signalements')
                .doc(s.id)
                .update({'status': newStatus});
          }
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🎨 INDICATEUR DE TYPE
                  Container(
                    width: 4,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF386641),
                          Color(0xFF6A994E),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 📸 IMAGE THUMBNAIL (if available)
                  if (s.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        s.imageUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],

                  // 📝 CONTENU
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                s.type,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            StatusChip(status: s.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 16,
                              color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              s.userName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$formattedDate à $formattedTime',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 🔽 INDICATEUR D'ACTION
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.3),
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