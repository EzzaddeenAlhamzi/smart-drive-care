import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class DeviceConnectionPage extends StatefulWidget {
  const DeviceConnectionPage({super.key});

  @override
  State<DeviceConnectionPage> createState() => _DeviceConnectionPageState();
}

class _DeviceConnectionPageState extends State<DeviceConnectionPage> {
  bool _isConnected = false;
  bool _isSearching = false;
  final List<Map<String, String>> _discoveredDevices = [];
  static const _mockDevices = [
    {'name': 'Vehicle Sensor Unit v2.5', 'mac': '00:1B:44:11:3A:B7'},
    {'name': 'Car Monitor Pro', 'mac': 'AA:BB:CC:DD:EE:F1'},
    {'name': 'Smart OBD-II', 'mac': '11:22:33:44:55:66'},
  ];

  Future<void> _startSearch() async {
    setState(() {
      _isSearching = true;
      _discoveredDevices.clear();
    });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isSearching = false;
        _discoveredDevices.addAll(_mockDevices);
      });
    }
  }

  void _connectToDevice(Map<String, String> device) {
    setState(() {
      _isConnected = true;
      _discoveredDevices.clear();
    });
  }

  void _disconnect() {
    setState(() => _isConnected = false);
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

                if (_isConnected) ...[
                  _buildConnectedDeviceCard(),
                  const SizedBox(height: 24),
                  _buildDisconnectButton(),
                ] else ...[
                  _buildSearchSection(),
                  if (_discoveredDevices.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDiscoveredDevicesList(),
                  ],
                ],

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
                  _isConnected
                      ? 'البيانات تُستقبل تلقائياً'
                      : 'ابحث عن جهاز المستشعر للاتصال',
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
            'الجهاز المتصل',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.device_hub, label: 'الاسم', value: 'Vehicle Sensor Unit v2.5'),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.fingerprint, label: 'عنوان MAC', value: '00:1B:44:11:3A:B7'),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.signal_cellular_4_bar, label: 'قوة الإشارة', value: 'ممتاز'),
        ],
      ),
    );
  }

  Widget _buildDisconnectButton() {
    return OutlinedButton.icon(
      onPressed: _disconnect,
      icon: const Icon(Icons.link_off, size: 20),
      label: const Text('قطع الاتصال'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.critical,
        side: const BorderSide(color: AppColors.critical),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildSearchSection() {
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'البحث عن الأجهزة',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تأكد من تشغيل جهاز المستشعر وتفعيل Bluetooth أو WiFi',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSearching ? null : _startSearch,
            icon: _isSearching
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search, size: 22),
            label: Text(_isSearching ? 'جاري البحث...' : 'بحث عن أجهزة'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredDevicesList() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'الأجهزة المكتشفة (${_discoveredDevices.length})',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ..._discoveredDevices.map((device) => ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.memory, color: AppColors.primary, size: 24),
                ),
                title: Text(device['name']!),
                subtitle: Text(
                  device['mac']!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: FilledButton(
                  onPressed: () => _connectToDevice(device),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('اتصال'),
                ),
              )),
        ],
      ),
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
            '• تأكد من تفعيل Bluetooth أو WiFi على هاتفك\n'
            '• ضع جهاز المستشعر بالقرب من الهاتف\n'
            '• إعداد "إعادة الاتصال التلقائي" من الإعدادات يحافظ على الاتصال',
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
