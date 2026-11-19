import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raccoon/model/raccoon_log_entry.dart';
import 'package:raccoon/raccoon_service.dart';

/// Lists log entries recorded through `Raccoon().log`, newest first.
class RaccoonLogsView extends StatefulWidget {
  const RaccoonLogsView({super.key, required this.service});

  final RaccoonService service;

  @override
  State<RaccoonLogsView> createState() => _RaccoonLogsViewState();
}

class _RaccoonLogsViewState extends State<RaccoonLogsView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(RaccoonLogEntry entry) {
    if (_query.isEmpty) return true;
    final query = _query.toLowerCase();
    return entry.message.toLowerCase().contains(query) ||
        (entry.tag?.toLowerCase().contains(query) ?? false) ||
        (entry.error?.toString().toLowerCase().contains(query) ?? false);
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label), duration: const Duration(seconds: 2)),
    );
  }

  static Color _levelColor(RaccoonLogLevel level) => switch (level) {
        RaccoonLogLevel.debug => Colors.grey,
        RaccoonLogLevel.info => Colors.blue,
        RaccoonLogLevel.warning => Colors.orange,
        RaccoonLogLevel.error => Colors.red,
      };

  static String _time(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    final millis = time.millisecond.toString().padLeft(3, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.$millis';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final entries = widget.service.logs.reversed
            .where(_matches)
            .toList(growable: false);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Logs'),
            actions: [
              IconButton(
                tooltip: 'Copy all',
                icon: const Icon(Icons.copy_all),
                onPressed: entries.isEmpty
                    ? null
                    : () => _copy(
                          entries.reversed.map((e) => e.toText()).join('\n'),
                          'Logs copied to clipboard',
                        ),
              ),
              IconButton(
                tooltip: 'Clear logs',
                icon: const Icon(Icons.delete),
                onPressed: widget.service.clearLogs,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: const InputDecoration(
                    hintText: 'Search logs',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
          ),
          body: entries.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty
                        ? 'There is no log yet'
                        : 'No logs match "$_query"',
                  ),
                )
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final color = _levelColor(entry.level);
                    return ListTile(
                      dense: true,
                      onLongPress: () =>
                          _copy(entry.toText(), 'Log copied to clipboard'),
                      title: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${entry.level.name.toUpperCase()} ',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (entry.tag != null && entry.tag!.isNotEmpty)
                              TextSpan(
                                text: '[${entry.tag}] ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            TextSpan(text: entry.message),
                          ],
                        ),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (entry.error != null)
                            Text(
                              '${entry.error}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          Text(_time(entry.time)),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
