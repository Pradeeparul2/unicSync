import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/sync_api_client.dart';
import '../../core/models/models.dart';

class ProfilesScreen extends StatefulWidget {
  final SyncApiClient client;

  const ProfilesScreen({super.key, required this.client});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  List<CloudProfileModel> _profiles = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchProfiles() async {
    setState(() => _isLoading = true);
    try {
      final profiles = await widget.client.getProfiles();
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final profiles = await widget.client.getProfiles();
      if (mounted) {
        setState(() {
          _profiles = profiles;
        });
      }
    } catch (_) {}
  }

  void _showAddProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddProfileDialog(
        client: widget.client,
        onProfileAdded: () {
          _fetchProfiles();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cloud storage profile saved successfully!'),
              backgroundColor: Colors.teal,
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteProfile(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Cloud Profile'),
        content: Text('Are you sure you want to remove profile "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.client.deleteProfile(name);
      if (success) {
        _fetchProfiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile "$name" deleted.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete profile.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cloud Storage Profiles', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Manage connected cloud destinations (AWS S3, Cloudflare R2, Google Drive, WebDAV)',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                ],
              ),
              Row(
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Refresh Profiles',
                    onPressed: _fetchProfiles,
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _showAddProfileDialog,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                : _profiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_off_outlined, size: 64, color: Colors.grey.shade600),
                            const SizedBox(height: 16),
                            Text('No Cloud Profiles Configured',
                                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade300)),
                            const SizedBox(height: 8),
                            Text(
                              'Connect AWS S3, Cloudflare R2, MinIO, Google Drive, or WebDAV to sync your files.',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF38BDF8),
                                foregroundColor: const Color(0xFF0F172A),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('Add Your First Cloud Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: _showAddProfileDialog,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _profiles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final profile = _profiles[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: profile.isActive ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                                width: profile.isActive ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: profile.isActive ? const Color(0xFF38BDF8).withValues(alpha: 0.15) : Colors.grey.shade800,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getProviderIcon(profile.provider),
                                    color: profile.isActive ? const Color(0xFF38BDF8) : Colors.grey.shade400,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(profile.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF334155),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(profile.provider, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                          ),
                                          if (profile.isActive) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text('ACTIVE TARGET',
                                                  style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(profile.destination, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!profile.isActive)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155)),
                                        onPressed: () async {
                                          await widget.client.setActiveProfile(profile.name);
                                          _fetchProfiles();
                                        },
                                        child: const Text('Set as Active'),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.check_circle, size: 16, color: Colors.greenAccent),
                                            SizedBox(width: 6),
                                            Text('Active', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                      tooltip: 'Delete Profile',
                                      onPressed: () => _confirmDeleteProfile(profile.name),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  IconData _getProviderIcon(String provider) {
    switch (provider.toLowerCase()) {
      case 's3':
        return Icons.dns_outlined;
      case 'google drive':
      case 'gdrive':
        return Icons.storage_outlined;
      case 'webdav':
        return Icons.folder_shared_outlined;
      default:
        return Icons.cloud_outlined;
    }
  }
}

class _AddProfileDialog extends StatefulWidget {
  final SyncApiClient client;
  final VoidCallback onProfileAdded;

  const _AddProfileDialog({required this.client, required this.onProfileAdded});

  @override
  State<_AddProfileDialog> createState() => _AddProfileDialogState();
}

class _AddProfileDialogState extends State<_AddProfileDialog> {
  String _selectedType = 's3'; // 's3', 'gdrive', 'webdav', 'mock'
  final _nameController = TextEditingController();

  // S3 Controllers
  final _s3BucketController = TextEditingController();
  final _s3RegionController = TextEditingController(text: 'ap-south-1');
  final _s3EndpointController = TextEditingController();
  final _s3AccessKeyController = TextEditingController();
  final _s3SecretKeyController = TextEditingController();
  bool _s3ForcePathStyle = true;

  // Google Drive Controllers
  final _gdriveTokenController = TextEditingController();
  final _gdriveFolderIdController = TextEditingController();

  // WebDAV Controllers
  final _webdavEndpointController = TextEditingController();
  final _webdavUserController = TextEditingController();
  final _webdavPasswordController = TextEditingController();
  final _webdavRootFolderController = TextEditingController();

  bool _makeActive = true;
  bool _obscureSecret = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _s3BucketController.dispose();
    _s3RegionController.dispose();
    _s3EndpointController.dispose();
    _s3AccessKeyController.dispose();
    _s3SecretKeyController.dispose();
    _gdriveTokenController.dispose();
    _gdriveFolderIdController.dispose();
    _webdavEndpointController.dispose();
    _webdavUserController.dispose();
    _webdavPasswordController.dispose();
    _webdavRootFolderController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Profile Name is required.');
      return;
    }

    final Map<String, dynamic> payload = {
      'name': name,
      'type': _selectedType,
      'make_active': _makeActive,
    };

    if (_selectedType == 's3') {
      final bucket = _s3BucketController.text.trim();
      final accessKey = _s3AccessKeyController.text.trim();
      final secretKey = _s3SecretKeyController.text.trim();

      if (bucket.isEmpty || accessKey.isEmpty || secretKey.isEmpty) {
        setState(() => _errorMessage = 'Bucket Name, Access Key, and Secret Key are required for S3.');
        return;
      }

      payload['bucket'] = bucket;
      payload['region'] = _s3RegionController.text.trim().isEmpty ? 'ap-south-1' : _s3RegionController.text.trim();
      payload['endpoint'] = _s3EndpointController.text.trim();
      payload['access_key'] = accessKey;
      payload['secret_key'] = secretKey;
      payload['force_path_style'] = _s3ForcePathStyle;
    } else if (_selectedType == 'gdrive') {
      final token = _gdriveTokenController.text.trim();
      if (token.isEmpty) {
        setState(() => _errorMessage = 'Google Drive OAuth Access Token is required.');
        return;
      }
      payload['access_token'] = token;
      final folderId = _gdriveFolderIdController.text.trim();
      if (folderId.isNotEmpty) {
        payload['folder_id'] = folderId;
      }
    } else if (_selectedType == 'webdav') {
      final endpoint = _webdavEndpointController.text.trim();
      final user = _webdavUserController.text.trim();
      final pass = _webdavPasswordController.text.trim();

      if (endpoint.isEmpty || user.isEmpty || pass.isEmpty) {
        setState(() => _errorMessage = 'Endpoint URL, Username, and Password are required for WebDAV.');
        return;
      }

      payload['endpoint'] = endpoint;
      payload['username'] = user;
      payload['password'] = pass;
      final root = _webdavRootFolderController.text.trim();
      if (root.isNotEmpty) {
        payload['root_folder'] = root;
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.client.saveProfile(payload);
      if (success) {
        if (mounted) {
          Navigator.pop(context);
          widget.onProfileAdded();
        }
      } else {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save profile. Please check parameters.';
        });
      }
    } catch (e) {
      String msg = 'Failed to save profile.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data.containsKey('error')) {
          msg = data['error'].toString();
        } else if (data is String && data.isNotEmpty) {
          msg = data;
        } else if (e.response?.statusCode == 400) {
          msg = 'Invalid profile parameters (HTTP 400). Please check all required fields.';
        } else {
          msg = e.message ?? e.toString();
        }
      } else {
        msg = e.toString();
      }
      setState(() {
        _isSaving = false;
        _errorMessage = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF38BDF8), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Add Cloud Storage Profile',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Provider Type Selector
            Row(
              children: [
                _buildTypeChip('s3', 'AWS S3 / R2 / MinIO', Icons.dns_outlined),
                const SizedBox(width: 8),
                _buildTypeChip('gdrive', 'Google Drive', Icons.storage_outlined),
                const SizedBox(width: 8),
                _buildTypeChip('webdav', 'WebDAV', Icons.folder_shared_outlined),
                const SizedBox(width: 8),
                _buildTypeChip('mock', 'Mock', Icons.science_outlined),
              ],
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  ],
                ),
              ),

            // Scrollable Form Fields
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Name Field
                    _buildTextField(
                      controller: _nameController,
                      label: 'Profile Name',
                      hint: 'e.g. s3-backup, cloudflare-r2, my-nextcloud',
                      prefixIcon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 14),

                    // Provider Specific Fields
                    if (_selectedType == 's3') ...[
                      _buildTextField(
                        controller: _s3BucketController,
                        label: 'S3 Bucket Name',
                        hint: 'e.g. edge-vault-storage',
                        prefixIcon: Icons.folder_open,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _s3RegionController,
                              label: 'AWS Region',
                              hint: 'e.g. ap-south-1, us-east-1, auto',
                              prefixIcon: Icons.public,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _s3EndpointController,
                              label: 'Custom Endpoint (Optional)',
                              hint: 'e.g. https://<account>.r2.cloudflarestorage.com',
                              prefixIcon: Icons.link,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _s3AccessKeyController,
                        label: 'Access Key ID',
                        hint: 'AKIA...',
                        prefixIcon: Icons.key,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _s3SecretKeyController,
                        label: 'Secret Access Key',
                        hint: 'Secret Key',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscureSecret,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureSecret ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Force Path-Style Addressing (MinIO / R2 / Ceph)', style: TextStyle(fontSize: 13)),
                        value: _s3ForcePathStyle,
                        activeColor: const Color(0xFF38BDF8),
                        onChanged: (val) => setState(() => _s3ForcePathStyle = val),
                      ),
                    ] else if (_selectedType == 'gdrive') ...[
                      _buildTextField(
                        controller: _gdriveTokenController,
                        label: 'OAuth2 Access Token',
                        hint: 'Bearer access token (ya29...)',
                        prefixIcon: Icons.vpn_key_outlined,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _gdriveFolderIdController,
                        label: 'Parent Folder ID (Optional)',
                        hint: 'Target Google Drive Folder ID (defaults to root)',
                        prefixIcon: Icons.folder_shared_outlined,
                      ),
                    ] else if (_selectedType == 'webdav') ...[
                      _buildTextField(
                        controller: _webdavEndpointController,
                        label: 'WebDAV Server URL',
                        hint: 'https://cloud.example.com/remote.php/dav/files/username/',
                        prefixIcon: Icons.link,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _webdavUserController,
                              label: 'Username',
                              hint: 'username',
                              prefixIcon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _webdavPasswordController,
                              label: 'Password / App Token',
                              hint: 'password',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscureSecret,
                              suffixIcon: IconButton(
                                icon: Icon(_obscureSecret ? Icons.visibility_off : Icons.visibility, size: 18),
                                onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _webdavRootFolderController,
                        label: 'Remote Root Folder (Optional)',
                        hint: 'e.g. /rSync_Backups',
                        prefixIcon: Icons.folder_outlined,
                      ),
                    ] else if (_selectedType == 'mock') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'In-memory simulated cloud bucket. Useful for local testing and benchmark uploads without real cloud charges.',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Set as Active Sync Destination Immediately', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Files from your watch folder will upload to this destination.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      value: _makeActive,
                      activeColor: const Color(0xFF38BDF8),
                      onChanged: (val) => setState(() => _makeActive = val),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                      : const Icon(Icons.check, size: 18),
                  label: Text(_isSaving ? 'Saving...' : 'Save Profile', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _isSaving ? null : _handleSave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _selectedType = type;
          _errorMessage = null;
        }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF38BDF8).withValues(alpha: 0.15) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? const Color(0xFF38BDF8) : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey.shade400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade300)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            prefixIcon: Icon(prefixIcon, size: 18, color: Colors.grey.shade400),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
