import 'package:divida_aqui/core/app_colors.dart';
import 'package:divida_aqui/core/company_model.dart';
import 'package:divida_aqui/core/company_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddCompanyPage extends StatefulWidget {
  final CompanyModel? company;

  const AddCompanyPage({super.key, this.company});

  @override
  State<AddCompanyPage> createState() => _AddCompanyPageState();
}

class _AddCompanyPageState extends State<AddCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = CompanyService();
  bool _saving = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _sectorCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _scoreCtrl;
  late final TextEditingController _debtCtrl;
  int _riskLevel = 1;

  bool get _isEditing => widget.company != null;

  @override
  void initState() {
    super.initState();
    final c = widget.company;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _sectorCtrl = TextEditingController(text: c?.sector ?? '');
    _latCtrl = TextEditingController(text: c?.lat.toString() ?? '');
    _lngCtrl = TextEditingController(text: c?.lng.toString() ?? '');
    _scoreCtrl = TextEditingController(text: c?.score.toString() ?? '');
    _debtCtrl = TextEditingController(text: c?.debtValue.toString() ?? '');
    _riskLevel = c?.riskLevel ?? 1;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sectorCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _scoreCtrl.dispose();
    _debtCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final lat = double.parse(_latCtrl.text.replaceAll(',', '.'));
      final lng = double.parse(_lngCtrl.text.replaceAll(',', '.'));
      final score = double.parse(_scoreCtrl.text.replaceAll(',', '.'));
      final debt = double.parse(_debtCtrl.text.replaceAll(',', '.'));

      if (_isEditing) {
        await _service.updateCompany(
          widget.company!.copyWith(
            name: _nameCtrl.text.trim(),
            sector: _sectorCtrl.text.trim(),
            lat: lat,
            lng: lng,
            riskLevel: _riskLevel,
            score: score,
            debtValue: debt,
          ),
        );
      } else {
        await _service.addCompany(
          CompanyModel(
            id: '',
            name: _nameCtrl.text.trim(),
            sector: _sectorCtrl.text.trim(),
            lat: lat,
            lng: lng,
            riskLevel: _riskLevel,
            score: score,
            debtValue: debt,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar empresa. Tente novamente.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: appPrimary,
        foregroundColor: Colors.white,
        title: Text(
          _isEditing ? 'Editar Empresa' : 'Nova Empresa',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSection('Dados da empresa', [
              _buildField(
                controller: _nameCtrl,
                label: 'Nome da empresa',
                icon: Icons.business,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _sectorCtrl,
                label: 'Setor',
                icon: Icons.category_outlined,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o setor' : null,
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Localização', [
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _latCtrl,
                      label: 'Latitude',
                      icon: Icons.location_on_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^-?\d*[,.]?\d*')),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Obrigatório';
                        final d = double.tryParse(v.replaceAll(',', '.'));
                        if (d == null) return 'Inválido';
                        if (d < -90 || d > 90) return '-90 a 90';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      controller: _lngCtrl,
                      label: 'Longitude',
                      icon: Icons.location_on_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^-?\d*[,.]?\d*')),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Obrigatório';
                        final d = double.tryParse(v.replaceAll(',', '.'));
                        if (d == null) return 'Inválido';
                        if (d < -180 || d > 180) return '-180 a 180';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Avaliação', [
              _buildRiskSelector(),
              const SizedBox(height: 14),
              _buildField(
                controller: _scoreCtrl,
                label: 'Score',
                icon: Icons.bar_chart,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*[,.]?\d*')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o score';
                  if (double.tryParse(v.replaceAll(',', '.')) == null) {
                    return 'Valor inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _debtCtrl,
                label: 'Valor da dívida (R\$)',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*[,.]?\d*')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Informe o valor da dívida';
                  }
                  if (double.tryParse(v.replaceAll(',', '.')) == null) {
                    return 'Valor inválido';
                  }
                  return null;
                },
              ),
            ]),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        _isEditing ? 'Salvar alterações' : 'Cadastrar empresa',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: appPrimary, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: appPrimary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _buildRiskSelector() {
    final risks = [
      (1, 'Baixo', const Color(0xFF4CAF50)),
      (2, 'Médio', const Color(0xFFFF9800)),
      (3, 'Alto', const Color(0xFFF44336)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nível de risco',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          children: risks.map((r) {
            final (level, label, color) = r;
            final selected = _riskLevel == level;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => setState(() => _riskLevel = level),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? color
                          : color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: color,
                          width: selected ? 2 : 1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
