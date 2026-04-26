import 'dart:async';
import 'dart:ui' as ui;

import 'package:divida_aqui/core/app_colors.dart';
import 'package:divida_aqui/core/auth_service.dart';
import 'package:divida_aqui/core/company_model.dart';
import 'package:divida_aqui/core/company_service.dart';
import 'package:divida_aqui/core/user_model.dart';
import 'package:divida_aqui/pages/admin/admin_companies_page.dart';
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
  final _companyService = CompanyService();
  UserModel? _currentUser;

  // --- mapa ---
  final Completer<GoogleMapController> _mapController = Completer();
  static const _initialPosition = CameraPosition(
    target: LatLng(-14.235, -51.9253),
    zoom: 4,
  );
  Marker? _myMarker;
  Set<Marker> _companyMarkers = {};
  bool _mapLoading = false;

  // permissão: null = verificando, true = concedida, false = negada
  bool? _locationGranted;
  bool _waitingSettings = false;

  StreamSubscription<List<CompanyModel>>? _companiesSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
    _checkPermission();
    _subscribeCompanies();
  }

  @override
  void dispose() {
    _companiesSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Empresas ──────────────────────────────────────────────────────────────

  void _subscribeCompanies() {
    _companiesSub =
        _companyService.streamCompanies().listen((companies) async {
      final newMarkers = <Marker>{};
      for (final c in companies) {
        final icon = await _buildMarkerIcon(c.name, c.riskLevel);
        newMarkers.add(Marker(
          markerId: MarkerId('company_${c.id}'),
          position: LatLng(c.lat, c.lng),
          icon: icon,
          onTap: () => _showCompanyDetails(c),
        ));
      }
      if (mounted) setState(() => _companyMarkers = newMarkers);
    });
  }

  Color _riskColor(int level) {
    switch (level) {
      case 1:
        return const Color(0xFF4CAF50);
      case 2:
        return const Color(0xFFFF9800);
      case 3:
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }

  Future<BitmapDescriptor> _buildMarkerIcon(String name, int riskLevel) async {
    final color = _riskColor(riskLevel);
    const double pixelRatio = 2.5;
    const double fontSize = 12 * pixelRatio;
    const double hPad = 8 * pixelRatio;
    const double vPad = 5 * pixelRatio;
    const double pointerH = 8 * pixelRatio;
    const double cornerR = 6 * pixelRatio;
    const double minW = 60 * pixelRatio;
    const double maxW = 160 * pixelRatio;

    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxW - hPad * 2);

    final w = (textPainter.width + hPad * 2).clamp(minW, maxW);
    final textH = textPainter.height + vPad * 2;
    final totalH = textH + pointerH;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, w, textH),
        const Radius.circular(cornerR),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, textH),
        const Radius.circular(cornerR),
      ),
      Paint()..color = color,
    );

    // pointer triangle
    canvas.drawPath(
      Path()
        ..moveTo(w / 2 - 6 * pixelRatio, textH)
        ..lineTo(w / 2 + 6 * pixelRatio, textH)
        ..lineTo(w / 2, totalH)
        ..close(),
      Paint()..color = color,
    );

    // text label
    textPainter.paint(canvas, Offset(hPad, vPad));

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.ceil() + 4, totalH.ceil() + 4);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(
      bytes!.buffer.asUint8List(),
      size: Size(w / pixelRatio, totalH / pixelRatio),
    );
  }

  void _showCompanyDetails(CompanyModel c) {
    final color = _riskColor(c.riskLevel);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(Icons.business, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        c.sector,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color, width: 1),
                  ),
                  child: Text(
                    c.riskLabel,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            _detailRow(Icons.bar_chart, 'Score', c.score.toStringAsFixed(2)),
            const SizedBox(height: 10),
            _detailRow(Icons.attach_money, 'Valor da dívida',
                _formatCurrency(c.debtValue)),
            const SizedBox(height: 10),
            _detailRow(
              Icons.location_on_outlined,
              'Localização',
              '${c.lat.toStringAsFixed(5)}, ${c.lng.toStringAsFixed(5)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: appPrimary, size: 18),
        const SizedBox(width: 10),
        Text('$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
      count++;
    }
    return 'R\$ ${buffer.toString().split('').reversed.join()},$decPart';
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
          _myMarker = Marker(
            markerId: const MarkerId('current'),
            position: latLng,
            infoWindow: const InfoWindow(title: 'Você está aqui'),
          );
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
      // cancela o stream antes do signOut para evitar permission-denied
      await _companiesSub?.cancel();
      _companiesSub = null;
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
          if (_currentUser?.role == 0)
            IconButton(
              icon: const Icon(Icons.business_outlined),
              tooltip: 'Empresas',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const AdminCompaniesPage()),
                );
              },
            ),
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
            markers: {
              ..._companyMarkers,
              if (_myMarker != null) _myMarker!,
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (c) {
              if (!_mapController.isCompleted) _mapController.complete(c);
              // zoom animado para a localização assim que o mapa estiver pronto
              if (_locationGranted == true) _goToCurrentPosition();
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
