import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:divida_aqui/core/app_colors.dart';
import 'package:divida_aqui/core/auth_service.dart';
import 'package:divida_aqui/components/auth_input_field.dart';
import 'package:divida_aqui/components/topo_background.dart';
import 'package:divida_aqui/pages/dashboard/dashboard_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _birthController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _birthController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await _authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMessage(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _firebaseMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Este email já está em uso.';
      case 'invalid-email':
        return 'Email inválido.';
      case 'weak-password':
        return 'A senha é muito fraca.';
      default:
        return 'Erro ao criar conta. Tente novamente.';
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 10, now.month, now.day),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: appPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _birthController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appPrimary,
      body: Stack(
        children: [
          const Positioned.fill(child: TopoBackground()),
          Column(
            children: [
              // Topo com título e botão voltar
              Expanded(
                flex: 1,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Text(
                          'Criar conta',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Formulário
              Expanded(
                flex: 5,
                child: ClipPath(
                  clipper: WaveClipper(),
                  child: Container(
                    color: Colors.white,
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cadastro',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 40,
                              height: 3,
                              decoration: BoxDecoration(
                                color: appPrimary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Nome completo
                            AuthInputField(
                              controller: _nameController,
                              label: 'Nome completo',
                              hintText: 'João da Silva',
                              prefixIcon: Icons.person_outline,
                              keyboardType: TextInputType.name,
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Informe o nome.';
                                if (v.split(' ').length < 2) {
                                  return 'Informe o nome completo.';
                                }
                                if (v.length < 4) {
                                  return 'Nome muito curto.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Email
                            AuthInputField(
                              controller: _emailController,
                              label: 'Email',
                              hintText: 'email@exemplo.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Informe o email.';
                                if (!v.contains('@')) {
                                  return 'Email deve conter @.';
                                }
                                if (!RegExp(r'\.[a-zA-Z]{2,}$').hasMatch(v)) {
                                  return 'Email deve conter domínio válido (ex: .com).';
                                }
                                return null;
                              },
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
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 14, horizontal: 16),
                                    filled: true,
                                    fillColor: const Color(0xFFFAFAFA),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE0E0E0)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: appPrimary, width: 1.5),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Colors.redAccent),
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
                            const SizedBox(height: 16),

                            // Senha
                            AuthInputField(
                              controller: _passwordController,
                              label: 'Senha',
                              hintText: 'mínimo 6 caracteres',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Informe a senha.';
                                }
                                if (value.length < 6) {
                                  return 'A senha deve ter pelo menos 6 caracteres.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Confirmação de senha
                            AuthInputField(
                              controller: _confirmController,
                              label: 'Confirmar senha',
                              hintText: 'repita a senha',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscureConfirm,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Confirme a senha.';
                                }
                                if (value != _passwordController.text) {
                                  return 'As senhas não coincidem.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            // Botão Cadastrar
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appPrimary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Criar conta',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            Center(
                              child: RichText(
                                text: TextSpan(
                                  text: 'Já tem uma conta? ',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF555555),
                                  ),
                                  children: [
                                    WidgetSpan(
                                      child: GestureDetector(
                                        onTap: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text(
                                          'Entrar',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: appPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
