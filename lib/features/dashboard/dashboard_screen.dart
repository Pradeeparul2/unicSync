import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/sync_api_client.dart';
import '../../core/models/models.dart';

class DashboardScreen extends StatefulWidget {
  final SyncApiClient client;
  final VoidCallback onNavigateToFiles;

  const DashboardScreen({
    super.key,
    required this.client,
    required this.onNavigateToFiles,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SyncStatusModel? _status;
  List<TrackedFileModel> _files = [];
  bool _isLoading = true;
  String _activeServer = 'Connecting...';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _silentRefresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    await widget.client.autoDetectServer();
    try {
      final status = await widget.client.getStatus();
      final files = await widget.client.getFiles();
      if (mounted) {
        setState(() {
          _activeServer = Platform.isWindows ? 'Windows Desktop Engine' : 'Linux Desktop Engine';
          _status = status;
          _files = files;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final status = await widget.client.getStatus();
      final files = await widget.client.getFiles();
      if (mounted) {
        setState(() {
          _status = status;
          _files = files;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)));
    }

    final localCount = _files.where((f) => f.tier == StorageTier.local).length;
    final syncedCount = _files.where((f) => f.tier == StorageTier.synced).length;
    final cloudOnlyCount = _files.where((f) => f.tier == StorageTier.cloudOnly).length;

    // Calculate disk space metrics
    final localBytes = _files.where((f) => f.tier != StorageTier.cloudOnly).fold<int>(0, (sum, f) => sum + f.totalSize);
    final totalCloudBytes = _files.fold<int>(0, (sum, f) => sum + f.totalSize);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard Overview', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: (_status?.isOnline ?? false) ? Colors.greenAccent : Colors.amberAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Target: $_activeServer • Profile: ${_status?.activeProfile ?? "default"}',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                onPressed: _loadDashboardData,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 4 Status Cards
          Row(
            children: [
              _buildMetricCard('Synced Files', '${_status?.completedFiles ?? 0}', Icons.check_circle_outline, Colors.green),
              const SizedBox(width: 16),
              _buildMetricCard('Active Uploads', '${_status?.uploadingFiles ?? 0}', Icons.cloud_upload_outlined, const Color(0xFF38BDF8)),
              const SizedBox(width: 16),
              _buildMetricCard('Pending Queue', '${_status?.pendingFiles ?? 0}', Icons.schedule, Colors.amber),
              const SizedBox(width: 16),
              _buildMetricCard('Failed / Retry', '${_status?.failedFiles ?? 0}', Icons.warning_amber_rounded, Colors.redAccent),
            ],
          ),

          const SizedBox(height: 24),

          // Infinite Storage Tiering Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storage, color: Color(0xFF38BDF8), size: 24),
                        const SizedBox(width: 12),
                        Text('Infinite USB Storage Tiering', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Manage Files'),
                      onPressed: widget.onNavigateToFiles,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Physical local cache: ${(localBytes / (1024 * 1024)).toStringAsFixed(1)} MB used across ${localCount + syncedCount} files. '
                  'Virtual Cloud Library: ${(totalCloudBytes / (1024 * 1024)).toStringAsFixed(1)} MB across ${_files.length} files ($cloudOnlyCount files space-saved).',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildTierPill('💾 $localCount Buffering', Colors.cyan),
                    const SizedBox(width: 12),
                    _buildTierPill('✅ $syncedCount Cached', Colors.green),
                    const SizedBox(width: 12),
                    _buildTierPill('☁️ $cloudOnlyCount Cloud Only (Dataless)', const Color(0xFF38BDF8)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action Toolbar
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  title: 'Discover Cloud Files',
                  desc: 'Scan remote bucket and register objects into drive',
                  icon: Icons.cloud_sync,
                  color: const Color(0xFF38BDF8),
                  onTap: () async {
                    final count = await widget.client.importFromCloud();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Discovered and imported $count cloud files!')),
                      );
                      _loadDashboardData();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  title: 'Free Up Local Cache',
                  desc: 'Run LRU eviction pass to free 1 GB of local space',
                  icon: Icons.delete_sweep_outlined,
                  color: Colors.amber,
                  onTap: () async {
                    final count = await widget.client.autoEvict(targetFreeMB: 1024);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Evicted $count files to Cloud-Only!')),
                      );
                      _loadDashboardData();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  title: 'Restore All to Drive',
                  desc: 'Download all cloud-only files back onto physical USB',
                  icon: Icons.cloud_download_outlined,
                  color: Colors.greenAccent,
                  onTap: () async {
                    await widget.client.restoreAll();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Downloading cloud files back to local drive...')),
                      );
                      _loadDashboardData();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
