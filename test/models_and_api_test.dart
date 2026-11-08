import 'package:flutter_test/flutter_test.dart';
import 'package:unic_sync/core/models/models.dart';
import 'package:unic_sync/core/engine/engine_manager.dart';

void main() {
  group('StorageTier Model Tests', () {
    test('StorageTier label and conversion', () {
      expect(StorageTier.local.label, contains('Local'));
      expect(StorageTier.synced.label, contains('Synced'));
      expect(StorageTier.cloudOnly.label, contains('Cloud Only'));

      expect(StorageTierExt.fromString('synced'), StorageTier.synced);
      expect(StorageTierExt.fromString('cloudonly'), StorageTier.cloudOnly);
      expect(StorageTierExt.fromString('cloud_only'), StorageTier.cloudOnly);
      expect(StorageTierExt.fromString('local'), StorageTier.local);
      expect(StorageTierExt.fromString('unknown'), StorageTier.local);
    });
  });

  group('TrackedFileModel Tests', () {
    test('TrackedFileModel deserialization from engine JSON', () {
      final json = {
        'file_id': 'abc-123',
        'path': 'subfolder/video.mp4',
        'size_bytes': 10485760,
        'status': 'COMPLETED',
        'storage_tier': 'SYNCED',
        'created_at': '2026-11-08T10:00:00Z',
        'updated_at': '2026-11-08T10:05:00Z',
      };

      final file = TrackedFileModel.fromJson(json);
      expect(file.fileId, 'abc-123');
      expect(file.relativePath, 'subfolder/video.mp4');
      expect(file.totalSize, 10485760);
      expect(file.status, 'COMPLETED');
      expect(file.tier, StorageTier.synced);
      expect(file.formattedSize, '10.0 MB');
    });

    test('TrackedFileModel CloudOnly detection', () {
      final json = {
        'file_id': 'cloud-456',
        'relative_path': 'archive/photo.raw',
        'size_bytes': 52428800,
        'status': 'COMPLETED',
        'storage_tier': 'CLOUDONLY',
      };

      final file = TrackedFileModel.fromJson(json);
      expect(file.tier, StorageTier.cloudOnly);
      expect(file.formattedSize, '50.0 MB');
    });

    test('TrackedFileModel local buffer and active uploading states', () {
      final queuedJson = {
        'file_id': 'vid-1',
        'relative_path': 'clip1.mp4',
        'size_bytes': 20971520,
        'status': 'QUEUED',
        'storage_tier': 'LOCAL',
        'completed_parts': 0,
        'total_parts': 4,
      };
      final queuedFile = TrackedFileModel.fromJson(queuedJson);
      expect(queuedFile.isQueued, isTrue);
      expect(queuedFile.isUploading, isFalse);
      expect(queuedFile.tier, StorageTier.local);

      final uploadingJson = {
        'file_id': 'vid-2',
        'relative_path': 'clip2.mp4',
        'size_bytes': 20971520,
        'status': 'UPLOADING',
        'storage_tier': 'LOCAL',
        'completed_parts': 1,
        'total_parts': 4,
      };
      final uploadingFile = TrackedFileModel.fromJson(uploadingJson);
      expect(uploadingFile.isUploading, isTrue);
      expect(uploadingFile.isQueued, isFalse);
      expect(uploadingFile.completedParts, 1);
      expect(uploadingFile.totalParts, 4);
    });
  });

  group('SyncStatusModel Tests', () {
    test('SyncStatusModel deserialization and metrics', () {
      final json = {
        'pending': 3,
        'uploading': 1,
        'completed': 42,
        'failed': 0,
        'is_online': true,
        'active_profile': 's3-backup',
        'speed_mbps': 12.5,
      };

      final status = SyncStatusModel.fromJson(json);
      expect(status.pendingFiles, 3);
      expect(status.uploadingFiles, 1);
      expect(status.completedFiles, 42);
      expect(status.failedFiles, 0);
      expect(status.totalTracked, 46);
      expect(status.isOnline, isTrue);
      expect(status.activeProfile, 's3-backup');
      expect(status.uploadSpeedMBps, 12.5);
    });
  });

  group('EngineLogEntry Parsing Tests', () {
    test('EngineLogEntry strips ANSI color codes', () {
      const rawLine = '\x1B[32m2026-11-08T12:00:00Z INFO watcher: Event processed\x1B[0m';
      final entry = EngineLogEntry.parse(rawLine);
      expect(entry.level, 'INFO');
      expect(entry.message, contains('watcher: Event processed'));
      expect(entry.message, isNot(contains('\x1B')));
    });

    test('EngineLogEntry parses ERROR and WARN levels correctly', () {
      final errorEntry = EngineLogEntry.parse('2026-11-08T12:00:00Z ERROR pipeline: Transfer failed');
      expect(errorEntry.level, 'ERROR');

      final warnEntry = EngineLogEntry.parse('2026-11-08T12:00:00Z WARN network: Flapping detected');
      expect(warnEntry.level, 'WARN');
    });
  });
}
