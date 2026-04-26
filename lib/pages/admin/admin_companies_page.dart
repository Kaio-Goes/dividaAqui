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
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.grey)),
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
      MaterialPageRoute(
        builder: (_) => AddCompanyPage(company: company),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: appPrimary,
        foregroundColor: Colors.white,
        title: const Text(
          'Empresas',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: appPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova empresa'),
      ),
      body: StreamBuilder<List<CompanyModel>>(
        stream: _service.streamCompanies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: appPrimary));
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Erro ao carregar empresas.',
                  style: TextStyle(color: Colors.grey)),
            );
          }
          final companies = snapshot.data ?? [];
          if (companies.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma empresa cadastrada.',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: companies.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final c = companies[index];
              final color = _riskColor(c.riskLevel);
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(Icons.business, color: color),
                  ),
                  title: Text(
                    c.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    c.sector,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color, width: 1),
                        ),
                        child: Text(
                          c.riskLabel,
                          style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        onSelected: (value) {
                          if (value == 'edit') _openForm(company: c);
                          if (value == 'delete') _delete(c);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'edit', child: Text('Editar')),
                          PopupMenuItem(
                              value: 'delete',
                              child: Text('Excluir',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
