import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raccoon/model/raccoon_http_call.dart';

/// Shows the request body: form fields (multipart or url-encoded), JSON, or
/// raw text. Long values are shortened on screen but copied in full, and
/// base64 images are previewed.
class RaccoonRequestWidget extends StatelessWidget {
  const RaccoonRequestWidget({super.key, required this.call});

  final RaccoonHttpCall call;

  /// Values longer than this are shortened on screen.
  static const int previewLength = 500;

  @override
  Widget build(BuildContext context) {
    final request = call.request;
    if (request == null) {
      return const Center(child: Text('There is no request'));
    }

    final fields = _fields(request.body, request.contentType,
        request.formDataFields?.map((f) => MapEntry(f.name, f.value)));
    final files = request.formDataFiles ?? const [];

    if (fields == null && files.isEmpty) {
      final raw = _rawText(request.body);
      if (raw.isEmpty) {
        return const Center(child: Text('There is no request body'));
      }
      return _RawBody(text: raw);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${request.contentType ?? '-'} · ${request.size} bytes',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: 'Copy body',
              icon: const Icon(Icons.copy, size: 20),
              visualDensity: VisualDensity.compact,
              onPressed: () => _copy(
                context,
                fields == null
                    ? _rawText(request.body)
                    : const JsonEncoder.withIndent('  ')
                        .convert(Map.fromEntries(fields)),
                'Request body copied to clipboard',
              ),
            ),
          ],
        ),
        for (final field in fields ?? const <MapEntry<String, String>>[])
          _FieldTile(name: field.key, value: field.value),
        for (final file in files)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file),
            title: Text(file.fileName ?? '(file)'),
            subtitle: Text('${file.contentType} · ${file.length} bytes'),
          ),
      ],
    );
  }

  /// Form fields of the body, or null when the body is not a form.
  static List<MapEntry<String, String>>? _fields(
    dynamic body,
    String? contentType,
    Iterable<MapEntry<String, String>>? formDataFields,
  ) {
    if (formDataFields != null) return formDataFields.toList();
    if (body is Map) {
      return body.entries
          .map((e) => MapEntry('${e.key}', _stringify(e.value)))
          .toList();
    }
    final isUrlEncoded =
        contentType?.toLowerCase().contains('x-www-form-urlencoded') ?? false;
    if (body is String && isUrlEncoded && body.isNotEmpty) {
      try {
        return Uri.splitQueryString(body).entries.toList();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String _stringify(dynamic value) {
    if (value is String) return value;
    try {
      return jsonEncode(value);
    } catch (_) {
      return '$value';
    }
  }

  static String _rawText(dynamic body) {
    if (body == null) return '';
    if (body is String) return _prettyJson(body) ?? body;
    try {
      return const JsonEncoder.withIndent('  ').convert(body);
    } catch (_) {
      return '$body';
    }
  }

  /// [text] re-indented when it is a JSON object or array, else null.
  static String? _prettyJson(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(trimmed));
    } catch (_) {
      return null;
    }
  }

  static void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label), duration: const Duration(seconds: 2)),
    );
  }
}

class _RawBody extends StatelessWidget {
  const _RawBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Copy body',
          icon: const Icon(Icons.copy, size: 20),
          onPressed: () => RaccoonRequestWidget._copy(
              context, text, 'Request body copied to clipboard'),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: SelectableText(
                text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One form field: name, value (JSON pretty-printed, long text shortened),
/// a copy button for the full value, and a preview when it is a base64 image.
class _FieldTile extends StatefulWidget {
  const _FieldTile({required this.name, required this.value});

  final String name;
  final String value;

  @override
  State<_FieldTile> createState() => _FieldTileState();
}

class _FieldTileState extends State<_FieldTile> {
  late final Uint8List? _image = _decodeImage(widget.value);
  late final String _display =
      RaccoonRequestWidget._prettyJson(widget.value) ?? widget.value;
  bool _expanded = false;

  /// Bytes of [value] when it is a base64 JPEG/PNG (with or without a
  /// `data:image/...;base64,` prefix), else null.
  static Uint8List? _decodeImage(String value) {
    var data = value.trim();
    final comma = data.indexOf(',');
    if (data.startsWith('data:image') && comma != -1) {
      data = data.substring(comma + 1);
    }
    if (!data.startsWith('/9j/') && !data.startsWith('iVBORw0KGgo')) {
      return null;
    }
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final isLong = _display.length > RaccoonRequestWidget.previewLength;
    final shown = isLong && !_expanded
        ? '${_display.substring(0, RaccoonRequestWidget.previewLength)}…'
        : _display;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                image != null
                    ? 'image · ${(image.length / 1024).toStringAsFixed(0)} KB'
                    : '${widget.value.length} chars',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              IconButton(
                tooltip: 'Copy ${widget.name}',
                icon: const Icon(Icons.copy, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () => RaccoonRequestWidget._copy(
                  context,
                  widget.value,
                  '${widget.name} copied to clipboard',
                ),
              ),
            ],
          ),
          if (image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                image,
                height: 220,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) =>
                    const Text('Image cannot be previewed'),
              ),
            )
          else ...[
            SelectableText(
              shown,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            if (isLong)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Show less' : 'Show all'),
              ),
          ],
        ],
      ),
    );
  }
}
