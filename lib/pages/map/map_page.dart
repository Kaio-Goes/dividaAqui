import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:divida_aqui/core/app_colors.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _controller = Completer();

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-14.235, -51.9253), // Centro do Brasil
    zoom: 4,
  );

  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  LatLng? _currentCameraCenter;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _goToCurrentPosition();
  }

  Future<void> _goToCurrentPosition() async {
    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      await _animateCamera(latLng);

      setState(() {
        _markers.clear();
        _markers.add(Marker(
          markerId: const MarkerId('current_position'),
          position: latLng,
          infoWindow: const InfoWindow(title: 'Você está aqui'),
        ));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível obter sua localização.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _animateCamera(LatLng position) async {
    final controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 15.5),
      ),
    );
  }

  void _onCameraIdle() {
    if (_currentCameraCenter == null) return;
    setState(() {
      _circles
        ..clear()
        ..add(Circle(
          circleId: const CircleId('center_circle'),
          center: _currentCameraCenter!,
          radius: 1000,
          strokeColor: appPrimary,
          strokeWidth: 2,
          fillColor: appPrimary.withValues(alpha: 0.08),
        ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: appPrimary,
        foregroundColor: Colors.white,
        title: const Text(
          'Mapa',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            zoomControlsEnabled: false,
            markers: _markers,
            circles: _circles,
            onMapCreated: (controller) => _controller.complete(controller),
            onCameraIdle: _onCameraIdle,
            onCameraMove: (position) {
              if (_currentCameraCenter == position.target) return;
              setState(() => _currentCameraCenter = position.target);
            },
          ),

          // Loading overlay
          if (_isLoading)
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(50),
                ),
                padding: const EdgeInsets.all(16),
                child: const CircularProgressIndicator(color: appPrimary),
              ),
            ),

          // Botão GPS
          Positioned(
            bottom: 24,
            right: 16,
            child: GestureDetector(
              onTap: _goToCurrentPosition,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.gps_fixed, color: appPrimary, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
