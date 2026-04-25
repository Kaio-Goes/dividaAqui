import 'package:flutter/material.dart';
import 'package:divida_aqui/core/app_colors.dart';
import 'package:divida_aqui/pages/map/map_page.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationPermissionPage extends StatefulWidget {
  const LocationPermissionPage({super.key});

  @override
  State<LocationPermissionPage> createState() =>
      _LocationPermissionPageState();
}

class _LocationPermissionPageState extends State<LocationPermissionPage>
    with WidgetsBindingObserver {
  bool _requesting = false;
  bool _waitingForSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Usuário voltou das configurações do sistema (iOS/Android)
    if (state == AppLifecycleState.resumed && _waitingForSettings) {
      _waitingForSettings = false;
      _checkAfterSettings();
    }
  }

  Future<void> _checkAfterSettings() async {
    final status = await Permission.locationWhenInUse.status;
    if (!mounted) return;
    if (status.isGranted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MapPage()),
      );
    }
    // se ainda negada, apenas permanece na tela
  }

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);

    final status = await Permission.locationWhenInUse.request();

    if (!mounted) return;

    setState(() => _requesting = false);

    if (status.isGranted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MapPage()),
      );
    } else if (status.isPermanentlyDenied) {
      _waitingForSettings = true;
      await openAppSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Permissão de localização negada. O mapa não pode ser exibido.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: appPrimary,
        foregroundColor: Colors.white,
        title: const Text(
          'Permissão de Localização',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: appPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_outlined,
                size: 52,
                color: appPrimary,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Acesso à Localização',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Para exibir o mapa e sua posição atual, o Dívida Aqui precisa acessar sua localização enquanto o app está em uso.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF666666),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: appPrimary, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sua localização é usada apenas para centralizar o mapa e nunca é armazenada.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _requesting ? null : _requestPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _requesting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Permitir acesso à localização',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Agora não',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
