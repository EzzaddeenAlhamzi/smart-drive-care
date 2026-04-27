import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import '../providers/maintenance_provider.dart';
import '../models/oil_change.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';

class MaintenanceLogPage extends StatelessWidget {
  const MaintenanceLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Consumer<MaintenanceProvider>(
        builder: (context, maintenance, _) {
          final data = maintenance.data;
          final history = data.oilChangeHistory;

          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () => _showRecordDialog(context, maintenance),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('تسجيل تغيير زيت'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // زر التصدير
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _exportLog(context, maintenance, history),
                        icon: const Icon(Icons.download, size: 20),
                        label: const Text('تصدير السجل'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 4 بطاقات ملخص
                    _buildSummaryCards(context, maintenance),
                    const SizedBox(height: 24),

                    // عنوان Timeline
                    const Text(
                      'سجل تغييرات الزيت',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Timeline
                    if (history.isEmpty)
                      _buildEmptyState()
                    else
                      _buildTimeline(context, history),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRecordDialog(BuildContext context, MaintenanceProvider maintenance) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل تغيير زيت جديد'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'ملاحظات (اختياري)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              maintenance.recordOilChange(noteController.text.trim().isEmpty ? null : noteController.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تسجيل تغيير الزيت وحفظه في القاعدة'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, MaintenanceProvider maintenance) {
    final data = maintenance.data;
    final totalChanges = data.oilChangeHistory.length;
    final mileageSince = maintenance.getMileageSinceLastOilChange();
    final remaining = maintenance.getRemainingMileage();
    final oilLife = maintenance.getOilLifePercentage();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.oil_barrel,
                label: 'إجمالي التغييرات',
                value: '$totalChanges',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.straighten,
                label: 'كم منذ آخر تغيير',
                value: '$mileageSince',
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.flag,
                label: 'المتبقي للتغيير',
                value: '$remaining',
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.percent,
                label: 'عمر الزيت',
                value: '$oilLife%',
                color: oilLife < 30 ? AppColors.critical : AppColors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'لا توجد سجلات تغيير زيت بعد',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, List<OilChange> history) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < history.length; i++) ...[
            _TimelineItem(
              record: history[i],
              isFirst: i == 0,
              isLast: i == history.length - 1,
              onTap: () => _showDetailDialog(context, history[i]),
            ),
            if (i < history.length - 1)
              Container(
                margin: const EdgeInsets.only(right: 23),
                width: 2,
                height: 8,
                color: Colors.grey.shade300,
              ),
          ],
        ],
      ),
    );
  }

  void _showDetailDialog(BuildContext context, OilChange record) {
    DateTime? dt;
    try {
      dt = DateTime.parse(record.date);
    } catch (_) {}
    final dateStr = dt != null
        ? intl.DateFormat('yyyy/MM/dd - HH:mm').format(dt)
        : record.date;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفاصيل تغيير الزيت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'التاريخ', value: dateStr),
            const SizedBox(height: 8),
            _DetailRow(label: 'قراءة العداد', value: '${record.mileage} كم'),
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailRow(label: 'ملاحظات', value: record.notes!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _exportLog(BuildContext context, MaintenanceProvider maintenance, List<OilChange> history) async {
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد سجلات للتصدير'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    try {
      await ExportService.exportMaintenanceLogPdf(
        history: history,
        totalChanges: history.length,
        mileageSince: maintenance.getMileageSinceLastOilChange(),
        remaining: maintenance.getRemainingMileage(),
        oilLife: maintenance.getOilLifePercentage(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تصدير السجل بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التصدير: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final OilChange record;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _TimelineItem({
    required this.record,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    DateTime? dt;
    try {
      dt = DateTime.parse(record.date);
    } catch (_) {}
    final dateStr = dt != null
        ? intl.DateFormat('yyyy/MM/dd').format(dt)
        : record.date;
    final timeStr = dt != null
        ? intl.DateFormat('HH:mm').format(dt)
        : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (timeStr.isNotEmpty)
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.straighten, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${record.mileage} كم',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (record.notes != null && record.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      record.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
