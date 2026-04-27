import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import '../providers/maintenance_provider.dart';
import '../models/maintenance_data.dart';
import '../theme/app_theme.dart';

class OilChangeCard extends StatelessWidget {
  const OilChangeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MaintenanceProvider>(
      builder: (context, provider, _) {
        final mileageSince = provider.getMileageSinceLastOilChange();
        final remaining = provider.getRemainingMileage();
        final percentage = provider.getOilLifePercentage();
        final status = provider.getOilStatus();
        final last = provider.data.lastOilChange;

        Color barColor;
        String statusMsg;
        switch (status) {
          case OilStatus.critical:
            barColor = AppColors.critical;
            statusMsg = 'حالة حرجة - يرجى تغيير الزيت فوراً';
            break;
          case OilStatus.warning:
            barColor = AppColors.warning;
            statusMsg = 'تحذير - اقتراب موعد تغيير الزيت';
            break;
          default:
            barColor = AppColors.success;
            statusMsg = 'جميع الأنظمة تعمل بشكل طبيعي';
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.water_drop, color: AppColors.primary, size: 28),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'حالة زيت المحرك',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'عمر الزيت المتبقي',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status != OilStatus.normal)
                    Icon(Icons.warning_amber_rounded,
                        color: barColor, size: 24),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'عمر الزيت المتبقي - $percentage%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      icon: Icons.trending_down,
                      label: 'منذ التغيير',
                      value: '${intl.NumberFormat('#,###').format(mileageSince)} كم',
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      icon: Icons.speed,
                      label: 'المتبقي',
                      value: '${intl.NumberFormat('#,###').format(remaining)} كم',
                      valueColor: barColor,
                    ),
                  ),
                ],
              ),
              if (last != null) ...[
                const SizedBox(height: 12),
                Text(
                  'آخر تغيير: ${_formatDate(last.date)} - ${intl.NumberFormat('#,###').format(last.mileage)} كم',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: barColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusMsg,
                        style: TextStyle(
                          fontSize: 13,
                          color: barColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return intl.DateFormat('d MMM yyyy').format(d);
    } catch (_) {
      return iso;
    }
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
