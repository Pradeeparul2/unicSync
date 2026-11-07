import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/models.dart';

/// Target engine types for multi-engine companion workflows.
enum EngineTarget {
  localPc,
  usbDrive,
  smartDrive,
}

/// Metadata describing a discovered rSync engine instance.
class DiscoveredEngine {
  final EngineTarget target;
  final String name;
  final String baseUrl;
  final bool isOnline;
  final int? pid;
  final String? watchPath;

  DiscoveredEngine({
    required this.target,
    required this.name,
    required this.baseUrl,
    required this.isOnline,
    this.pid,
    this.watchPath,
  });
}

/// Client to communicate with the rSync sync-agent daemon on desktop or USB Smart Drive.
class SyncApiClient {
  final Dio _dio;
  String baseUrl;
  EngineTarget currentTarget = EngineTarget.localPc;
  String? _pin;
  String? _sessionToken;

  String? get pin => _pin;
  String? get sessionToken => _sessionToken;

  SyncApiClient({this.baseUrl = 'http://127.0.0.1:8484'})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 5),
          headers: {'Content-Type': 'application/json'},
        ));

  /// Switches active communication target to a different engine (e.g. Local PC or USB Drive).
  void setBaseUrl(String newUrl, {EngineTarget? target}) {
    baseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
    if (target != null) {
      currentTarget = target;
    }
  }

  void setPin(String? pin) {
    _pin = pin;
    if (pin != null && pin.isNotEmpty) {
      _dio.options.headers['X-Pin'] = pin;
    } else {
      _dio.options.headers.remove('X-Pin');
    }
  }

  void setSessionToken(String? token) {
    _sessionToken = token;
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  Future<bool> authenticate(String pin) async {
    try {
      final res = await _dio.post('/api/auth', data: {'pin': pin});
      if (res.statusCode == 200 && res.data['authenticated'] == true) {
        final token = res.data['token']?.toString();
        if (token != null) {
          setSessionToken(token);
        }
        setPin(pin);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Probes for active engines (Local PC, USB Drive on host, Smart Drive hardware).
  /// Only returns engines that are currently ONLINE and available.
  Future<List<DiscoveredEngine>> detectAvailableEngines() async {
    final candidates = <Map<String, dynamic>>[
      {'target': EngineTarget.localPc, 'name': '💻 Local PC Drive', 'url': 'http://127.0.0.1:8484'},
      {'target': EngineTarget.usbDrive, 'name': '💾 USB Pendrive (Host)', 'url': 'http://127.0.0.1:8485'},
      {'target': EngineTarget.smartDrive, 'name': '⚡ USB-C Smart Drive', 'url': 'http://192.168.7.2:8484'},
    ];

    // 1. Read desktop engine config storage place if available
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      final configPortFiles = [
        '$home/.local/share/com.rsync.unic_sync/config/engine.port',
        '$home/.config/rsync/engine.port',
        if (Platform.isWindows) ...[
          '$home/AppData/Roaming/com.rsync.unic_sync/config/engine.port',
          '$home/AppData/Local/com.rsync.unic_sync/config/engine.port',
        ],
      ];
      for (final cp in configPortFiles) {
        try {
          final file = File(cp);
          if (file.existsSync()) {
            final json = jsonDecode(file.readAsStringSync()) as Map;
            final port = json['port'];
            if (port is int) {
              candidates.insert(0, {
                'target': EngineTarget.localPc,
                'name': '💻 Local PC Drive',
                'url': 'http://127.0.0.1:$port',
              });
            }
          }
        } catch (_) {}
      }
    }

    // 2. Auto-detect mounted removable drives with config storage (.rsync/engine.port)
    final potentialMountedDirs = <String>[];
    final user = Platform.environment['USER'] ?? Platform.environment['USERNAME'];
    if (user != null) {
      potentialMountedDirs.add('/media/$user');
      potentialMountedDirs.add('/run/media/$user');
    }
    potentialMountedDirs.add('/media');
    if (Platform.isMacOS) {
      potentialMountedDirs.add('/Volumes');
    }
    if (Platform.isWindows) {
      for (final letter in ['D', 'E', 'F', 'G', 'H', 'U']) {
        potentialMountedDirs.add('$letter:\\');
      }
    }

    for (final base in potentialMountedDirs) {
      try {
        final dir = Directory(base);
        if (dir.existsSync()) {
          for (final entity in dir.listSync()) {
            if (entity is Directory) {
              final portFiles = [
                File('${entity.path}/.rsync/engine.port'),
                File('${entity.path}/config/engine.port'),
              ];
              for (final portFile in portFiles) {
                if (portFile.existsSync()) {
                  final json = jsonDecode(portFile.readAsStringSync()) as Map;
                  final port = json['port'];
                  if (port is int && port != 8484 && port != 8485) {
                    final driveName = entity.path.split('/').last;
                    candidates.add({
                      'target': EngineTarget.usbDrive,
                      'name': '💾 $driveName (USB)',
                      'url': 'http://127.0.0.1:$port',
                    });
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    final onlineEngines = <DiscoveredEngine>[];
    final seenUrls = <String>{};

    for (final c in candidates) {
      final url = c['url'] as String;
      if (seenUrls.contains(url)) continue;
      seenUrls.add(url);

      final target = c['target'] as EngineTarget;
      final name = c['name'] as String;

      try {
        final res = await Dio().get(
          '$url/api/status',
          options: Options(receiveTimeout: const Duration(milliseconds: 600)),
        );
        if (res.statusCode == 200 && res.data is Map) {
          final data = res.data as Map;
          onlineEngines.add(DiscoveredEngine(
            target: target,
            name: name,
            baseUrl: url,
            isOnline: true,
            pid: data['pid'] is int ? data['pid'] as int : null,
            watchPath: data['watch_dir']?.toString(),
          ));
        }
      } catch (_) {}
    }

    return onlineEngines;
  }

  /// Auto-detect whether sync-agent is on localhost (8484), secondary USB engine (8485), or USB-C Smart Drive (192.168.7.2).
  Future<String> autoDetectServer() async {
    for (final host in ['http://127.0.0.1:8484', 'http://127.0.0.1:8485', 'http://192.168.7.2:8484']) {
      try {
        final res = await Dio().get('$host/api/status', options: Options(receiveTimeout: const Duration(milliseconds: 800)));
        if (res.statusCode == 200) {
          baseUrl = host;
          _dio.options.baseUrl = host;
          return host;
        }
      } catch (_) {}
    }
    return baseUrl;
  }

  /// Get real-time sync queue status.
  Future<SyncStatusModel> getStatus() async {
    final res = await _dio.get('/api/status');
    return SyncStatusModel.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// Get list of all tracked files and storage tiers.
  Future<List<TrackedFileModel>> getFiles() async {
    final res = await _dio.get('/api/files');
    final dynamic data = res.data;
    final List list;
    if (data is List) {
      list = data;
    } else if (data is Map && data.containsKey('files') && data['files'] is List) {
      list = data['files'] as List;
    } else {
      list = [];
    }
    return list.map((e) => TrackedFileModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Evict a local file payload (Infinite USB Drive tiering).
  Future<bool> evictFile(String fileId, {String? path}) async {
    final res = await _dio.post('/api/evict', data: {
      'file_id': fileId,
      if (path != null) 'path': path,
    });
    return res.statusCode == 200;
  }

  /// Hydrate (download) a CloudOnly file back to physical storage.
  Future<bool> hydrateFile(String fileId, {String? path}) async {
    final res = await _dio.post(
      '/api/hydrate',
      data: {
        'file_id': fileId,
        if (path != null) 'path': path,
      },
      options: Options(
        receiveTimeout: const Duration(minutes: 15),
        sendTimeout: const Duration(minutes: 2),
      ),
    );
    return res.statusCode == 200;
  }

  /// Run an automatic LRU eviction pass freeing up target megabytes.
  Future<int> autoEvict({int targetFreeMB = 1024}) async {
    final res = await _dio.post(
      '/api/evict/auto',
      data: {'target_free_mb': targetFreeMB},
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
    return res.data['evicted_count'] ?? 0;
  }

  /// Trigger remote cloud bucket discovery and catalog import.
  Future<int> importFromCloud() async {
    final res = await _dio.post(
      '/api/cloud/import',
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
    return res.data['imported_count'] ?? 0;
  }

  /// Download all cloud files back onto the physical drive.
  Future<bool> restoreAll() async {
    final res = await _dio.post(
      '/api/restore/all',
      options: Options(
        receiveTimeout: const Duration(minutes: 30),
        sendTimeout: const Duration(minutes: 2),
      ),
    );
    return res.statusCode == 200;
  }

  /// Request the background rSync daemon to shut down cleanly.
  Future<bool> shutdownDaemon() async {
    try {
      final res = await _dio.post('/api/shutdown');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get all configured cloud destination profiles.
  Future<List<CloudProfileModel>> getProfiles() async {
    final res = await _dio.get('/api/profiles');
    final dynamic data = res.data;
    if (data is! Map) return [];
    final active = data['active_profile'] ?? data['default_profile'] ?? '';
    final Map<String, dynamic> profiles =
        data['profiles'] is Map ? Map<String, dynamic>.from(data['profiles'] as Map) : {};

    return profiles.entries.map((entry) {
      return CloudProfileModel.fromJson(entry.key, entry.value as Map<String, dynamic>, entry.key == active);
    }).toList();
  }

  /// Switch active cloud destination profile.
  Future<bool> setActiveProfile(String name) async {
    final res = await _dio.post('/api/profiles/active', data: {'name': name});
    return res.statusCode == 200;
  }

  /// Add or update a cloud storage destination profile.
  Future<bool> saveProfile(Map<String, dynamic> profileData) async {
    final res = await _dio.post('/api/profiles/save', data: profileData);
    return res.statusCode == 200;
  }

  /// Remove a configured cloud profile by name.
  Future<bool> deleteProfile(String name) async {
    final res = await _dio.post('/api/profiles/delete', data: {'name': name});
    return res.statusCode == 200;
  }

  /// Delete a file permanently from local disk, state tracking, and remote cloud destination.
  Future<bool> deleteFile(String fileId, {String? path}) async {
    try {
      final res = await _dio.post('/api/files/delete', data: {
        'file_id': fileId,
        'path': path,
      });
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch engine settings (active profile, deletion policy, PIN protection status).
  Future<Map<String, dynamic>?> getSettings() async {
    try {
      final res = await _dio.get('/api/settings');
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Update deletion policy (keep_cloud, remove_both, local_only).
  Future<bool> setDeletionPolicy(String policy) async {
    try {
      final res = await _dio.post('/api/settings', data: {
        'deletion_policy': policy,
        'policy': policy,
      });
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Update device security PIN code.
  Future<bool> updatePin({String? oldPin, required String newPin}) async {
    final res = await _dio.post('/api/settings/pin', data: {
      'current_pin': oldPin,
      'old_pin': oldPin,
      'new_pin': newPin,
    });
    return res.statusCode == 200;
  }
}
