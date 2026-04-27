import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/sensor_api_service.dart';
import '../theme/app_theme.dart';

class DeviceConnectionPage extends StatefulWidget {
  const DeviceConnectionPage({super.key});

  @override
  State<DeviceConnectionPage> createState() => _DeviceConnectionPageState();
}

class _DeviceConnectionPageState extends State<DeviceConnectionPage> {
  bool _isChecking = false;
  bool _serverReachable = false;
  SensorBridgePayload? _latest;
  Timer? _pollTimer;
  String _lastBaseUrl = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyPollingFromSettings());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final baseUrl = context.watch<SettingsProvider>().sensorServerBaseUrl.trim();
    if (baseUrl != _lastBaseUrl) {
      _lastBaseUrl = baseUrl;
      _applyPollingFromSettings();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _applyPollingFromSettings() async {
    _pollTimer?.cancel();
    final settings = context.read<SettingsProvider>();
    final baseUrl = settings.sensorServerBaseUrl.trim();
    if (baseUrl.isEmpty) {
      if (!mounted) return;
      setState(() {
        _serverReachable = false;
        _latest = null;
      });
      return;
    }

    await _refreshConnection();
    final interval = Duration(seconds: settings.updateIntervalSeconds.clamp(1, 30));
    _pollTimer = Timer.periodic(interval, (_) => _refreshConnection());
  }

  Future<void> _refreshConnection() async {
    final baseUrl = context.read<SettingsProvider>().sensorServerBaseUrl.trim();
    if (baseUrl.isEmpty) return;
    if (mounted) setState(() => _isChecking = true);
    final ok = await SensorApiService.checkHealth(baseUrl);
    final latest = ok ? await SensorApiService.fetchLatest(baseUrl) : null;
    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _serverReachable = ok;
      _latest = latest;
    });
  }

  bool get _isConnected {
    if (!_serverReachable || _latest?.updatedAt == null) return false;
    try {
      final ts = DateTime.parse(_latest!.updatedAt!).toLocal();
      return DateTime.now().difference(ts).inSeconds <= 30;
    } catch (_) {
      return false;
    }
  }

  String _statusText(SettingsProvider settings) {
    if (settings.sensorServerBaseUrl.trim().isEmpty) return 'لم يتم ضبط عنوان السيرفر';
    if (_isChecking) return 'جاري فحص الاتصال...';
    if (_isConnected) return 'متصل بالحساسات والبيانات مباشرة';
    if (_serverReachable) return 'السيرفر متاح لكن لا توجد بيانات حديثة';
    return 'غير متصل بالسيرفر';
  }

  String _updatedAtText() {
    final ts = _latest?.updatedAt;
    if (ts == null || ts.isEmpty) return '-';
    try {
      return DateTime.parse(ts).toLocal().toString();
    } catch (_) {
      return ts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // حالة الاتصال
                _buildConnectionStatusCard(settings),
                const SizedBox(height: 24),

                _buildConnectedDeviceCard(),
                const SizedBox(height: 16),
                _buildConnectionActions(context),

                const SizedBox(height: 24),

                // معلومات إضافية
                _buildInfoCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isConnected
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isConnected ? AppColors.success : AppColors.warning,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isConnected
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.warning.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isConnected ? Icons.wifi : Icons.wifi_off,
              size: 36,
              color: _isConnected ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isConnected ? 'متصل بالجهاز' : 'غير متصل',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _isConnected ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusText(settings),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (settings.autoReconnect && !_isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'إعادة اتصال تلقائي',
                    style: TextStyle(fontSize: 11, color: AppColors.primary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectedDeviceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'بيانات الربط الفعلية',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.lan, label: 'حالة السيرفر', value: _serverReachable ? 'متاح' : 'غير متاح'),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.thermostat, label: 'حرارة المحرك', value: '${_latest?.temp.toStringAsFixed(1) ?? '-'}°C'),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.battery_charging_full, label: 'البطارية', value: '${_latest?.battery.toStringAsFixed(2) ?? '-'}V'),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.oil_barrel, label: 'زيت المحرك', value: '${_latest?.engineOil ?? '-'} كم'),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.settings_input_component, label: 'زيت القير', value: '${_latest?.gearOil ?? '-'} كم'),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.update, label: 'آخر تحديث', value: _updatedAtText()),
        ],
      ),
    );
  }

  Widget _buildConnectionActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _isChecking ? null : _refreshConnection,
            icon: _isChecking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync, size: 18),
            label: Text(_isChecking ? 'جاري التحديث...' : 'تحديث الآن'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('يمكنك تغيير عنوان السيرفر من صفحة الإعدادات')),
              );
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('إعدادات الربط'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                'نصيحة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• هذه الصفحة تعرض حالة الربط الحقيقية مع سيرفر الحساسات.\n'
            '• إذا كان السيرفر متاحًا ولا توجد بيانات حديثة، تأكد أن Wokwi/ESP32 يرسل إلى /update.\n'
            '• يتم التحديث تلقائيا حسب فترة التحديث في الإعدادات.',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
