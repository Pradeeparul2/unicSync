import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single log line emitted by the rSync engine.
class EngineLogEntry {
  final DateTime timestamp;
  final String level;
  final String message;

  EngineLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  static final _ansiRegex = RegExp(r'\x1B\[[0-9;]*[a-zA-Z]|\x1B\([B0-9]');
  static final _fallbackAnsiRegex = RegExp(r'\[[0-9;]+m');
  static final _tracingRegex = RegExp(r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z?)\s+([A-Z]+)\s+(.*)$');

  factory EngineLogEntry.parse(String rawLine) {
    // 1. Strip ANSI escape sequences and colors
    final clean = rawLine.replaceAll(_ansiRegex, '').replaceAll(_fallbackAnsiRegex, '').trim();

    DateTime timestamp = DateTime.now();
    String level = 'INFO';
    String msg = clean;

    // 2. Check for structured tracing log format (e.g. 2026-11-06T17:13:10.354Z INFO target: msg)
    final match = _tracingRegex.firstMatch(clean);
    if (match != null) {
      final isoStr = match.group(1);
      final lvlStr = match.group(2);
      final rest = match.group(3) ?? '';

      if (isoStr != null) {
        try {
          timestamp = DateTime.parse(isoStr).toLocal();
        } catch (_) {}
      }
      if (lvlStr != null) {
        level = lvlStr.toUpperCase();
      }
      msg = rest;
    } else {
      // 3. Fallback level detection
      if (clean.contains('ERROR') || clean.contains('error:')) {
        level = 'ERROR';
      } else if (clean.contains('WARN') || clean.contains('warning:')) {
        level = 'WARN';
      } else if (clean.contains('DEBUG')) {
        level = 'DEBUG';
      }
    }

    return EngineLogEntry(timestamp: timestamp, level: level, message: msg);
  }
}

/// Manages installation, background execution, and lifecycle of the rSync sync-agent engine.
class EngineManager {
  static final EngineManager _instance = EngineManager._internal();
  factory EngineManager() => _instance;
  EngineManager._internal();

  Process? _process;
  bool _isRunning = false;
  int? _pid;
  DateTime? _startedAt;

  final List<EngineLogEntry> _logs = [];
  final _logStreamController = StreamController<EngineLogEntry>.broadcast();

  Stream<EngineLogEntry> get logStream => _logStreamController.stream;
  List<EngineLogEntry> get logs => List.unmodifiable(_logs);
  bool get isRunning => _isRunning;
  int? get pid => _pid;
  DateTime? get startedAt => _startedAt;

  Directory? _appDir;
  String? _binaryPath;
  String? _dbPath;
  String? _configDir;
  String? _logFilePath;
  String? _currentWatchPath;

  Timer? _logTailTimer;
  int _lastLogOffset = 0;

  String? get dbPath => _dbPath;
  String? get configDir => _configDir;
  String? get logFilePath => _logFilePath;
  String? get currentWatchPath => _currentWatchPath;

  /// Initialize application directories, verify/extract binary, and reconnect to any running daemon.
  Future<void> initialize() async {
    _appDir = await getApplicationSupportDirectory();
    final binDir = Directory('${_appDir!.path}/bin');
    final dataDir = Directory('${_appDir!.path}/data');
    final configDir = Directory('${_appDir!.path}/config');
    final logsDir = Directory('${_appDir!.path}/logs');

    await binDir.create(recursive: true);
    await dataDir.create(recursive: true);
    await configDir.create(recursive: true);
    await logsDir.create(recursive: true);

    final binaryName = Platform.isWindows ? 'sync-agent.exe' : 'sync-agent';
    _binaryPath = '${binDir.path}/$binaryName';
    _dbPath = '${dataDir.path}/sync.db';
    _configDir = configDir.path;
    _logFilePath = '${logsDir.path}/sync-agent.log';

    // 1. Check first if background sync-agent daemon is already running
    final status = await checkRunningEngine();
    if (status != null) {
      _addLog('INFO', 'Connected to existing background rSync daemon (PID: $_pid, Directory: $_currentWatchPath)');
    }

    // 2. Verify or extract binary (skip if daemon is already running and binary exists)
    final binaryFile = File(_binaryPath!);
    if (!binaryFile.existsSync()) {
      _addLog('INFO', 'Installing rSync engine to application storage: $_binaryPath');
      await _installBinary(binaryFile);
    } else if (status == null) {
      // Only refresh binary when engine is not actively executing
      await _installBinary(binaryFile);
      _addLog('INFO', 'rSync engine up to date at: $_binaryPath');
    }

    // 3. Load saved watch path
    final prefs = await SharedPreferences.getInstance();
    _currentWatchPath = prefs.getString('watch_path') ?? _currentWatchPath;
  }

  int _activePort = 8484;
  int get activePort => _activePort;

  /// Queries active engine port (checking engine.port file, then 8484, 8485, 8080).
  Future<Map<String, dynamic>?> checkRunningEngine({int? preferredPort}) async {
    int portToTry = preferredPort ?? _activePort;
    try {
      if (_configDir != null) {
        final portFile = File('$_configDir/engine.port');
        if (portFile.existsSync()) {
          final json = jsonDecode(portFile.readAsStringSync()) as Map;
          if (json.containsKey('port') && json['port'] is int) {
            portToTry = json['port'] as int;
          }
        }
      }
    } catch (_) {}

    final portsToProbe = [portToTry, 8484, 8485, 8080];
    final tried = <int>{};
    for (final p in portsToProbe) {
      if (tried.contains(p)) continue;
      tried.add(p);
      try {
        final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 700);
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:$p/api/status'));
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          _isRunning = true;
          _activePort = p;
          if (json.containsKey('pid') && json['pid'] is int) {
            _pid = json['pid'] as int;
          }
          if (json.containsKey('watch_path') && json['watch_path'] is String) {
            _currentWatchPath = json['watch_path'] as String;
          }
          _startLogTailing();
          return json;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _installBinary(File targetFile) async {
    final tempFile = File('${targetFile.path}.tmp');
    final assetBinaryPath = Platform.isWindows ? 'assets/bin/sync-agent.exe' : 'assets/bin/sync-agent';

    // 1. Try extracting from Flutter assets
    try {
      final ByteData data = await rootBundle.load(assetBinaryPath);
      final buffer = data.buffer;
      await tempFile.writeAsBytes(buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', tempFile.path]);
      }
      await tempFile.rename(targetFile.path);
      _addLog('INFO', 'Extracted bundled sync-agent asset successfully.');
      return;
    } catch (e) {
      _addLog('WARN', 'Bundled asset extraction issue ($e), checking local repository builds...');
      try {
        if (tempFile.existsSync()) await tempFile.delete();
      } catch (_) {}
    }

    // 2. Fallback: check sibling rSync build
    final candidatePaths = [
      if (Platform.isWindows) ...[
        r'..\rSync\target\release\sync-agent.exe',
        r'..\rSync\target\debug\sync-agent.exe',
        r'C:\rSync\target\release\sync-agent.exe',
      ] else ...[
        '/home/pradeep/Documents/rSync/target/release/sync-agent',
        '/home/pradeep/Documents/rSync/target/debug/sync-agent',
        '/usr/local/bin/sync-agent',
      ],
    ];

    for (final candidate in candidatePaths) {
      try {
        final candFile = File(candidate);
        if (candFile.existsSync()) {
          await candFile.copy(tempFile.path);
          if (!Platform.isWindows) {
            await Process.run('chmod', ['+x', tempFile.path]);
          }
          await tempFile.rename(targetFile.path);
          _addLog('INFO', 'Copied sync-agent from $candidate to ${targetFile.path}');
          return;
        }
      } catch (e) {
        _addLog('WARN', 'Failed to copy candidate $candidate: $e');
        try {
          if (tempFile.existsSync()) await tempFile.delete();
        } catch (_) {}
      }
    }

    if (!targetFile.existsSync()) {
      _addLog('ERROR', 'Could not locate sync-agent executable during installation!');
    }
  }

  /// Launch the sync-agent engine in detached mode so it stays running in the background.
  Future<bool> start(String targetPath) async {
    // First, check if already running on port 8080/8484
    final status = await checkRunningEngine();
    if (status != null) {
      if (_currentWatchPath == targetPath) {
        _addLog('INFO', 'Engine already running in background on: $targetPath (PID: $_pid)');
        return true;
      } else {
        _addLog('INFO', 'Switching watch directory from $_currentWatchPath to $targetPath...');
        await stop();
      }
    }

    final targetDir = Directory(targetPath);
    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }

    _currentWatchPath = targetPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('watch_path', targetPath);

    _addLog('INFO', 'Starting background rSync engine on watch directory: $targetPath');
    _addLog('INFO', 'State database: $_dbPath');
    _addLog('INFO', 'Profiles config directory: $_configDir');
    _addLog('INFO', 'Log file: $_logFilePath');

    final logFile = File(_logFilePath!);
    if (!logFile.existsSync()) {
      await logFile.create(recursive: true);
    }

    try {
      // Launch detached so sync-agent continues running after closing the Flutter window
      if (Platform.isWindows) {
        _process = await Process.start(
          'cmd.exe',
          [
            '/c',
            '""$_binaryPath" --db "$_dbPath" watch --path "$targetPath" --web-port 8484 >> "$_logFilePath" 2>&1"',
          ],
          environment: {
            'RSYNC_CONFIG_DIR': _configDir!,
            'RSYNC_DB_PATH': _dbPath!,
          },
          mode: ProcessStartMode.detached,
        );
      } else {
        _process = await Process.start(
          'sh',
          [
            '-c',
            'exec "\$0" "\$@" >> "$_logFilePath" 2>&1',
            _binaryPath!,
            '--db',
            _dbPath!,
            'watch',
            '--path',
            targetPath,
            '--web-port',
            '8484',
          ],
          environment: {
            'RSYNC_CONFIG_DIR': _configDir!,
            'RSYNC_DB_PATH': _dbPath!,
          },
          mode: ProcessStartMode.detached,
        );
      }

      // Poll until the engine web API becomes active (up to 5 seconds)
      for (int i = 0; i < 12; i++) {
        await Future.delayed(const Duration(milliseconds: 400));
        final activeStatus = await checkRunningEngine();
        if (activeStatus != null) {
          _isRunning = true;
          _startedAt = DateTime.now();
          _startLogTailing();
          _addLog('INFO', 'rSync engine daemon active in background (PID: $_pid)');
          return true;
        }
      }

      _addLog('WARN', 'rSync daemon launched but did not respond to status endpoint in time.');
      return true;
    } catch (e) {
      _addLog('ERROR', 'Failed to launch background rSync engine process: $e');
      _isRunning = false;
      return false;
    }
  }

  /// Stop the engine process gracefully via API and OS signal.
  Future<void> stop() async {
    _addLog('INFO', 'Stopping rSync engine daemon (PID: $_pid)...');
    _stopLogTailing();

    // 1. Send graceful shutdown HTTP request
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
      final req = await client.postUrl(Uri.parse('http://127.0.0.1:$_activePort/api/shutdown'));
      await req.close();
    } catch (_) {}

    // 2. Terminate PID if still alive
    if (_pid != null) {
      try {
        if (Platform.isWindows) {
          Process.killPid(_pid!);
          await Process.run('taskkill', ['/F', '/T', '/PID', '$_pid']);
        } else {
          Process.killPid(_pid!, ProcessSignal.sigterm);
          await Future.delayed(const Duration(milliseconds: 300));
          Process.killPid(_pid!, ProcessSignal.sigkill);
        }
      } catch (_) {}
    }

    if (_process != null) {
      if (Platform.isWindows) {
        _process?.kill();
      } else {
        _process?.kill(ProcessSignal.sigterm);
      }
      _process = null;
    }

    _isRunning = false;
    _pid = null;
    _addLog('INFO', 'rSync engine stopped.');
  }

  /// Restart the engine.
  Future<void> restart() async {
    if (_currentWatchPath != null) {
      await stop();
      await Future.delayed(const Duration(milliseconds: 800));
      await start(_currentWatchPath!);
    }
  }

  void _startLogTailing() {
    if (_logTailTimer != null && _logTailTimer!.isActive) return;
    if (_logFilePath == null) return;

    final file = File(_logFilePath!);
    if (file.existsSync()) {
      try {
        final length = file.lengthSync();
        // If logs list is empty, read the recent ~200 lines
        if (_logs.isEmpty && length > 0) {
          final startPos = length > 65536 ? length - 65536 : 0;
          final raf = file.openSync(mode: FileMode.read);
          raf.setPositionSync(startPos);
          final bytes = raf.readSync(length - startPos);
          raf.closeSync();
          final text = utf8.decode(bytes, allowMalformed: true);
          for (final line in const LineSplitter().convert(text)) {
            if (line.trim().isNotEmpty) {
              _logs.add(EngineLogEntry.parse(line));
            }
          }
        }
        _lastLogOffset = length;
      } catch (_) {}
    }

    _logTailTimer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      if (_logFilePath == null) return;
      final f = File(_logFilePath!);
      if (!f.existsSync()) return;

      try {
        final length = await f.length();
        if (length > _lastLogOffset) {
          final raf = await f.open(mode: FileMode.read);
          await raf.setPosition(_lastLogOffset);
          final bytes = await raf.read(length - _lastLogOffset);
          await raf.close();
          _lastLogOffset = length;

          final text = utf8.decode(bytes, allowMalformed: true);
          for (final line in const LineSplitter().convert(text)) {
            if (line.trim().isNotEmpty) {
              _addLogEntry(EngineLogEntry.parse(line));
            }
          }
        } else if (length < _lastLogOffset) {
          _lastLogOffset = 0;
        }
      } catch (_) {}
    });
  }

  void _stopLogTailing() {
    _logTailTimer?.cancel();
    _logTailTimer = null;
  }

  void _addLog(String level, String message) {
    _addLogEntry(EngineLogEntry(timestamp: DateTime.now(), level: level, message: message));
  }

  void _addLogEntry(EngineLogEntry entry) {
    _logs.add(entry);
    if (_logs.length > 2000) _logs.removeAt(0); // rolling buffer
    _logStreamController.add(entry);
  }

  void clearLogs() {
    _logs.clear();
  }
}
