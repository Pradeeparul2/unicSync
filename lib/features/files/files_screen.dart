import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/api/sync_api_client.dart';
import '../../core/models/models.dart';

class FilesScreen extends StatefulWidget {
  final SyncApiClient client;

  const FilesScreen({super.key, required this.client});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<TrackedFileModel> _files = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  StorageTier? _selectedTierFilter;
  Timer? _pollTimer;
  final Set<String> _processingFileIds = {};

  @override
  void initState() {
    super.initState();
    _fetchFiles();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _silentRefresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final files = await widget.client.getFiles();
      if (mounted) {
        setState(() {
          _files = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final files = await widget.client.getFiles();
      if (mounted) {
        setState(() {
          _files = files;
          _errorMessage = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleEvict(TrackedFileModel file) async {
    setState(() => _processingFileIds.add(file.fileId));
    try {
      final success = await widget.client.evictFile(file.fileId, path: file.relativePath);
      if (success) {
        await _fetchFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Local space freed for '${file.relativePath}'. Safe in cloud."),
              backgroundColor: Colors.teal,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not free up space. File may not be fully synced.')),
          );
        }
      }
    } catch (e) {
      String msg = 'Failed to free up space.';
      if (e is DioException) {
        if (e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.connectionTimeout) {
          msg = 'Request timed out. The operation is taking longer than expected.';
        } else {
          final err = e.response?.data;
          if (err is Map && err.containsKey('error')) {
            msg = err['error'].toString();
          } else {
            msg = e.message ?? e.toString();
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _processingFileIds.remove(file.fileId));
    }
  }

  Future<void> _handleDelete(TrackedFileModel file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete File Everywhere?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          "Permanently delete '${file.relativePath}' from local storage and your remote cloud destination?",
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Everywhere'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingFileIds.add(file.fileId));
    try {
      final success = await widget.client.deleteFile(file.fileId, path: file.relativePath);
      if (success) {
        await _fetchFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Deleted '${file.relativePath}' locally and from cloud."),
              backgroundColor: Colors.teal,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete file from cloud destination.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _processingFileIds.remove(file.fileId));
    }
  }

  Future<void> _handleHydrate(TrackedFileModel file) async {
    setState(() => _processingFileIds.add(file.fileId));
    try {
      final success = await widget.client.hydrateFile(file.fileId, path: file.relativePath);
      if (success) {
        await _fetchFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Restored '${file.relativePath}' to local storage."),
              backgroundColor: Colors.teal,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to restore file from cloud.')),
          );
        }
      }
    } catch (e) {
      String msg = 'Failed to restore file.';
      if (e is DioException) {
        if (e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.connectionTimeout) {
          msg = "Download timed out. The file may be large or the cloud network connection is slow.";
        } else {
          final err = e.response?.data;
          if (err is Map && err.containsKey('error')) {
            msg = err['error'].toString();
          } else {
            msg = e.message ?? e.toString();
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _processingFileIds.remove(file.fileId));
    }
  }

  Future<void> _promptPinDialog() async {
    final pinController = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Unlock Device / Engine'),
        content: TextField(
          controller: pinController,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Enter 4-8 Digit PIN',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, pinController.text.trim()),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (pin != null && pin.isNotEmpty) {
      final success = await widget.client.authenticate(pin);
      if (success) {
        _fetchFiles();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid PIN. Please try again.')),
          );
        }
      }
    }
  }

  List<TrackedFileModel> get _filteredFiles {
    return _files.where((f) {
      final matchesSearch = f.relativePath.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesTier = _selectedTierFilter == null || f.tier == _selectedTierFilter;
      return matchesSearch && matchesTier;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Search and Filter
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search files across local drive and cloud...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 16),
              IconButton.filledTonal(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh Files',
                onPressed: _fetchFiles,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Tier Filter Chips
          Row(
            children: [
              _buildFilterChip('All Files (${_files.length})', null),
              const SizedBox(width: 10),
              _buildFilterChip('💾 Local (${_files.where((f) => f.tier == StorageTier.local).length})', StorageTier.local),
              const SizedBox(width: 10),
              _buildFilterChip('✅ Synced (${_files.where((f) => f.tier == StorageTier.synced).length})', StorageTier.synced),
              const SizedBox(width: 10),
              _buildFilterChip('☁️ Cloud Only (${_files.where((f) => f.tier == StorageTier.cloudOnly).length})', StorageTier.cloudOnly),
            ],
          ),

          const SizedBox(height: 20),

          // File List Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _errorMessage!.contains('401') ? Icons.lock_outline : Icons.error_outline,
                              size: 48,
                              color: _errorMessage!.contains('401') ? Colors.amberAccent : Colors.redAccent,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!.contains('401')
                                  ? 'PIN Authentication Required'
                                  : 'Failed to load files: $_errorMessage',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _errorMessage!.contains('401') ? _promptPinDialog : _fetchFiles,
                              icon: Icon(_errorMessage!.contains('401') ? Icons.key : Icons.refresh),
                              label: Text(_errorMessage!.contains('401') ? 'Enter PIN' : 'Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredFiles.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty ? 'No files tracked yet.' : 'No files matching "$_searchQuery"',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          )
                        : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: ListView.separated(
                          itemCount: _filteredFiles.length,
                          separatorBuilder: (_, __) => const Divider(color: Color(0xFF334155), height: 1),
                          itemBuilder: (context, index) {
                            final file = _filteredFiles[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              leading: Icon(_getFileIcon(file.relativePath), color: const Color(0xFF38BDF8), size: 24),
                              title: Text(file.relativePath, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                _buildFileSubtitle(file),
                                style: TextStyle(
                                  color: file.isUploading
                                      ? const Color(0xFF38BDF8)
                                      : Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildStatusBadge(file),
                                  const SizedBox(width: 12),
                                  if (file.tier == StorageTier.synced)
                                    OutlinedButton.icon(
                                      icon: _processingFileIds.contains(file.fileId)
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
                                            )
                                          : const Icon(Icons.cloud_sync, size: 14),
                                      label: Text(
                                        _processingFileIds.contains(file.fileId) ? 'Freeing...' : 'Free Up Space',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.amberAccent,
                                        side: const BorderSide(color: Colors.amberAccent),
                                      ),
                                      onPressed: _processingFileIds.contains(file.fileId)
                                          ? null
                                          : () => _handleEvict(file),
                                    ),
                                  if (file.tier == StorageTier.cloudOnly)
                                    OutlinedButton.icon(
                                      icon: _processingFileIds.contains(file.fileId)
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                                            )
                                          : const Icon(Icons.cloud_download_outlined, size: 14),
                                      label: Text(
                                        _processingFileIds.contains(file.fileId) ? 'Restoring...' : 'Restore',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF38BDF8),
                                        side: const BorderSide(color: Color(0xFF38BDF8)),
                                      ),
                                      onPressed: _processingFileIds.contains(file.fileId)
                                          ? null
                                          : () => _handleHydrate(file),
                                    ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    tooltip: 'Delete Everywhere',
                                    onPressed: _processingFileIds.contains(file.fileId)
                                        ? null
                                        : () => _handleDelete(file),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, StorageTier? tier) {
    final isSelected = _selectedTierFilter == tier;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedTierFilter = tier),
      selectedColor: const Color(0xFF38BDF8).withOpacity(0.2),
      backgroundColor: const Color(0xFF1E293B),
      side: BorderSide(color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF38BDF8) : Colors.grey.shade300,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildStatusBadge(TrackedFileModel file) {
    if (file.isUploading) {
      final partInfo = file.totalParts > 0
          ? ' (${file.completedParts + 1}/${file.totalParts})'
          : '';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF38BDF8).withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
            ),
            const SizedBox(width: 6),
            Text(
              '⏳ Uploading$partInfo',
              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (file.isFailed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
        ),
        child: const Text('⚠️ Failed', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }

    Color bg;
    Color fg;
    String label;

    switch (file.tier) {
      case StorageTier.synced:
        bg = Colors.green.withOpacity(0.15);
        fg = Colors.greenAccent;
        label = '✅ Synced';
        break;
      case StorageTier.cloudOnly:
        bg = Colors.blue.withOpacity(0.15);
        fg = Colors.lightBlueAccent;
        label = '☁️ Cloud Only';
        break;
      case StorageTier.local:
        bg = Colors.cyan.withOpacity(0.15);
        fg = Colors.cyanAccent;
        label = '💾 Local Buffer';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: fg.withOpacity(0.3))),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _buildFileSubtitle(TrackedFileModel file) {
    final sizeStr = file.formattedSize;
    if (file.isUploading) {
      if (file.totalParts > 0) {
        return '$sizeStr • Uploading chunk ${file.completedParts + 1} of ${file.totalParts}...';
      }
      return '$sizeStr • Uploading to cloud...';
    } else if (file.isQueued) {
      return '$sizeStr • Queued in local buffer';
    } else if (file.tier == StorageTier.synced) {
      return '$sizeStr • Synced to cloud';
    } else if (file.tier == StorageTier.cloudOnly) {
      return '$sizeStr • Stored in cloud (dataless)';
    } else if (file.isFailed) {
      return '$sizeStr • Upload failed (will retry)';
    }
    return '$sizeStr • Modified: ${_formatDate(file.updatedAt)}';
  }

  IconData _getFileIcon(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'mkv', 'avi'].contains(ext)) return Icons.movie_outlined;
    if (['jpg', 'jpeg', 'png', 'raw', 'cr3', 'dng'].contains(ext)) return Icons.image_outlined;
    if (['zip', 'tar', 'gz', '7z'].contains(ext)) return Icons.archive_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
