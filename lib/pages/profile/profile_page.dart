import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:divida_aqui/core/app_colors.dart';
import 'package:divida_aqui/core/auth_service.dart';
import 'package:divida_aqui/core/user_model.dart';
import 'package:divida_aqui/components/auth_input_field.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _birthController = TextEditingController();

  UserModel? _user;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = await _authService.fetchCurrentUserProfile();
    if (mounted) {
      setState(() {
        _user = user;
        _nameController.text = user?.name ?? '';
        _birthController.text = user?.birthDate ?? '';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    DateTime tempDate = DateTime(now.year - 18, now.month, now.day);

    if (_birthController.text.isNotEmpty) {
      final parts = _birthController.text.split('/');
      if (parts.length == 3) {
        tempDate = DateTime(
          int.tryParse(parts[2]) ?? tempDate.year,
          int.tryParse(parts[1]) ?? tempDate.month,
          int.tryParse(parts[0]) ?? tempDate.day,
        );
      }
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        height: 320,
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  CupertinoButton(
                    child: Text('Confirmar', style: TextStyle(color: appPrimary)),
                    onPressed: () {
                      _birthController.text =
                          '${tempDate.day.toString().padLeft(2, '0')}/${tempDate.month.toString().padLeft(2, '0')}/${tempDate.year}';
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: tempDate,
                minimumDate: DateTime(1900),
                maximumDate: DateTime(now.year - 10, now.month, now.day),
                onDateTimeChanged: (date) => tempDate = date,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_user == null) return;
    setState(() => _saving = true);
    try {
      await _authService.updateUserProfile(
        uid: _user!.uid,
        name: _nameController.text.trim(),
        birthDate: _birthController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar perfil. Tente novamente.'),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: appPrimary,
        foregroundColor: Colors.white,
        title: const Text(
          'Meu Perfil',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: appPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: appPrimary.withValues(alpha: 0.12),
                        child: const Icon(Icons.person, size: 48, color: appPrimary),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Nome
                    AuthInputField(
                      controller: _nameController,
                      label: 'Nome completo',
                      hintText: 'João da Silva',
                      prefixIcon: Icons.person_outline,
                      keyboardType: TextInputType.name,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Informe o nome.';
                        if (v.split(' ').length < 2) return 'Informe o nome completo.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email (somente leitura)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.email_outlined,
                                  color: Colors.grey, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _user?.email ?? '',
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF888888)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'O email não pode ser alterado.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Data de nascimento
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Data de nascimento',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _birthController,
                          readOnly: true,
                          onTap: _pickDate,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Selecione a data de nascimento.';
                            }
                            return null;
                          },
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF222222)),
                          decoration: InputDecoration(
                            hintText: 'DD/MM/AAAA',
                            hintStyle: const TextStyle(
                                color: Color(0xFFAAAAAA), fontSize: 14),
                            prefixIcon: const Icon(
                                Icons.calendar_today_outlined,
                                color: Colors.grey,
                                size: 20),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 16),
                            filled: true,
                            fillColor: const Color(0xFFFAFAFA),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE0E0E0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: appPrimary, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Colors.redAccent),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Botão Salvar
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'Salvar alterações',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
