import 'package:divida_aqui/core/app_colors.dart';
import 'package:divida_aqui/core/company_model.dart';
import 'package:divida_aqui/core/company_service.dart';
import 'package:divida_aqui/pages/admin/add_company_page.dart';
import 'package:flutter/material.dart';

class AdminCompaniesPage extends StatefulWidget {
  const AdminCompaniesPage({super.key});

  @override
  State<AdminCompaniesPage> createState() => _AdminCompaniesPageState();
}

class _AdminCompaniesPageState extends State<AdminCompaniesPage> {
  final _service = CompanyService();
  final _searchCtrl = TextEditingController();
  int? _filterRisk;
  String? _filterSector;
  String _searchText = '';

  // Lista mantida em estado local — stream atualiza sem reconstruir o TextField
  List<CompanyModel> _allCompanies = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _searchText = _searchCtrl.text.toLowerCase()));
    _service.streamCompanies().listen((data) {
      if (mounted) setState(() => _allCompanies = data);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CompanyModel> _applyFilter(List<CompanyModel> all) {
    return all.where((c) {
      final matchRisk = _filterRisk == null || c.riskLevel == _filterRisk;
      final matchSector =
          _filterSector == null || c.sector == _filterSector;
      final q = _searchText;
      final matchSearch = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.sector.toLowerCase().contains(q) ||
          c.cnpj.contains(q) ||
          c.riskLabel.toLowerCase().contains(q) ||
          c.score.toString().contains(q) ||
          c.debtValue.toString().contains(q) ||
          c.lat.toString().contains(q) ||
          c.lng.toString().contains(q);
      return matchRisk && matchSector && matchSearch;
    }).toList();
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

  Future<void> _delete(CompanyModel company) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir empresa',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Deseja excluir "${company.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deleteCompany(company.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Empresa excluída.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openForm({CompanyModel? company}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddCompanyPage(company: company)),
    );
  }

  String _formatCurrency(double value) {
    final cents = (value * 100).round();
    final centsPart = (cents % 100).toString().padLeft(2, '0');
    final reais = cents ~/ 100;
    final reaisStr = reais.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'R\$ $reaisStr,$centsPart';
  }

  String _formatCnpj(String digits) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    if (d.length != 14) return digits;
    return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
  }

  Widget _metric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888888))),
                  Text(
                    value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required int? value,
    Color? color,
  }) {
    final selected = _filterRisk == value;
    final chipColor = color ?? appPrimary;
    return GestureDetector(
      onTap: () => setState(() => _filterRisk = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? chipColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor : const Color(0xFFDDDDDD),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            color: selected ? chipColor : const Color(0xFF777777),
          ),
        ),
      ),
    );
  }

  Widget _sectorChip({
    required String label,
    required String? value,
  }) {
    final selected = _filterSector == value;
    return GestureDetector(
      onTap: () => setState(() =>
          _filterSector = (_filterSector == value) ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? appPrimary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? appPrimary : const Color(0xFFDDDDDD),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.normal,
            color: selected ? appPrimary : const Color(0xFF777777),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companies = _applyFilter(_allCompanies);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: appPrimary,
        foregroundColor: Colors.white,
        title: const Text('Empresas',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: appPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova empresa'),
      ),
      body: Column(
        children: [
          // ── Barra de pesquisa + filtros — fora de qualquer StreamBuilder ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Pesquisar por nome, CNPJ, setor, score…',
                    hintStyle: const TextStyle(
                        color: Color(0xFFAAAAAA), fontSize: 14),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.grey, size: 20),
                    suffixIcon: _searchText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.grey, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    filled: true,
                    fillColor: const Color(0xFFF4F6F8),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: appPrimary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Linha de risco
                Row(
                  children: [
                    _filterChip(label: 'Todos', value: null),
                    const SizedBox(width: 8),
                    _filterChip(
                        label: 'Baixo',
                        value: 1,
                        color: const Color(0xFF4CAF50)),
                    const SizedBox(width: 8),
                    _filterChip(
                        label: 'Médio',
                        value: 2,
                        color: const Color(0xFFFF9800)),
                    const SizedBox(width: 8),
                    _filterChip(
                        label: 'Alto',
                        value: 3,
                        color: const Color(0xFFF44336)),
                    const Spacer(),
                    Text(
                      '${companies.length} result${companies.length == 1 ? 'ado' : 'ados'}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF999999)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Linha de setor (scroll horizontal)
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _sectorChip(label: 'Todos', value: null),
                      ...kSectors.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _sectorChip(label: s, value: s),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Lista ────────────────────────────────────────────────────────
          Expanded(
            child: _allCompanies.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: appPrimary))
                : companies.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma empresa encontrada.',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: companies.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final c = companies[index];
                          final color = _riskColor(c.riskLevel);
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFFE4E8EE),
                                  width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // ── Cabeçalho ──────────────────
                                  Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: color.withValues(
                                              alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: color.withValues(
                                                  alpha: 0.3),
                                              width: 1),
                                        ),
                                        child: Icon(
                                            Icons.business_rounded,
                                            color: color,
                                            size: 22),
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
                                                fontWeight:
                                                    FontWeight.w700,
                                                fontSize: 15,
                                                color: Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              c.sector,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      Color(0xFF888888)),
                                            ),
                                            if (c.cnpj.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatCnpj(c.cnpj),
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Color(0xFFAAAAAA),
                                                    letterSpacing: 0.3),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color.withValues(
                                              alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: color, width: 1),
                                        ),
                                        child: Text(
                                          c.riskLabel,
                                          style: TextStyle(
                                              color: color,
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert,
                                            color: Colors.grey, size: 20),
                                        onSelected: (value) {
                                          if (value == 'edit')
                                            _openForm(company: c);
                                          if (value == 'delete')
                                            _delete(c);
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Editar')),
                                          PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Excluir',
                                                  style: TextStyle(
                                                      color:
                                                          Colors.red))),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),
                                  const Divider(
                                      height: 1,
                                      color: Color(0xFFEEEEEE)),
                                  const SizedBox(height: 12),

                                  // ── Métricas ────────────────────
                                  Row(
                                    children: [
                                      _metric(
                                        icon: Icons.bar_chart_rounded,
                                        label: 'Score',
                                        value: c.score.toStringAsFixed(0),
                                        color: appPrimary,
                                      ),
                                      const SizedBox(width: 8),
                                      _metric(
                                        icon: Icons.attach_money_rounded,
                                        label: 'Dívida',
                                        value:
                                            _formatCurrency(c.debtValue),
                                        color: const Color(0xFFF44336),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  // ── Coordenadas ─────────────────
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F6F8),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFE4E8EE)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                            Icons.location_on_outlined,
                                            size: 14,
                                            color: Color(0xFF888888)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Lat: ${c.lat.toStringAsFixed(5)}   '
                                          'Lng: ${c.lng.toStringAsFixed(5)}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF666666),
                                              fontFamily: 'monospace'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
