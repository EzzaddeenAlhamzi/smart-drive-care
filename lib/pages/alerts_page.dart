import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alert.dart';
import '../providers/alerts_provider.dart';
import '../theme/app_theme.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  static String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    final minutes = diff.inMinutes;
    if (minutes < 1) return 'الآن';
    if (minutes < 60) return 'منذ $minutes دقيقة';
    final hours = diff.inHours;
    if (hours < 24) return 'منذ $hours ساعة';
    final days = diff.inDays;
    return 'منذ $days يوم';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: Consumer<AlertsProvider>(
            builder: (context, provider, _) {
              final unack = provider.unacknowledgedAlerts;
              final ack = provider.acknowledgedAlerts;
              final criticalCount =
                  provider.alerts.where((a) => a.riskLevel == 'CRITICAL').length;
              final highCount =
                  provider.alerts.where((a) => a.riskLevel == 'HIGH').length;
              final mediumCount =
                  provider.alerts.where((a) => a.riskLevel == 'MEDIUM').length;
              final ackCount =
                  provider.alerts.where((a) => a.acknowledged).length;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (provider.isLoading && provider.alerts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _EmptyState(
                          icon: Icons.sync,
                          message: 'جاري جلب التنبيهات الحية...',
                        ),
                      ),

                    // دوائر إحصائيات 2x2
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.0,
                      children: [
                        _StatCard(
                          label: 'تنبيهات حرجة',
                          count: criticalCount,
                          color: AppColors.critical,
                        ),
                        _StatCard(
                          label: 'تنبيهات عالية',
                          count: highCount,
                          color: const Color(0xFFea580c),
                        ),
                        _StatCard(
                          label: 'تنبيهات متوسطة',
                          count: mediumCount,
                          color: AppColors.warning,
                        ),
                        _StatCard(
                          label: 'تم الاطلاع',
                          count: ackCount,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // التنبيهات النشطة
                    const Text(
                      'التنبيهات النشطة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (unack.isEmpty)
                      _EmptyState(
                        icon: Icons.check_circle_outline,
                        message: 'لا توجد تنبيهات نشطة',
                      )
                    else
                      ...unack.map((a) => _AlertCard(
                            alert: a,
                            onTap: () => _showAlertDetail(context, a, provider),
                          )),
                    const SizedBox(height: 24),

                    // التنبيهات السابقة
                    const Text(
                      'تم الاطلاع عليها',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (ack.isEmpty)
                      const SizedBox.shrink()
                    else
                      ...ack.map((a) => _AlertCard(
                            alert: a,
                            acknowledged: true,
                          )),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAlertDetail(
      BuildContext context, Alert alert, AlertsProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AlertDetailSheet(
        alert: alert,
        formatTimestamp: _formatTimestamp,
        onAcknowledge: () async {
          Navigator.pop(ctx);
          await provider.acknowledge(alert.id);
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.55), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Alert alert;
  final VoidCallback? onTap;
  final bool acknowledged;

  const _AlertCard({
    required this.alert,
    this.onTap,
    this.acknowledged = false,
  });

  Color get _borderColor {
    if (acknowledged) return Colors.grey;
    switch (alert.riskLevel) {
      case 'CRITICAL':
        return AppColors.critical;
      case 'HIGH':
        return const Color(0xFFea580c);
      case 'MEDIUM':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  Color get _bgColor {
    if (acknowledged) return Colors.grey.shade100;
    switch (alert.riskLevel) {
      case 'CRITICAL':
        return AppColors.critical.withValues(alpha: 0.08);
      case 'HIGH':
        return const Color(0xFFea580c).withValues(alpha: 0.08);
      case 'MEDIUM':
        return AppColors.warning.withValues(alpha: 0.08);
      default:
        return AppColors.primary.withValues(alpha: 0.08);
    }
  }

  String get _riskLabel {
    switch (alert.riskLevel) {
      case 'CRITICAL':
        return 'حرجة';
      case 'HIGH':
        return 'عالية';
      case 'MEDIUM':
        return 'متوسطة';
      default:
        return 'منخفضة';
    }
  }

  IconData get _icon {
    if (acknowledged) return Icons.check_circle;
    switch (alert.riskLevel) {
      case 'CRITICAL':
      case 'HIGH':
        return Icons.warning_amber_rounded;
      case 'MEDIUM':
        return Icons.info_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: acknowledged ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(
                right: BorderSide(color: _borderColor, width: 4),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Opacity(
              opacity: acknowledged ? 0.6 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_icon,
                          color: acknowledged
                              ? AppColors.success
                              : _borderColor,
                          size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          alert.message,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _borderColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _riskLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _borderColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alert.suggestedAction,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AlertsPage._formatTimestamp(alert.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertDetailSheet extends StatelessWidget {
  final Alert alert;
  final String Function(DateTime) formatTimestamp;
  final VoidCallback onAcknowledge;

  const _AlertDetailSheet({
    required this.alert,
    required this.formatTimestamp,
    required this.onAcknowledge,
  });

  Color get _borderColor {
    switch (alert.riskLevel) {
      case 'CRITICAL':
        return AppColors.critical;
      case 'HIGH':
        return const Color(0xFFea580c);
      case 'MEDIUM':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  String get _riskLabel {
    switch (alert.riskLevel) {
      case 'CRITICAL':
        return 'حرجة';
      case 'HIGH':
        return 'عالية';
      case 'MEDIUM':
        return 'متوسطة';
      default:
        return 'منخفضة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: _borderColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.message,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _borderColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _riskLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _borderColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatTimestamp(alert.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الإجراء المقترح',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alert.suggestedAction,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!alert.acknowledged) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onAcknowledge,
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text('تم الاطلاع'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.share, size: 20),
                      label: const Text('مشاركة'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
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
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
