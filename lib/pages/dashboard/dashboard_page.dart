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
  Set<Marker> _companyMarkers = {};
  Set<Marker> _allMarkers = {};
  bool _mapLoading = false;
  List<CompanyModel> _allCompanies = [];

  // filtro de risco
  int? _filterRisk;
  // filtro de setor
  String? _filterSector;

  // pesquisa flutuante
  final _searchCtrl = TextEditingController();
  String _searchText = '';
  bool _showSuggestions = false;

  // Estilo do mapa: oculta labels/ícones de POIs do Google
  static const _mapStyle = '''[
    {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
    {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","elementType":" ","stylers":[{"visibility":"off"}]}
  ]''';

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
    _searchCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Empresas ──────────────────────────────────────────────────────────────

  void _subscribeCompanies() {
    _companiesSub =
        _companyService.streamCompanies().listen((companies) async {
      final newMarkers = <Marker>{};
      for (final c in companies) {
        final icon = await _buildMarkerIcon(c);
        newMarkers.add(Marker(
          markerId: MarkerId('company_${c.id}'),
          position: LatLng(c.lat, c.lng),
          icon: icon,
          onTap: () => _showCompanyDetails(c),
        ));
      }
      if (mounted) {
        setState(() {
          _allMarkers = newMarkers;
          _allCompanies = companies;
          _companyMarkers = _filterMarkers(newMarkers);
        });
      }
    });
  }

  Set<Marker> _filterMarkers(Set<Marker> source) {
    var companies = _allCompanies;
    if (_filterRisk != null) {
      companies = companies.where((c) => c.riskLevel == _filterRisk).toList();
    }
    if (_filterSector != null) {
      companies = companies.where((c) => c.sector == _filterSector).toList();
    }
    final ids = companies.map((c) => 'company_${c.id}').toSet();
    if (_filterRisk == null && _filterSector == null) return source;
    return source.where((m) => ids.contains(m.markerId.value)).toSet();
  }

  void _setRiskFilter(int? risk) {
    setState(() {
      _filterRisk = _filterRisk == risk ? null : risk;
      _companyMarkers = _filterMarkers(_allMarkers);
    });
  }

  void _setSectorFilter(String? sector) {
    setState(() {
      _filterSector = _filterSector == sector ? null : sector;
      _companyMarkers = _filterMarkers(_allMarkers);
    });
  }

  List<CompanyModel> _searchResults() {
    if (_searchText.isEmpty) return [];
    final q = _searchText.toLowerCase();
    // dígitos puros digitados (para busca numérica na dívida)
    final qDigits = q.replaceAll(RegExp(r'[^\d]'), '');
    final source = _allCompanies
        .where((c) =>
            (_filterRisk == null || c.riskLevel == _filterRisk) &&
            (_filterSector == null || c.sector == _filterSector))
        .toList();
    return source
        .where((c) {
          if (c.name.toLowerCase().contains(q)) return true;
          if (c.cnpj.contains(q) || _formatCnpj(c.cnpj).contains(q)) return true;
          // busca pelo valor da dívida: compara string numérica e formatada
          final debtFormatted = _formatCurrency(c.debtValue).toLowerCase();
          if (debtFormatted.contains(q)) return true;
          if (qDigits.isNotEmpty &&
              c.debtValue.toStringAsFixed(0).contains(qDigits)) return true;
          return false;
        })
        .take(6)
        .toList();
  }

  Future<void> _goToCompany(CompanyModel c) async {
    _searchCtrl.clear();
    setState(() {
      _searchText = '';
      _showSuggestions = false;
    });
    FocusScope.of(context).unfocus();
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(c.lat, c.lng), zoom: 16),
      ),
    );
    if (mounted) _showCompanyDetails(c);
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

  Future<BitmapDescriptor> _buildMarkerIcon(CompanyModel company) async {
    final color = _riskColor(company.riskLevel);
    final name = company.name;
    final subLabel =
        '${company.riskLabel}  \u2022  Score ${company.score.toStringAsFixed(0)}';

    const double px = 2.5;
    const double fontSize = 14 * px;
    const double subFontSize = 12 * px;
    const double hPad = 13 * px;
    const double vPad = 8 * px;
    const double lineGap = 4 * px;
    const double pointerH = 9 * px;
    const double cornerR = 8 * px;
    const double maxW = 200 * px;
    const double minInner = 70 * px;

    final namePainter = TextPainter(
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

    final subPainter = TextPainter(
      text: TextSpan(
        text: subLabel,
        style: TextStyle(
          fontSize: subFontSize,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxW - hPad * 2);

    final innerW = [namePainter.width, subPainter.width, minInner]
        .reduce((a, b) => a > b ? a : b)
        .clamp(minInner, maxW - hPad * 2);
    final w = innerW + hPad * 2;
    final textH =
        vPad + namePainter.height + lineGap + subPainter.height + vPad;
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
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, textH),
        const Radius.circular(cornerR),
      ),
      Paint()..color = color,
    );

    // faixa escura na parte do sub-label
    final subStripH = subPainter.height + vPad;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, textH - subStripH, w, subStripH),
        bottomLeft: const Radius.circular(cornerR),
        bottomRight: const Radius.circular(cornerR),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // pointer
    canvas.drawPath(
      Path()
        ..moveTo(w / 2 - 7 * px, textH)
        ..lineTo(w / 2 + 7 * px, textH)
        ..lineTo(w / 2, totalH)
        ..close(),
      Paint()..color = color,
    );

    // textos
    namePainter.paint(canvas, Offset(hPad, vPad));
    subPainter.paint(canvas, Offset(hPad, vPad + namePainter.height + lineGap));

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.ceil() + 4, totalH.ceil() + 4);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(
      bytes!.buffer.asUint8List(),
      size: Size(w / px, totalH / px),
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
                      if (c.cnpj.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatCnpj(c.cnpj),
                          style: const TextStyle(
                              color: Color(0xFFAAAAAA),
                              fontSize: 12,
                              letterSpacing: 0.4),
                        ),
                      ],
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
            if (c.cnpj.isNotEmpty) ...[
              _detailRow(Icons.badge_outlined, 'CNPJ', _formatCnpj(c.cnpj)),
              const SizedBox(height: 10),
            ],
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

  String _formatCnpj(String digits) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    if (d.length != 14) return digits;
    return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
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
      if (mounted) setState(() {});
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

  void _showSectorSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                const Text(
                  'Filtrar por Setor',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // chip "Todos"
                    _sectorChipSheet(
                      label: 'Todos',
                      selected: _filterSector == null,
                      onTap: () {
                        _setSectorFilter(null);
                        Navigator.pop(ctx);
                      },
                    ),
                    ...kSectors.map((s) => _sectorChipSheet(
                          label: s,
                          selected: _filterSector == s,
                          onTap: () {
                            _setSectorFilter(s);
                            Navigator.pop(ctx);
                          },
                        )),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _sectorChipSheet({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? appPrimary
              : appPrimary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? appPrimary : appPrimary.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            color: selected ? Colors.white : appPrimary,
          ),
        ),
      ),
    );
  }

  Widget _riskChip({
    required String label,
    required int? value,
    Color? color,
  }) {
    final selected = _filterRisk == value;
    final chipColor = color ?? appPrimary;
    return GestureDetector(
      onTap: () => _setRiskFilter(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? chipColor
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor : Colors.white,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : chipColor,
          ),
        ),
      ),
    );
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
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            style: _mapStyle,
            onMapCreated: (c) {
              if (!_mapController.isCompleted) _mapController.complete(c);
              // zoom animado para a localização assim que o mapa estiver pronto
              if (_locationGranted == true) _goToCurrentPosition();
            },
          ),
          // ── Barra de pesquisa flutuante ─────────────────────────────
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // campo de busca
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.93),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() {
                      _searchText = v.toLowerCase();
                      _showSuggestions = v.isNotEmpty;
                    }),
                    onTap: () {
                      if (_searchText.isNotEmpty) {
                        setState(() => _showSuggestions = true);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar empresa ou CNPJ…',
                      hintStyle: const TextStyle(
                          color: Color(0xFFAAAAAA), fontSize: 14),
                      prefixIcon: const Icon(Icons.search,
                          color: appPrimary, size: 22),
                      suffixIcon: _searchText.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.grey, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _searchText = '';
                                  _showSuggestions = false;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 13, horizontal: 4),
                    ),
                  ),
                ),

                // sugestões
                if (_showSuggestions)
                  Builder(builder: (context) {
                    final results = _searchResults();
                    if (results.isEmpty) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: Color(0xFFEEEEEE)),
                        itemBuilder: (context, i) {
                          final c = results[i];
                          final color = _riskColor(c.riskLevel);
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _goToCompany(c),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color:
                                          color.withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                          color: color.withValues(
                                              alpha: 0.3)),
                                    ),
                                    child: Icon(Icons.business_rounded,
                                        color: color, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (c.cnpj.isNotEmpty)
                                          Text(
                                            _formatCnpj(c.cnpj),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF888888)),
                                          ),
                                        Text(
                                          _formatCurrency(c.debtValue),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFFAAAAAA)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: color, width: 0.8),
                                    ),
                                    child: Text(
                                      c.riskLabel,
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),

          // ── Chips de filtro de risco + botão setor ──────────────────
          Positioned(
            bottom: 24,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botão de filtro por setor
                GestureDetector(
                  onTap: _showSectorSheet,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _filterSector != null
                          ? appPrimary
                          : Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _filterSector != null
                            ? appPrimary
                            : Colors.white,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 14,
                          color: _filterSector != null
                              ? Colors.white
                              : appPrimary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _filterSector ?? 'Setor',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _filterSector != null
                                ? Colors.white
                                : appPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.expand_more,
                          size: 14,
                          color: _filterSector != null
                              ? Colors.white
                              : appPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Chips de risco
                _riskChip(label: 'Todos', value: null),
                const SizedBox(height: 6),
                _riskChip(
                    label: 'Baixo',
                    value: 1,
                    color: const Color(0xFF4CAF50)),
                const SizedBox(height: 6),
                _riskChip(
                    label: 'Médio',
                    value: 2,
                    color: const Color(0xFFFF9800)),
                const SizedBox(height: 6),
                _riskChip(
                    label: 'Alto',
                    value: 3,
                    color: const Color(0xFFF44336)),
              ],
            ),
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
