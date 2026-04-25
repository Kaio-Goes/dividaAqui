import 'package:flutter/material.dart';
import 'package:divida_aqui/core/app_colors.dart';
import 'package:divida_aqui/components/login_form_panel.dart';
import 'package:divida_aqui/components/topo_background.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appPrimary,
      body: Stack(
        children: [
          const Positioned.fill(child: TopoBackground()),
          Column(
            children: [
              SizedBox(height: 48),
              Expanded(
                flex: 2,
                child: SafeArea(
                  bottom: false,
                  child: Center(
                    child: Image.asset(
                      'assets/images/divida_logo_fundo.png',
                      width: 330,
                      height: 330,
                    ),
                  ),
                ),
              ),
              const Expanded(
                flex: 3,
                child: LoginFormPanel(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
