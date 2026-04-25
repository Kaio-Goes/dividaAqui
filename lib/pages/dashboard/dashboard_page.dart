import 'dart:async';
import 'package:divida_aqui/core/app_colors.dart';
import 'package:divida_aqui/core/auth_service.dart';
import 'package:divida_aqui/core/user_model.dart';
import 'package:divida_aqui/pages/admin/admin_users_page.dart';
import 'package:divida_aqui/pages/auth/login_page.dart';
import 'package:divida_aqui/pages/profile/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  final _authService = AuthService();
  UserModel? _currentUser;

  // --- mapa ---
  final Completer<GoogleMapController> _mapController = Completer();
  static const _initialPosition = CameraPosition(
    target: LatLng(-14.235, -51.9253),
    zoom: 4,
  );
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  LatLng? _cameraCenterLatLng;
  bool _mapLoading = false;

  // permissão: null = verificando, true = concedida, false = negada
  bool? _locationGranted;
  bool _waitingSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingSettings) {
      _waitingSettings = false;
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _locationGranted = true);
      _goToCurrentPosition();
    } else {
      // solicita direto, sem mostrar card
      await _requestPermission();
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _locationGranted = true);
      _goToCurrentPosition();
    } else if (status.isPermanentlyDenied) {
      // só abre Settings se realmente bloqueado permanentemente
      _waitingSettings = true;
      await openAppSettings();
    }
    // se apenas 'denied' (usuário recusou o diálogo), mostra mapa sem localização
    // para não travar o usuário em loop de settings
    else {
      setState(() => _locationGranted = true);
    }
  }

  Future<void> _goToCurrentPosition() async {
    if (_mapLoading) return;
    setState(() => _mapLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      if (!_mapController.isCompleted) return;
      final controller = await _mapController.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 15.5),
        ),
      );
      if (mounted) {
        setState(() {
          _markers
            ..clear()
            ..add(Marker(
              markerId: const MarkerId('current'),
              position: latLng,
              infoWindow: const InfoWindow(title: 'Você está aqui'),
            ));
        });
      }
    } catch (_) {
      // emulador sem GPS — apenas mantém posição inicial
    } finally {
      if (mounted) setState(() => _mapLoading = false);
    }
  }

  Future<void> _loadUser() async {
    final user = await _authService.fetchCurrentUserProfile();
    if (mounted) setState(() => _currentUser = user);
  }

  void _navigateToProfile() {
    if (_currentUser == null) return;
    if (_currentUser!.role == 0) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminUsersPage()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sair da conta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Deseja realmente sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: appPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: appPrimary,
        foregroundColor: Colors.white,
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Perfil',
            onPressed: _navigateToProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Enquanto verifica/solicita permissão
    if (_locationGranted != true) {
      return const Center(child: CircularProgressIndicator(color: appPrimary));
    }

    // Permissão concedida → mapa em tela cheia
      return Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            zoomControlsEnabled: false,
            markers: _markers,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (c) {
              if (!_mapController.isCompleted) _mapController.complete(c);
            },
            onCameraIdle: () {
              if (_cameraCenterLatLng == null) return;
              setState(() {
                _circles
                  ..clear()
                  ..add(Circle(
                    circleId: const CircleId('center'),
                    center: _cameraCenterLatLng!,
                    radius: 1000,
                    strokeColor: appPrimary,
                    strokeWidth: 2,
                    fillColor: appPrimary.withValues(alpha: 0.08),
                  ));
              });
            },
            onCameraMove: (pos) {
              if (_cameraCenterLatLng != pos.target) {
                setState(() => _cameraCenterLatLng = pos.target);
              }
            },
          ),
          if (_mapLoading)
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(50),
                ),
                padding: const EdgeInsets.all(16),
                child:
                    const CircularProgressIndicator(color: appPrimary),
              ),
            ),
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
                child:
                    const Icon(Icons.gps_fixed, color: appPrimary, size: 24),
              ),
            ),
          ),
        ],
      );
  }
}
