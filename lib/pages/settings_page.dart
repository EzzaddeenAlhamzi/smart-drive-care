import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/maintenance_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/alerts_provider.dart';
import '../services/sensor_api_service.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showSavedMessage = false;
  bool _isEditingMileage = false;
  bool _intervalInitialized = false;
  bool _isCheckingServer = false;
  bool? _serverReachable;
  SensorBridgePayload? _latestPayload;
  final _mileageController = TextEditingController();
  final _intervalController = TextEditingController();
  final _sensorServerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final url = context.read<SettingsProvider>().sensorServerBaseUrl;
      if (url.isNotEmpty) {
        _sensorServerController.text = url;
        _checkServerConnection();
      }
    });
  }

  @override
  void dispose() {
    _mileageController.dispose();
    _intervalController.dispose();
    _sensorServerController.dispose();
    super.dispose();
  }

  void _showSaveConfirmation() {
    setState(() => _showSavedMessage = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSavedMessage = false);
    });
  }

  Future<void> _checkServerConnection() async {
    final baseUrl = context.read<SettingsProvider>().sensorServerBaseUrl;
    if (baseUrl.trim().isEmpty) {
      setState(() {
        _serverReachable = null;
        _latestPayload = null;
      });
      return;
    }
    setState(() => _isCheckingServer = true);
    final health = await SensorApiService.checkHealth(baseUrl);
    final latest = health ? await SensorApiService.fetchLatest(baseUrl) : null;
    if (!mounted) return;
    setState(() {
      _isCheckingServer = false;
      _serverReachable = health;
      _latestPayload = latest;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showSavedMessage) _buildSavedBanner(),
                    const SizedBox(height: 16),

                    // إعدادات الصيانة
                    _buildSectionTitle('إعدادات الصيانة'),
                    const SizedBox(height: 12),
                    _buildMaintenanceSection(context),
                    const SizedBox(height: 24),

                    // الإعدادات العامة
                    _buildSectionTitle('الإعدادات العامة'),
                    const SizedBox(height: 12),
                    _buildGeneralSection(context),
                    const SizedBox(height: 24),

                    // الإشعارات
                    _buildSectionTitle('الإشعارات'),
                    const SizedBox(height: 12),
                    _buildNotificationsSection(context),
                    const SizedBox(height: 24),

                    // الاتصال
                    _buildSectionTitle('الاتصال'),
                    const SizedBox(height: 12),
                    _buildConnectionSection(context),
                    const SizedBox(height: 24),

                    // سيرفر الحساسات (Wokwi / ESP32)
                    _buildSectionTitle('سيرفر الحساسات (ESP32 / Wokwi)'),
                    const SizedBox(height: 12),
                    _buildSensorServerSection(context),
                    const SizedBox(height: 24),

                    // إدارة البيانات
                    _buildSectionTitle('إدارة البيانات'),
                    const SizedBox(height: 12),
                    _buildDataSection(context),
                    const SizedBox(height: 24),

                    // عن التطبيق
                    _buildSectionTitle('عن التطبيق'),
                    const SizedBox(height: 12),
                    _buildAboutSection(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildSaveButton(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 28),
          const SizedBox(width: 12),
          const Text(
            'تم حفظ الإعدادات بنجاح',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  Widget _buildMaintenanceSection(BuildContext context) {
    final maintenance = context.watch<MaintenanceProvider>();
    final data = maintenance.data;
    if (!_intervalInitialized) {
      _intervalInitialized = true;
      _intervalController.text = data.oilChangeInterval.toString();
    }

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('قراءة العداد الحالية'),
                    Text(
                      '${intl.NumberFormat('#,###').format(data.currentMileage)} كم',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isEditingMileage) ...[
            TextField(
              controller: _mileageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'أدخل المسافة بالكيلومتر',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _isEditingMileage = false),
                  child: const Text('إلغاء'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final val = int.tryParse(_mileageController.text);
                    if (val != null && val >= 0) {
                      maintenance.updateCurrentMileage(val);
                      setState(() => _isEditingMileage = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تحديث قراءة العداد بنجاح'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('الرجاء إدخال رقم صحيح للمسافة'),
                          backgroundColor: AppColors.critical,
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                  child: const Text('حفظ'),
                ),
              ],
            ),
          ] else
            OutlinedButton.icon(
              onPressed: () {
                _mileageController.text = data.currentMileage.toString();
                setState(() => _isEditingMileage = true);
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('تعديل'),
            ),
          const SizedBox(height: 16),
          const Text('المسافة لتغيير الزيت (كم)'),
          const SizedBox(height: 8),
          TextField(
            controller: _intervalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '1000 - 50000',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) {
              final val = int.tryParse(v);
              if (val != null && val >= 1000 && val <= 50000) {
                maintenance.updateOilChangeInterval(val);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تحديث مسافة تغيير الزيت بنجاح'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'المسافة الموصى بها تختلف حسب نوع السيارة ونوع الزيت المستخدم.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSection(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('وحدة الحرارة'),
              DropdownButton<String>(
                value: settings.temperatureUnit,
                items: const [
                  DropdownMenuItem(value: 'celsius', child: Text('°C')),
                  DropdownMenuItem(value: 'fahrenheit', child: Text('°F')),
                ],
                onChanged: (v) => v != null ? settings.setTemperatureUnit(v) : null,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('فترة التحديث'),
              DropdownButton<int>(
                value: settings.updateIntervalSeconds,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 ثانية')),
                  DropdownMenuItem(value: 3, child: Text('3 ثواني')),
                  DropdownMenuItem(value: 5, child: Text('5 ثواني')),
                  DropdownMenuItem(value: 10, child: Text('10 ثواني')),
                ],
                onChanged: (v) => v != null ? settings.setUpdateInterval(v) : null,
              ),
            ],
          ),
          const Divider(height: 24),
          _buildSwitchRow(
            'الوضع الليلي',
            settings.darkMode,
            Icons.dark_mode,
            Icons.light_mode,
            settings.setDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

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
        children: [
          _buildSwitchRow(
            'تفعيل الإشعارات',
            settings.notificationsEnabled,
            Icons.notifications,
            Icons.notifications_off,
            settings.setNotificationsEnabled,
          ),
          const Divider(height: 24),
          Opacity(
            opacity: settings.notificationsEnabled ? 1 : 0.5,
            child: _buildSwitchRow(
              'التنبيهات الحرجة فقط',
              settings.criticalAlertsOnly,
              Icons.warning,
              Icons.warning_amber,
              settings.setCriticalAlertsOnly,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorServerSection(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (_sensorServerController.text.isEmpty &&
        settings.sensorServerBaseUrl.isNotEmpty) {
      _sensorServerController.text = settings.sensorServerBaseUrl;
    }

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'عنوان السيرفر الوسيط',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'بدون /update.\n'
            '• Chrome / Edge (flutter run -d chrome): http://localhost:3000\n'
            '• محاكي Android: http://10.0.2.2:3000\n'
            '• هاتف على نفس WiFi: http://عنوان-IP-الكمبيوتر:3000\n'
            'اتركه فارغاً للمحاكاة داخل التطبيق.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sensorServerController,
            decoration: const InputDecoration(
              hintText: 'http://10.0.2.2:3000',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              context.read<SettingsProvider>().setSensorServerBaseUrl(_sensorServerController.text);
              _checkServerConnection();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حفظ عنوان السيرفر'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            icon: const Icon(Icons.save_outlined, size: 20),
            label: const Text('حفظ عنوان السيرفر'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isCheckingServer ? null : _checkServerConnection,
            icon: _isCheckingServer
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.health_and_safety_outlined, size: 20),
            label: Text(_isCheckingServer ? 'جاري الفحص...' : 'اختبار الاتصال'),
          ),
          if (_serverReachable != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_serverReachable! ? AppColors.success : AppColors.critical)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _serverReachable! ? Icons.check_circle : Icons.error_outline,
                    size: 18,
                    color: _serverReachable! ? AppColors.success : AppColors.critical,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _serverReachable! ? 'السيرفر متاح ويعمل' : 'تعذر الوصول إلى السيرفر',
                    style: TextStyle(
                      color: _serverReachable! ? AppColors.success : AppColors.critical,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionSection(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSwitchRow(
            'إعادة الاتصال التلقائي',
            settings.autoReconnect,
            Icons.refresh,
            Icons.refresh,
            settings.setAutoReconnect,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'حالة مصدر البيانات',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('وضع الاتصال: ${settings.useLiveSensors ? 'مباشر من السيرفر' : 'محلي'}'),
                Text('عنوان السيرفر: ${settings.sensorServerBaseUrl.isEmpty ? '-' : settings.sensorServerBaseUrl}'),
                Text('حالة السيرفر: ${_serverReachable == null ? 'غير مفحوص' : (_serverReachable! ? 'متاح' : 'غير متاح')}'),
                if (_latestPayload?.updatedAt != null)
                  Text('آخر تحديث فعلي: ${_latestPayload!.updatedAt}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final retentionOptions = [7, 14, 30, 60, 90];

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('مدة حفظ البيانات'),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: settings.dataRetentionDays,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: retentionOptions
                .map((d) => DropdownMenuItem(
                      value: d,
                      child: Text('$d يوم'),
                    ))
                .toList(),
            onChanged: (v) => v != null ? settings.setDataRetentionDays(v) : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportBackup(context),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('نسخ احتياطي'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _importBackup(context),
                  icon: const Icon(Icons.upload, size: 18),
                  label: const Text('استعادة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _showClearDataDialog(context),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('مسح جميع البيانات'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.critical,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
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
          const Text('نظام الصيانة التنبؤية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('الإصدار: 1.0.0', style: TextStyle(color: Colors.grey.shade600)),
          Text('فبراير 2026', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(
    String label,
    bool value,
    IconData iconOn,
    IconData iconOff,
    void Function(bool) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(value ? iconOn : iconOff, size: 22, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: FilledButton(
          onPressed: () {
            _showSaveConfirmation();
            final maintenance = context.read<MaintenanceProvider>();
            final settings = context.read<SettingsProvider>();
            final interval = int.tryParse(_intervalController.text);
            if (interval != null && interval >= 1000 && interval <= 50000) {
              maintenance.updateOilChangeInterval(interval);
            }
            settings.setSensorServerBaseUrl(_sensorServerController.text);
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.success,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('حفظ الإعدادات'),
        ),
      ),
    );
  }

  void _exportBackup(BuildContext context) {
    final maintenance = context.read<MaintenanceProvider>();
    final settings = context.read<SettingsProvider>();
    final data = {
      'maintenance': maintenance.data.toJson(),
      'settings': {
        'temperatureUnit': settings.temperatureUnit,
        'updateInterval': settings.updateIntervalSeconds,
        'dataRetentionDays': settings.dataRetentionDays,
        'sensorServerBaseUrl': settings.sensorServerBaseUrl,
      },
      'exportedAt': DateTime.now().toIso8601String(),
    };
    final backupJson = const JsonEncoder.withIndent('  ').convert(data);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نسخة احتياطية (JSON)'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              backupJson,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: backupJson));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم نسخ النسخة الاحتياطية للحافظة'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('نسخ'),
          ),
        ],
      ),
    );
  }

  void _importBackup(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة النسخة الاحتياطية'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            minLines: 10,
            maxLines: 16,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              hintText: 'الصق JSON هنا...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final raw = controller.text.trim();
                final map = jsonDecode(raw) as Map<String, dynamic>;
                final settingsMap =
                    (map['settings'] as Map?)?.cast<String, dynamic>() ?? {};
                final maintenanceMap =
                    (map['maintenance'] as Map?)?.cast<String, dynamic>() ?? {};
                final settings = context.read<SettingsProvider>();
                final maintenance = context.read<MaintenanceProvider>();

                await settings.saveAll(settingsMap);
                if (maintenanceMap.isNotEmpty) {
                  await maintenance.restoreFromJson(maintenanceMap);
                }
                if (!mounted) return;
                Navigator.pop(ctx);
                setState(() => _intervalInitialized = false);
                _sensorServerController.text = settings.sensorServerBaseUrl;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تمت استعادة النسخة الاحتياطية بنجاح'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('صيغة النسخة الاحتياطية غير صحيحة'),
                    backgroundColor: AppColors.critical,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد المسح'),
        content: const Text(
          'هل أنت متأكد من مسح جميع البيانات؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final maintenance = context.read<MaintenanceProvider>();
              final alerts = context.read<AlertsProvider>();
              final messenger = ScaffoldMessenger.of(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              await maintenance.reload();
              await alerts.reload();
              if (!mounted) return;
              setState(() => _intervalInitialized = false);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('تم مسح جميع البيانات'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.critical),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
  }
}
