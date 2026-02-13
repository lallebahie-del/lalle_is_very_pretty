import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_language.dart';
import '../app_theme_manager.dart';
import '../models/signalement.dart';

class MapPage extends StatefulWidget {
  final AppLanguage appLanguage;
  final AppThemeManager themeManager;

  const MapPage({
    super.key,
    required this.appLanguage,
    required this.themeManager,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _controller;
  Set<Marker> _markers = {}; // Removed final to allow re-assignment
  bool _showOnlyMyReports = false;
  
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(33.5731, -7.5898), 
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          14,
        ),
      );
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  void _updateMarkers(List<Signalement> signalements) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final Set<Marker> newMarkers = {};

    final filtered = _showOnlyMyReports
        ? signalements.where((s) => s.userId == currentUserId).toList()
        : signalements;

    for (var s in filtered) {
      if (s.latitude != null && s.longitude != null) {
        newMarkers.add(
          Marker(
            markerId: MarkerId(s.id),
            position: LatLng(s.latitude!, s.longitude!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _getHueForStatus(s.status),
            ),
            infoWindow: InfoWindow(
              title: s.type,
              snippet: "${s.status} - ${s.description}",
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers; // Re-assigning entire set
      });
    }
  }

  double _getHueForStatus(String status) {
    switch (status) {
      case 'En cours':
        return BitmapDescriptor.hueBlue;
      case 'Résolu':
        return BitmapDescriptor.hueGreen;
      case 'En attente':
      default:
        return BitmapDescriptor.hueOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Carte des Signalements"),
        backgroundColor: const Color(0xFF386641),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('signalements').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Erreur: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting && _markers.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF386641)));
          }

          if (snapshot.hasData) {
            final signalements = snapshot.data!.docs.map((doc) {
              return Signalement.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
            }).toList();
            
            // On utilise WidgetsBinding pour éviter de déclencher setState pendant le build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateMarkers(signalements);
            });
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: _initialPosition,
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false, // On utilise notre bouton personnalisé
                onMapCreated: (controller) => _controller = controller,
              ),
              
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: "Tous les rapports",
                        selected: !_showOnlyMyReports,
                        onSelected: (v) {
                          if (v) setState(() {
                            _showOnlyMyReports = false;
                          });
                        },
                        icon: Icons.map,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: "Mes rapports",
                        selected: _showOnlyMyReports,
                        onSelected: (v) {
                          if (v) setState(() {
                            _showOnlyMyReports = true;
                          });
                        },
                        icon: Icons.person_pin_circle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "btn_loc",
            onPressed: _getCurrentLocation,
            backgroundColor: Colors.white,
            child: const Icon(Icons.my_location, color: Color(0xFF386641)),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "btn_refresh",
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${_markers.length} marqueurs affichés")),
              );
            },
            backgroundColor: const Color(0xFF386641),
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
    required IconData icon,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: const Color(0xFF386641),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.white : const Color(0xFF386641),
      ),
      backgroundColor: Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
