import 'package:divida_aqui/core/app_colors.dart';
import 'package:divida_aqui/core/company_model.dart';
import 'package:divida_aqui/core/company_service.dart';
import 'package:divida_aqui/pages/admin/map_location_picker_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  late final TextEditingController _cnpjCtrl;
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
    _cnpjCtrl = TextEditingController(
        text: c != null ? _CnpjInputFormatter.applyMask(c.cnpj) : '');
    _sectorCtrl = TextEditingController(text: c?.sector ?? '');
    _latCtrl = TextEditingController(text: c?.lat.toString() ?? '');
    _lngCtrl = TextEditingController(text: c?.lng.toString() ?? '');
    _scoreCtrl = TextEditingController(text: c?.score.toString() ?? '');
    _debtCtrl = TextEditingController(
        text: c != null ? _formatCurrencyValue(c.debtValue) : '');
    _riskLevel = c?.riskLevel ?? 1;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cnpjCtrl.dispose();
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
      final debt = double.parse(
        _debtCtrl.text
            .replaceAll('R\$ ', '')
            .replaceAll('.', '')
            .replaceAll(',', '.'),
      );
      final cnpj = _cnpjCtrl.text.replaceAll(RegExp(r'[^\d]'), '');

      if (_isEditing) {
        await _service.updateCompany(
          widget.company!.copyWith(
            name: _nameCtrl.text.trim(),
            cnpj: cnpj,
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
            cnpj: cnpj,
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
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            // ── Dados da empresa ───────────────────────────────────────────
            _sectionLabel('Dados da empresa'),
            const SizedBox(height: 10),
            _buildCard([
              _buildField(
                controller: _nameCtrl,
                label: 'Nome da empresa',
                hint: 'Ex: Empresa ABC Ltda',
                icon: Icons.business_outlined,
                autovalidate: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Informe o nome da empresa';
                  }
                  if (v.trim().length < 2) {
                    return 'Nome muito curto (mín. 2 caracteres)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _cnpjCtrl,
                label: 'CNPJ',
                hint: '00.000.000/0000-00',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [_CnpjInputFormatter()],
                autovalidate: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Informe o CNPJ';
                  }
                  final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                  if (digits.length != 14) {
                    return 'CNPJ deve ter 14 dígitos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _sectorCtrl,
                label: 'Setor de atuação',
                hint: 'Ex: Tecnologia, Varejo, Saúde…',
                icon: Icons.category_outlined,
                autovalidate: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Informe o setor de atuação';
                  }
                  if (v.trim().length < 2) {
                    return 'Setor muito curto (mín. 2 caracteres)';
                  }
                  return null;
                },
              ),
            ]),

            const SizedBox(height: 24),

            // ── Localização ────────────────────────────────────────────────
            _sectionLabel('Localização'),
            const SizedBox(height: 10),
            _buildCard([
              // Botão de seleção no mapa
              OutlinedButton.icon(
                onPressed: _pickOnMap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: appPrimary,
                  side: const BorderSide(color: appPrimary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 0),
                ),
                icon: const Icon(Icons.map_outlined, size: 20),
                label: const Text(
                  'Selecionar no mapa',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ou insira manualmente',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF999999)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _latCtrl,
                      label: 'Latitude',
                      hint: '-23.55052',
                      icon: Icons.near_me_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^-?\d*[,.]?\d*')),
                      ],
                      autovalidate: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Obrigatório';
                        }
                        final d = double.tryParse(v.replaceAll(',', '.'));
                        if (d == null) return 'Valor inválido';
                        if (d < -90 || d > 90) return 'Entre -90 e 90';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      controller: _lngCtrl,
                      label: 'Longitude',
                      hint: '-46.63330',
                      icon: Icons.near_me_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^-?\d*[,.]?\d*')),
                      ],
                      autovalidate: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Obrigatório';
                        }
                        final d = double.tryParse(v.replaceAll(',', '.'));
                        if (d == null) return 'Valor inválido';
                        if (d < -180 || d > 180) return 'Entre -180 e 180';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ]),

            const SizedBox(height: 24),

            // ── Avaliação ──────────────────────────────────────────────────
            _sectionLabel('Avaliação de risco'),
            const SizedBox(height: 10),
            _buildCard([
              _buildRiskSelector(),
              const SizedBox(height: 16),
              _buildField(
                controller: _scoreCtrl,
                label: 'Score de crédito',
                hint: 'Ex: 750',
                icon: Icons.bar_chart_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*')),
                ],
                autovalidate: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Informe o score';
                  }
                  final d = double.tryParse(v.replaceAll(',', '.'));
                  if (d == null) return 'Valor inválido';
                  if (d < 0) return 'Score não pode ser negativo';
                  if (d > 1000) return 'Score máximo é 1000';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _debtCtrl,
                label: 'Valor da dívida',
                hint: 'R\$ 0,00',
                icon: Icons.attach_money_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [_CurrencyInputFormatter()],
                autovalidate: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty || v == 'R\$ 0,00') {
                    return 'Informe o valor da dívida';
                  }
                  return null;
                },
              ),
            ]),

            const SizedBox(height: 32),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appPrimary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: appPrimary.withValues(alpha: 0.4),
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

  // ── Helpers de layout ──────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool autovalidate = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          autovalidateMode: autovalidate
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          style: const TextStyle(fontSize: 14, color: Color(0xFF222222)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.grey, size: 20),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: appPrimary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickOnMap() async {
    LatLng? initial;
    final lat = double.tryParse(_latCtrl.text.replaceAll(',', '.'));
    final lng = double.tryParse(_lngCtrl.text.replaceAll(',', '.'));
    if (lat != null && lng != null) initial = LatLng(lat, lng);

    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPickerPage(initial: initial),
      ),
    );
    if (result != null) {
      _latCtrl.text = result.latitude.toStringAsFixed(6);
      _lngCtrl.text = result.longitude.toStringAsFixed(6);
    }
  }

  static String _formatCurrencyValue(double value) {
    final cents = (value * 100).round();
    return _CurrencyInputFormatter._format(cents);
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

class _CurrencyInputFormatter extends TextInputFormatter {
  static String _format(int cents) {
    if (cents == 0) return 'R\$ 0,00';
    final centsPart = (cents % 100).toString().padLeft(2, '0');
    final reais = cents ~/ 100;
    final reaisStr = _formatThousands(reais);
    return 'R\$ $reaisStr,$centsPart';
  }

  static String _formatThousands(int n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
    final cents = int.tryParse(digits) ?? 0;
    final formatted = _format(cents);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CnpjInputFormatter extends TextInputFormatter {
  // Aplica máscara 00.000.000/0000-00
  static String applyMask(String digits) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < d.length && i < 14; i++) {
      if (i == 2 || i == 5) buf.write('.');
      if (i == 8) buf.write('/');
      if (i == 12) buf.write('-');
      buf.write(d[i]);
    }
    return buf.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final formatted = applyMask(digits);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
