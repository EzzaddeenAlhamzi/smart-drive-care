import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/alerts_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../pages/dashboard_page.dart';
import '../pages/alerts_page.dart';
import '../pages/history_page.dart';
import '../pages/reports_page.dart';
import '../pages/maintenance_log_page.dart';
import '../pages/device_connection_page.dart';
import '../pages/settings_page.dart';

class RootLayout extends StatefulWidget {
  const RootLayout({super.key});

  @override
  State<RootLayout> createState() => _RootLayoutState();
}

class _RootLayoutState extends State<RootLayout> {
  int _currentIndex = 0;

  final _pages = const [
    DashboardPage(),
    AlertsPage(),
    HistoryPage(),
    ReportsPage(),
    MaintenanceLogPage(),
    DeviceConnectionPage(),
    SettingsPage(),
  ];

  static const _menuItems = [
    (icon: Icons.home, label: 'الرئيسية'),
    (icon: Icons.notifications, label: 'التنبيهات'),
    (icon: Icons.bar_chart, label: 'السجل التاريخي'),
    (icon: Icons.description, label: 'التقارير'),
    (icon: Icons.build, label: 'سجل الصيانة'),
    (icon: Icons.wifi, label: 'الربط بالجهاز'),
    (icon: Icons.settings, label: 'الإعدادات'),
  ];

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertsProvider>(
      builder: (context, alertsProvider, _) {
        final settings = context.watch<SettingsProvider>();
        alertsProvider.configureServer(settings.sensorServerBaseUrl);
        final badgeCount = alertsProvider.unacknowledgedCount;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black87),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'نظام الصيانة التنبؤية',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.wifi, color: AppColors.primary),
                  onPressed: () {},
                ),
              ],
            ),
            drawer: _buildDrawer(badgeCount),
            body: _pages[_currentIndex],
            bottomNavigationBar: Container(
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavItem(
                        icon: Icons.home,
                        label: 'الرئيسية',
                        isActive: _currentIndex == 0,
                        onTap: () => setState(() => _currentIndex = 0),
                      ),
                      _NavItem(
                        icon: Icons.notifications,
                        label: 'التنبيهات',
                        isActive: _currentIndex == 1,
                        onTap: () => setState(() => _currentIndex = 1),
                        badge: badgeCount > 0 ? badgeCount : null,
                      ),
                      _NavItem(
                        icon: Icons.bar_chart,
                        label: 'السجل',
                        isActive: _currentIndex == 2,
                        onTap: () => setState(() => _currentIndex = 2),
                      ),
                      _NavItem(
                        icon: Icons.description,
                        label: 'التقارير',
                        isActive: _currentIndex == 3,
                        onTap: () => setState(() => _currentIndex = 3),
                      ),
                      _NavItem(
                        icon: Icons.settings,
                        label: 'الإعدادات',
                        isActive: _currentIndex == 4,
                        onTap: () => setState(() => _currentIndex = 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawer(int badgeCount) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: AppColors.primary.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'نظام الصيانة التنبؤية',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(_menuItems.length, (i) {
              final item = _menuItems[i];
              final isActive = _currentIndex == i;
              final showBadge = i == 1 && badgeCount > 0;
              return ListTile(
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      item.icon,
                      color: isActive ? AppColors.primary : Colors.grey.shade600,
                      size: 24,
                    ),
                    if (showBadge)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.critical,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? AppColors.primary : Colors.black87,
                  ),
                ),
                selected: isActive,
                selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                onTap: () => _navigateTo(i),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                size: 24,
                color: isActive ? AppColors.primary : Colors.grey.shade500,
              ),
              if (badge != null && badge! > 0)
                Positioned(
                  top: -4,
                  left: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.critical,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppColors.primary : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
