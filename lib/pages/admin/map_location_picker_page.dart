import 'package:divida_aqui/core/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapLocationPickerPage extends StatefulWidget {
  /// Posição inicial opcional (coordenadas já preenchidas no formulário).
  final LatLng? initial;

  const MapLocationPickerPage({super.key, this.initial});

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage> {
  GoogleMapController? _mapCtrl;
  LatLng? _picked;

  static const LatLng _defaultCenter = LatLng(-14.235, -51.925); // Brasil

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) return;

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    final target = LatLng(pos.latitude, pos.longitude);
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: appPrimary,
        foregroundColor: Colors.white,
        title: const Text(
          'Selecionar localização',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_picked != null)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, _picked),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'Confirmar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initial ?? _defaultCenter,
              zoom: widget.initial != null ? 14 : 4,
            ),
            onMapCreated: (c) {
              _mapCtrl = c;
              if (widget.initial == null) _goToCurrentLocation();
            },
            onTap: (latLng) => setState(() => _picked = latLng),
            markers: _picked != null
                ? {
                    Marker(
                      markerId: const MarkerId('picked'),
                      position: _picked!,
                    ),
                  }
                : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Instrução
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app_outlined,
                      size: 18, color: appPrimary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Toque no mapa para marcar a localização da empresa',
                      style: TextStyle(fontSize: 13, color: Color(0xFF444444)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Coordenadas selecionadas
          if (_picked != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: appPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Lat: ${_picked!.latitude.toStringAsFixed(6)}'
                      '   Lng: ${_picked!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF222222),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

          // Botão minha localização
          Positioned(
            bottom: 36,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'my_location_picker',
              backgroundColor: Colors.white,
              foregroundColor: appPrimary,
              tooltip: 'Minha localização',
              onPressed: _goToCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Botão confirmar (bottom)
          if (_picked != null)
            Positioned(
              bottom: 36,
              left: 16,
              right: 72,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _picked),
                style: ElevatedButton.styleFrom(
                  backgroundColor: appPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check),
                label: const Text(
                  'Confirmar localização',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
