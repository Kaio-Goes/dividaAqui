import 'dart:io';
import 'package:divida_aqui/core/company_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _white70 = PdfColor(1, 1, 1, 0.7);

class ReportService {
  static String _formatCurrency(double value) {
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

  static String _formatCnpj(String digits) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    if (d.length != 14) return digits;
    return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
  }

  static String _riskLabel(int level) {
    switch (level) {
      case 1:
        return 'Baixo';
      case 2:
        return 'Médio';
      case 3:
        return 'Alto';
      default:
        return '-';
    }
  }

  static PdfColor _riskColor(int level) {
    switch (level) {
      case 1:
        return const PdfColor.fromInt(0xFF4CAF50);
      case 2:
        return const PdfColor.fromInt(0xFFFF9800);
      case 3:
        return const PdfColor.fromInt(0xFFF44336);
      default:
        return PdfColors.grey;
    }
  }

  static String _now() {
    final n = DateTime.now();
    final d =
        '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}';
    final t =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
    return '$d às $t';
  }

  /// Gera o PDF e compartilha via Share nativo.
  static Future<void> exportAndShare({
    required List<CompanyModel> companies,
    required String analystName,
    int? filterRisk,
    String? filterSector,
  }) async {
    final pdf = pw.Document();

    final appPrimary = const PdfColor.fromInt(0xFF1A4B8C);
    final headerBg = const PdfColor.fromInt(0xFF1A4B8C);
    final rowAlt = const PdfColor.fromInt(0xFFF5F7FA);

    // ── Estatísticas ──────────────────────────────────────────────────
    final total = companies.length;
    final totalDebt = companies.fold(0.0, (s, c) => s + c.debtValue);
    final baixo = companies.where((c) => c.riskLevel == 1).length;
    final medio = companies.where((c) => c.riskLevel == 2).length;
    final alto = companies.where((c) => c.riskLevel == 3).length;

    // ── Filtros ativos para exibição ──────────────────────────────────
    final filterParts = <String>[];
    if (filterRisk != null) filterParts.add('Risco: ${_riskLabel(filterRisk)}');
    if (filterSector != null) filterParts.add('Setor: $filterSector');
    final filterDesc =
        filterParts.isEmpty ? 'Sem filtros aplicados' : filterParts.join(' • ');

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        ),
        build: (context) => [
          // ── Cabeçalho ───────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: headerBg,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Dívida Aqui',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Radar de Risco Empresarial',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: _white70,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Relatório Exportado',
                      style: pw.TextStyle(
                          fontSize: 10, color: _white70),
                    ),
                    pw.Text(
                      _now(),
                      style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Analista: $analystName',
                      style: pw.TextStyle(
                          fontSize: 10, color: _white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Filtros ─────────────────────────────────────────────────
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                  color: const PdfColor.fromInt(0xFFE0E0E0)),
              borderRadius: pw.BorderRadius.circular(6),
              color: const PdfColor.fromInt(0xFFFAFAFA),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'Filtros: ',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  filterDesc,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Cards de resumo ──────────────────────────────────────────
          pw.Row(
            children: [
              _summaryCard('Total de Empresas', '$total', appPrimary),
              pw.SizedBox(width: 8),
              _summaryCard(
                  'Total de Dívidas', _formatCurrency(totalDebt), appPrimary),
              pw.SizedBox(width: 8),
              _summaryCard(
                  'Distribuição de Risco',
                  'B: $baixo  M: $medio  A: $alto',
                  appPrimary),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Tabela de empresas ───────────────────────────────────────
          pw.Text(
            'Lista de Empresas',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: appPrimary,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2.8),
              1: const pw.FlexColumnWidth(2.0),
              2: const pw.FlexColumnWidth(2.2),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.0),
              5: const pw.FlexColumnWidth(1.8),
            },
            children: [
              // Cabeçalho da tabela
              pw.TableRow(
                decoration: pw.BoxDecoration(color: appPrimary),
                children: [
                  _th('Empresa'),
                  _th('Setor'),
                  _th('CNPJ'),
                  _th('Score'),
                  _th('Risco'),
                  _th('Dívida'),
                ],
              ),
              // Linhas de dados
              ...List.generate(companies.length, (i) {
                final c = companies[i];
                final bg = i.isOdd ? rowAlt : PdfColors.white;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _td(c.name),
                    _td(c.sector),
                    _td(c.cnpj.isNotEmpty ? _formatCnpj(c.cnpj) : '-'),
                    _td(c.score.toStringAsFixed(1)),
                    _tdRisk(_riskLabel(c.riskLevel), _riskColor(c.riskLevel)),
                    _td(_formatCurrency(c.debtValue)),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    // ── Salvar e compartilhar ─────────────────────────────────────────
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/relatorio_divida_aqui.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Relatório Dívida Aqui – ${_now()}',
    );
  }

  static pw.Widget _summaryCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(fontSize: 8, color: _white70)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _th(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      );

  static pw.Widget _td(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
      );

  static pw.Widget _tdRisk(String label, PdfColor color) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      );
}
