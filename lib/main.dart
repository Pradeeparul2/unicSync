import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api/sync_api_client.dart';
import 'core/engine/engine_manager.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/files/files_screen.dart';
import 'features/logs/logs_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profiles/profiles_screen.dart';
import 'features/settings/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UnicSyncApp());
}

class UnicSyncApp extends StatelessWidget {
  const UnicSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'unicSync',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF1E293B),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: const Color(0xFF1E293B),
          indicatorColor: const Color(0xFF38BDF8),
          selectedIconTheme: const IconThemeData(color: Color(0xFF0F172A), size: 24),
          unselectedIconTheme: IconThemeData(color: Colors.grey.shade400, size: 22),
          selectedLabelTextStyle: const TextStyle(
            color: Color(0xFF38BDF8),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelTextStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
        useMaterial3: true,
      ),
      home: const AppBootstrap(),
    );
  }
}

/// Determines whether to display first-time setup or the main dashboard.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _isLoading = true;
  bool _isOnboarded = false;

  @override
  void initState() {
    super.initState();
    _checkSetupState();
  }

  Future<void> _checkSetupState() async {
    try {
      final engine = EngineManager();
      await engine.initialize();

      final prefs = await SharedPreferences.getInstance();
      final onboarded = prefs.getBool('is_onboarded') ?? false;
      final watchPath = prefs.getString('watch_path') ?? engine.currentWatchPath;

      final isAlreadyRunning = engine.isRunning;
      final effectiveWatchPath = watchPath ?? engine.currentWatchPath;

      if ((onboarded || isAlreadyRunning) && effectiveWatchPath != null) {
        if (!isAlreadyRunning) {
          await engine.start(effectiveWatchPath);
        }
        if (mounted) {
          setState(() {
            _isOnboarded = true;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isOnboarded = false;
            _isLoading = false;
          });
        }
      }
    } catch (e, stack) {
      debugPrint('Startup check error: $e\n$stack');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF38BDF8)),
              SizedBox(height: 16),
              Text('Starting rSync Engine...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (!_isOnboarded) {
      return OnboardingScreen(
        onSetupComplete: () => setState(() => _isOnboarded = true),
      );
    }

    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final SyncApiClient _client = SyncApiClient();
  List<DiscoveredEngine> _engines = [];
  Timer? _engineProbeTimer;

  @override
  void initState() {
    super.initState();
    _probeEngines();
    _engineProbeTimer = Timer.periodic(const Duration(seconds: 4), (_) => _probeEngines());
  }

  @override
  void dispose() {
    _engineProbeTimer?.cancel();
    super.dispose();
  }

  Future<void> _probeEngines() async {
    try {
      final detected = await _client.detectAvailableEngines();
      if (mounted) {
        // If the currently selected engine was unplugged/went offline, fallback cleanly to Local PC
        if (_client.currentTarget != EngineTarget.localPc) {
          final isStillOnline = detected.any((e) => e.baseUrl == _client.baseUrl);
          if (!isStillOnline) {
            final localEngine = detected.firstWhere(
              (e) => e.target == EngineTarget.localPc,
              orElse: () => DiscoveredEngine(
                target: EngineTarget.localPc,
                name: '💻 Local PC Drive',
                baseUrl: 'http://127.0.0.1:8484',
                isOnline: true,
              ),
            );
            _client.setBaseUrl(localEngine.baseUrl, target: EngineTarget.localPc);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('USB drive disconnected. Auto-switched back to Local PC Engine.'),
                backgroundColor: Colors.amber,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
        setState(() => _engines = detected);
      }
    } catch (_) {}
  }

  void _switchEngine(DiscoveredEngine engine) {
    _client.setBaseUrl(engine.baseUrl, target: engine.target);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to ${engine.name} (${engine.baseUrl})'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        client: _client,
        onNavigateToFiles: () => setState(() => _selectedIndex = 1),
      ),
      FilesScreen(client: _client),
      ProfilesScreen(client: _client),
      const LogsScreen(),
      SettingsScreen(client: _client),
    ];

    const currentTargetName = '💻 Desktop Engine';

    return Scaffold(
      body: Row(
        children: [
          // Desktop Linux Navigation Sidebar
          NavigationRail(
            backgroundColor: const Color(0xFF1E293B),
            minWidth: 88,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            indicatorColor: const Color(0xFF38BDF8),
            selectedIconTheme: const IconThemeData(color: Color(0xFF0F172A), size: 24),
            unselectedIconTheme: IconThemeData(color: Colors.grey.shade400, size: 22),
            selectedLabelTextStyle: const TextStyle(
              color: Color(0xFF38BDF8),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
            leading: Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.cloud_sync, color: Color(0xFF38BDF8), size: 26),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'unicSync',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: Color(0xFF0F172A)),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.folder_shared_outlined),
                selectedIcon: Icon(Icons.folder_shared, color: Color(0xFF0F172A)),
                label: Text('Files'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.cloud_outlined),
                selectedIcon: Icon(Icons.cloud, color: Color(0xFF0F172A)),
                label: Text('Profiles'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.terminal_outlined),
                selectedIcon: Icon(Icons.terminal, color: Color(0xFF0F172A)),
                label: Text('Logs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings, color: Color(0xFF0F172A)),
                label: Text('Settings'),
              ),
            ],
          ),

          const VerticalDivider(thickness: 1, width: 1, color: Color(0xFF334155)),

          // Selected Feature Screen with Engine Switcher Bar
          Expanded(
            child: Column(
              children: [
                // Top Multi-Engine Toolbar
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.device_hub, size: 16, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 8),
                      const Text(
                        'Target Engine:',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<DiscoveredEngine>(
                        tooltip: 'Switch Engine Target',
                        color: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFF334155)),
                        ),
                        onSelected: _switchEngine,
                        itemBuilder: (ctx) {
                          if (_engines.isEmpty) {
                            return [
                              const PopupMenuItem(
                                enabled: false,
                                child: Text('Probing engines...'),
                              ),
                            ];
                          }
                          return _engines.map((e) {
                            final isCurrent = e.baseUrl == _client.baseUrl;
                            return PopupMenuItem<DiscoveredEngine>(
                              value: e,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: e.isOnline ? Colors.greenAccent : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    e.name,
                                    style: TextStyle(
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                      color: isCurrent ? const Color(0xFF38BDF8) : Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    e.baseUrl.replaceAll('http://', ''),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currentTargetName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF38BDF8),
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF38BDF8)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 12, color: Colors.greenAccent),
                            SizedBox(width: 4),
                            Text(
                              'Daemon Active',
                              style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Active Endpoint Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lan_outlined, size: 12, color: Colors.tealAccent),
                            const SizedBox(width: 6),
                            Text(
                              _client.baseUrl,
                              style: const TextStyle(fontSize: 11, color: Colors.tealAccent, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
                        tooltip: 'Reconnect to Local Engine',
                        onPressed: _probeEngines,
                      ),
                    ],
                  ),
                ),
                Expanded(child: screens[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
