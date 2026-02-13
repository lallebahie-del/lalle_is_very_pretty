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
  final Set<Marker> _markers = {};
  List<Signalement> _allSignalements = [];
  bool _showOnlyMyReports = false;
  bool _loading = true;
  
  // Default position (e.g., city center) if GPS fails
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(33.5731, -7.5898), // Casablanca example
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _loadSignalements();
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
      // Ignore location errors, just stay on default
    }
  }

  Future<void> _loadSignalements() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('signalements').get();
      final List<Signalement> signalements = snapshot.docs.map((doc) {
        return Signalement.fromFirestore(doc.id, doc.data());
      }).toList();

      if (mounted) {
        setState(() {
          _allSignalements = signalements;
          _updateMarkers();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateMarkers() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final Set<Marker> newMarkers = {};

    final filtered = _showOnlyMyReports
        ? _allSignalements.where((s) => s.userId == currentUserId).toList()
        : _allSignalements;

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

    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });
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
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (controller) => _controller = controller,
          ),
          
          // 🔘 Filter Toggle Overlay
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
                        _updateMarkers();
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
                        _updateMarkers();
                      });
                    },
                    icon: Icons.person_pin_circle,
                  ),
                ],
              ),
            ),
          ),

          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
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
