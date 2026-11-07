import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/engine/engine_manager.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final EngineManager _engine = EngineManager();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<EngineLogEntry>? _sub;
  List<EngineLogEntry> _logs = [];
  bool _autoScroll = true;
  String _filterLevel = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _logs = List.from(_engine.logs);

    _sub = _engine.logStream.listen((entry) {
      if (mounted) {
        setState(() {
          _logs.add(entry);
        });
        if (_autoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<EngineLogEntry> get _filteredLogs {
    return _logs.where((l) {
      final matchesLevel = _filterLevel == 'ALL' || l.level == _filterLevel;
      final matchesSearch = _searchQuery.isEmpty || l.message.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesLevel && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Engine Status Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _engine.isRunning ? Colors.greenAccent : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _engine.isRunning ? 'Engine Running (PID: ${_engine.pid})' : 'Engine Stopped',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Watching: ${_engine.currentWatchPath ?? "None"} • DB: ${_engine.dbPath ?? "App Storage"}',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_engine.isRunning) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Restart'),
                        onPressed: () async {
                          await _engine.restart();
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.stop, size: 16),
                        label: const Text('Stop'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.8), foregroundColor: Colors.white),
                        onPressed: () async {
                          await _engine.stop();
                          setState(() {});
                        },
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Start Engine'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.black),
                        onPressed: () async {
                          if (_engine.currentWatchPath != null) {
                            await _engine.start(_engine.currentWatchPath!);
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Log Toolbar (Search, Filter, Auto-Scroll, Actions)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: 'Filter log output...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 12),
              _buildLevelFilterChip('ALL'),
              const SizedBox(width: 8),
              _buildLevelFilterChip('INFO'),
              const SizedBox(width: 8),
              _buildLevelFilterChip('WARN'),
              const SizedBox(width: 8),
              _buildLevelFilterChip('ERROR'),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center),
                tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
                color: _autoScroll ? const Color(0xFF38BDF8) : Colors.grey,
                onPressed: () => setState(() => _autoScroll = !_autoScroll),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy Logs',
                onPressed: () {
                  final text = _filteredLogs.map((l) => '[${l.timestamp.toIso8601String()}] [${l.level}] ${l.message}').join('\n');
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logs copied to clipboard!')));
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Clear Logs',
                onPressed: () {
                  _engine.clearLogs();
                  setState(() => _logs.clear());
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Console Terminal Window
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: _filteredLogs.isEmpty
                  ? Center(child: Text('No log output yet.', style: TextStyle(color: Colors.grey.shade600, fontFamily: 'monospace')))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _filteredLogs.length,
                      itemBuilder: (context, index) {
                        final entry = _filteredLogs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: SelectableText.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')} ',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontFamily: 'monospace'),
                                ),
                                TextSpan(
                                  text: '[${entry.level}] ',
                                  style: TextStyle(
                                    color: _getLevelColor(entry.level),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                TextSpan(
                                  text: entry.message,
                                  style: TextStyle(color: Colors.grey.shade300, fontSize: 12, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
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

  Widget _buildLevelFilterChip(String level) {
    final isSelected = _filterLevel == level;
    return ChoiceChip(
      label: Text(level),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterLevel = level),
      selectedColor: const Color(0xFF38BDF8).withOpacity(0.2),
      backgroundColor: const Color(0xFF1E293B),
      side: BorderSide(color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF38BDF8) : Colors.grey.shade400,
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.redAccent;
      case 'WARN':
        return Colors.amberAccent;
      case 'DEBUG':
        return Colors.grey;
      default:
        return Colors.cyanAccent;
    }
  }
}
