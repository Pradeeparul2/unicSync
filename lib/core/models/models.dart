import 'package:flutter/foundation.dart';

/// Storage tier for files in the storage tiering architecture.
enum StorageTier {
  local,
  synced,
  cloudOnly,
}

extension StorageTierExt on StorageTier {
  String get label {
    switch (this) {
      case StorageTier.local:
        return '💾 Local Buffer';
      case StorageTier.synced:
        return '✅ Synced';
      case StorageTier.cloudOnly:
        return '☁️ Cloud Only';
    }
  }

  static StorageTier fromString(String str) {
    switch (str.toLowerCase()) {
      case 'synced':
        return StorageTier.synced;
      case 'cloudonly':
      case 'cloud_only':
        return StorageTier.cloudOnly;
      default:
        return StorageTier.local;
    }
  }
}

/// Overall engine sync queue status.
@immutable
class SyncStatusModel {
  final int pendingFiles;
  final int uploadingFiles;
  final int completedFiles;
  final int failedFiles;
  final bool isOnline;
  final String activeProfile;
  final double uploadSpeedMBps;

  const SyncStatusModel({
    required this.pendingFiles,
    required this.uploadingFiles,
    required this.completedFiles,
    required this.failedFiles,
    required this.isOnline,
    required this.activeProfile,
    this.uploadSpeedMBps = 0.0,
  });

  factory SyncStatusModel.fromJson(Map<String, dynamic> json) {
    return SyncStatusModel(
      pendingFiles: (json['pending'] ?? json['pending_files'] ?? 0) as int,
      uploadingFiles: (json['uploading'] ?? json['uploading_files'] ?? 0) as int,
      completedFiles: (json['completed'] ?? json['completed_files'] ?? 0) as int,
      failedFiles: (json['failed'] ?? json['failed_files'] ?? 0) as int,
      isOnline: json['is_online'] ?? true,
      activeProfile: json['active_profile']?.toString() ?? 'default',
      uploadSpeedMBps: (json['speed_mbps'] as num?)?.toDouble() ?? 0.0,
    );
  }

  int get totalTracked => pendingFiles + uploadingFiles + completedFiles + failedFiles;
}

/// File metadata tracked by rSync SQLite store.
@immutable
class TrackedFileModel {
  final String fileId;
  final String relativePath;
  final int totalSize;
  final String status;
  final StorageTier tier;
  final DateTime updatedAt;
  final DateTime createdAt;

  const TrackedFileModel({
    required this.fileId,
    required this.relativePath,
    required this.totalSize,
    required this.status,
    required this.tier,
    required this.updatedAt,
    required this.createdAt,
  });

  factory TrackedFileModel.fromJson(Map<String, dynamic> json) {
    final rawCreated = json['created_at'];
    final rawUpdated = json['updated_at'];
    final size = json['size_bytes'] ?? json['total_size'] ?? 0;

    return TrackedFileModel(
      fileId: json['file_id']?.toString() ?? '',
      relativePath: json['path']?.toString() ?? json['relative_path']?.toString() ?? '',
      totalSize: size is num ? size.toInt() : (int.tryParse(size.toString()) ?? 0),
      status: json['status']?.toString() ?? 'unknown',
      tier: StorageTierExt.fromString(json['storage_tier']?.toString() ?? 'local'),
      updatedAt: rawUpdated != null
          ? (DateTime.tryParse(rawUpdated.toString()) ?? DateTime.now())
          : DateTime.now(),
      createdAt: rawCreated != null
          ? (DateTime.tryParse(rawCreated.toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    if (totalSize < 1024 * 1024 * 1024) return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Cloud destination profile.
@immutable
class CloudProfileModel {
  final String name;
  final String provider;
  final String destination;
  final bool isActive;
  final Map<String, dynamic> rawConfig;

  const CloudProfileModel({
    required this.name,
    required this.provider,
    required this.destination,
    required this.isActive,
    this.rawConfig = const {},
  });

  factory CloudProfileModel.fromJson(String name, Map<String, dynamic> json, bool isActive) {
    final type = (json['type']?.toString() ?? 'unknown').toLowerCase();
    String dest = '';
    if (type == 's3') {
      final bucket = json['bucket'] ?? '';
      final region = json['region'] ?? 'ap-south-1';
      final endpoint = json['endpoint_url'] ?? json['endpoint'] ?? '';
      dest = 's3://$bucket ($region)${endpoint.toString().isNotEmpty ? " • $endpoint" : ""}';
    } else if (type == 'webdav') {
      dest = json['endpoint_url'] ?? json['url'] ?? json['endpoint'] ?? '';
      final user = json['username'] ?? '';
      if (user.toString().isNotEmpty) {
        dest += ' ($user)';
      }
    } else if (type == 'gdrive' || type == 'google_drive') {
      dest = 'Folder: ${json['parent_folder_id'] ?? json['folder_id'] ?? 'root'}';
    } else {
      dest = 'Local In-Memory Mock';
    }

    return CloudProfileModel(
      name: name,
      provider: type == 'gdrive' ? 'GOOGLE DRIVE' : type.toUpperCase(),
      destination: dest,
      isActive: isActive,
      rawConfig: json,
    );
  }
}
