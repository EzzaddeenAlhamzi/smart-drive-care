import 'dart:typed_data';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/oil_change.dart';

/// خدمة تصدير التقارير والسجلات
class ExportService {
  static const _primary = PdfColor.fromInt(0xFF0d7e9c);
  static const _success = PdfColor.fromInt(0xFF3fb77a);
  static const _warning = PdfColor.fromInt(0xFFf59e0b);
  static const _critical = PdfColor.fromInt(0xFFdc2626);

  /// تصدير تقرير التقارير كـ PDF ومشاركته
  static Future<void> exportReportsPdf({
    required String monthName,
    required int totalReadings,
    required int normalReadings,
    required int warnings,
    required int critical,
    required double avgOil,
    required double avgTemp,
    required double avgBattery,
    required double avgTrans,
    required String tempUnit,
    required List<Map<String, dynamic>> alertsByType,
    required List<Map<String, dynamic>> weeklyAverages,
  }) async {
    final doc = pw.Document();
    final tempSuffix = tempUnit == 'fahrenheit' ? '°F' : '°C';
    final displayTemp = tempUnit == 'fahrenheit' ? avgTemp * 9 / 5 + 32 : avgTemp;

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(
          base: await PdfGoogleFonts.amiriRegular(),
          bold: await PdfGoogleFonts.amiriBold(),
        ),
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'تقرير الشهر الحالي - نظام الصيانة التنبؤية',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  monthName,
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('ملخص القراءات', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildCard('إجمالي القراءات', '$totalReadings', _primary),
              pw.SizedBox(width: 12),
              _buildCard('طبيعية', '$normalReadings', _success),
              pw.SizedBox(width: 12),
              _buildCard('تحذيرات', '$warnings', _warning),
              pw.SizedBox(width: 12),
              _buildCard('حرجة', '$critical', _critical),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('متوسطات القراءات الشهرية', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildCard('زيت المحرك', '$avgOil%', _success),
              pw.SizedBox(width: 12),
              _buildCard('حرارة', '${displayTemp.toStringAsFixed(1)}$tempSuffix', _warning),
              pw.SizedBox(width: 12),
              _buildCard('البطارية', '${avgBattery.toStringAsFixed(1)}V', PdfColors.purple),
              pw.SizedBox(width: 12),
              _buildCard('زيت القير', '$avgTrans%', PdfColors.pink),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('التنبيهات حسب النوع', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('النوع', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('العدد', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('الاتجاه', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ],
              ),
              ...alertsByType.map((e) => pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(e['type'] as String)),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${e['count']}')),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(_trendLabel(e['trend'] as String))),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('المتوسطات الأسبوعية', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('اليوم', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('زيت %', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('حرارة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ],
              ),
              ...weeklyAverages.map((e) => pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(e['day'] as String)),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${(e['oil'] as double).toStringAsFixed(0)}%')),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${(e['temp'] as double).toStringAsFixed(0)}°')),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'تاريخ التصدير: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await _sharePdf(bytes, 'تقرير_الصيانة_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  static pw.Widget _buildCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 2),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(label, style: pw.TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  static String _trendLabel(String t) {
    switch (t) {
      case 'up': return 'صاعد';
      case 'down': return 'هابط';
      default: return 'مستقر';
    }
  }

  /// تصدير سجل الصيانة كـ PDF ومشاركته
  static Future<void> exportMaintenanceLogPdf({
    required List<OilChange> history,
    required int totalChanges,
    required int mileageSince,
    required int remaining,
    required int oilLife,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(
          base: await PdfGoogleFonts.amiriRegular(),
          bold: await PdfGoogleFonts.amiriBold(),
        ),
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'سجل تغييرات الزيت - نظام الصيانة التنبؤية',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'تاريخ التصدير: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('ملخص', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildCard('إجمالي التغييرات', '$totalChanges', _primary),
              pw.SizedBox(width: 12),
              _buildCard('كم منذ آخر تغيير', '$mileageSince', _success),
              pw.SizedBox(width: 12),
              _buildCard('المتبقي للتغيير', '$remaining', _warning),
              pw.SizedBox(width: 12),
              _buildCard('عمر الزيت', '$oilLife%', PdfColors.purple),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('سجل التغييرات', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('التاريخ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('قراءة العداد (كم)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('ملاحظات', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ],
              ),
              ...history.map((r) {
                DateTime? dt;
                try {
                  dt = DateTime.parse(r.date);
                } catch (_) {}
                final dateStr = dt != null
                    ? intl.DateFormat('yyyy/MM/dd HH:mm').format(dt)
                    : r.date;
                return pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(dateStr)),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${r.mileage}')),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(r.notes ?? '-')),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await _sharePdf(bytes, 'سجل_الصيانة_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  static Future<void> _sharePdf(Uint8List bytes, String filename) async {
    try {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (_) {
      final xFile = XFile.fromData(bytes, mimeType: 'application/pdf', name: filename);
      await Share.shareXFiles([xFile], text: filename);
    }
  }
}
