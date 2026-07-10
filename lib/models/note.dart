import 'dart:convert';

import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Note types & templates
/// ---------------------------------------------------------------------------

enum NoteType {
  text,
  login,
  website,
  wifi,
  bank,
  license,
  personal,
  shopping,
  todo,
  custom,
}

class NoteTypeMeta {
  final String label;
  final String blurb;
  final IconData icon;
  const NoteTypeMeta(this.label, this.blurb, this.icon);
}

const Map<NoteType, NoteTypeMeta> noteTypeMeta = {
  NoteType.text: NoteTypeMeta(
      'Text note', 'A plain page for anything', Icons.notes_rounded),
  NoteType.login: NoteTypeMeta('Login credentials',
      'Username & password for an app', Icons.key_rounded),
  NoteType.website: NoteTypeMeta('Website account',
      'Site, URL and sign-in details', Icons.language_rounded),
  NoteType.wifi: NoteTypeMeta(
      'Wi-Fi details', 'Network name & password', Icons.wifi_rounded),
  NoteType.bank: NoteTypeMeta(
      'Bank information', 'General account details', Icons.account_balance_rounded),
  NoteType.license: NoteTypeMeta(
      'Software license', 'Keys & activation details', Icons.verified_rounded),
  NoteType.personal: NoteTypeMeta('Personal information',
      'IDs, contacts and addresses', Icons.badge_rounded),
  NoteType.shopping: NoteTypeMeta(
      'Shopping list', 'A checklist for the market', Icons.shopping_cart_rounded),
  NoteType.todo: NoteTypeMeta(
      'To-do', 'Tasks with checkboxes', Icons.check_circle_outline_rounded),
  NoteType.custom: NoteTypeMeta(
      'Custom note', 'Your own fields, your rules', Icons.dashboard_customize_rounded),
};

class FieldSpec {
  final String key;
  final String label;
  final String hint;
  final bool secret;
  final bool copyable;
  final bool multiline;
  final bool canGenerate;
  final TextInputType keyboard;

  const FieldSpec(
    this.key,
    this.label, {
    this.hint = '',
    this.secret = false,
    this.copyable = false,
    this.multiline = false,
    this.canGenerate = false,
    this.keyboard = TextInputType.text,
  });
}

const Map<NoteType, List<FieldSpec>> templates = {
  NoteType.text: [],
  NoteType.shopping: [],
  NoteType.todo: [],
  NoteType.custom: [],
  NoteType.login: [
    FieldSpec('app', 'Website / app name', hint: 'e.g. Gmail'),
    FieldSpec('username', 'Username', copyable: true),
    FieldSpec('email', 'Email',
        copyable: true, keyboard: TextInputType.emailAddress),
    FieldSpec('password', 'Password',
        secret: true, copyable: true, canGenerate: true),
    FieldSpec('url', 'Website URL',
        hint: 'https://…', copyable: true, keyboard: TextInputType.url),
  ],
  NoteType.website: [
    FieldSpec('site', 'Site name', hint: 'e.g. NSE India'),
    FieldSpec('url', 'URL',
        hint: 'https://…', copyable: true, keyboard: TextInputType.url),
    FieldSpec('username', 'Username / email', copyable: true),
    FieldSpec('password', 'Password',
        secret: true, copyable: true, canGenerate: true),
  ],
  NoteType.wifi: [
    FieldSpec('network', 'Network name (SSID)', hint: 'e.g. Home 5G'),
    FieldSpec('password', 'Password', secret: true, copyable: true),
    FieldSpec('security', 'Security type', hint: 'WPA2 / WPA3'),
  ],
  NoteType.bank: [
    FieldSpec('bank', 'Bank name'),
    FieldSpec('holder', 'Account holder'),
    FieldSpec('account', 'Account number', secret: true, copyable: true),
    FieldSpec('ifsc', 'IFSC / routing code', copyable: true),
    FieldSpec('customerId', 'Customer ID', secret: true, copyable: true),
    FieldSpec('branch', 'Branch'),
  ],
  NoteType.license: [
    FieldSpec('software', 'Software', hint: 'e.g. Photoshop'),
    FieldSpec('key', 'License key', secret: true, copyable: true),
    FieldSpec('email', 'Licensed to', keyboard: TextInputType.emailAddress),
    FieldSpec('date', 'Purchase date', hint: '12 Mar 2026'),
    FieldSpec('version', 'Version'),
  ],
  NoteType.personal: [
    FieldSpec('name', 'Full name'),
    FieldSpec('dob', 'Date of birth', hint: 'DD/MM/YYYY'),
    FieldSpec('phone', 'Phone', copyable: true, keyboard: TextInputType.phone),
    FieldSpec('email', 'Email',
        copyable: true, keyboard: TextInputType.emailAddress),
    FieldSpec('idNumber', 'ID number', secret: true, copyable: true),
    FieldSpec('address', 'Address', multiline: true),
  ],
};

bool typeHasChecklist(NoteType t) =>
    t == NoteType.shopping || t == NoteType.todo;

const List<Color?> noteColors = [
  null,
  Color(0xFFF6C6C6),
  Color(0xFFF8DDB0),
  Color(0xFFF9F1B5),
  Color(0xFFC9E7C5),
  Color(0xFFBFE3E0),
  Color(0xFFC5D8F5),
  Color(0xFFDCCDF2),
  Color(0xFFE4D5C3),
];

/// ---------------------------------------------------------------------------
/// Checklist / custom rows
/// ---------------------------------------------------------------------------

class ChecklistItem {
  String text;
  bool done;
  ChecklistItem(this.text, {this.done = false});

  Map<String, dynamic> toMap() => {'text': text, 'done': done};

  static ChecklistItem fromMap(Map<String, dynamic> m) =>
      ChecklistItem((m['text'] ?? '') as String,
          done: (m['done'] ?? false) as bool);
}

class CustomRow {
  String name;
  String value;
  bool secret;
  CustomRow({this.name = '', this.value = '', this.secret = false});

  Map<String, dynamic> toMap() =>
      {'name': name, 'value': value, 'secret': secret};

  static CustomRow fromMap(Map<String, dynamic> m) => CustomRow(
        name: (m['name'] ?? '') as String,
        value: (m['value'] ?? '') as String,
        secret: (m['secret'] ?? false) as bool,
      );
}

/// ---------------------------------------------------------------------------
/// Note — stored as a Firestore document (users/{uid}/notes/{id})
/// ---------------------------------------------------------------------------

class Note {
  final String id;
  final NoteType type;
  String title;
  String content;
  Map<String, dynamic> fields;
  List<String> tags;
  int colorIndex;
  bool favorite;
  bool pinned;
  bool archived;
  bool deleted;
  DateTime createdAt;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.type,
    this.title = '',
    this.content = '',
    Map<String, dynamic>? fields,
    List<String>? tags,
    this.colorIndex = 0,
    this.favorite = false,
    this.pinned = false,
    this.archived = false,
    this.deleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : fields = fields ?? {},
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  List<ChecklistItem> get checklist {
    final raw = fields['items'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => ChecklistItem.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }
    return [];
  }

  set checklist(List<ChecklistItem> items) {
    fields['items'] = items.map((e) => e.toMap()).toList();
  }

  List<CustomRow> get customRows {
    final raw = fields['custom'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => CustomRow.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }
    return [];
  }

  set customRows(List<CustomRow> rows) {
    fields['custom'] = rows.map((e) => e.toMap()).toList();
  }

  String preview() {
    if (typeHasChecklist(type)) {
      final items = checklist;
      if (items.isEmpty) return 'Empty list';
      final done = items.where((i) => i.done).length;
      return '$done of ${items.length} done · ${items.take(3).map((i) => i.text).join(', ')}';
    }
    final specs = templates[type] ?? const [];
    if (specs.isNotEmpty) {
      final parts = <String>[];
      for (final f in specs) {
        final v = (fields[f.key] ?? '').toString();
        if (v.isEmpty) continue;
        parts.add(f.secret ? '${f.label}: ••••••' : v);
        if (parts.length >= 3) break;
      }
      if (parts.isNotEmpty) return parts.join('  ·  ');
    }
    if (type == NoteType.custom && customRows.isNotEmpty) {
      return customRows
          .take(3)
          .map((r) => r.secret ? '${r.name}: ••••••' : '${r.name}: ${r.value}')
          .join('  ·  ');
    }
    return content;
  }

  String searchable() {
    final buf = StringBuffer('$title $content ${tags.join(' ')} ');
    fields.forEach((k, v) {
      if (v is String) buf.write('$v ');
    });
    for (final i in checklist) {
      buf.write('${i.text} ');
    }
    for (final r in customRows) {
      buf.write('${r.name} ${r.value} ');
    }
    return buf.toString().toLowerCase();
  }

  /// Deep copy (JSON round-trip keeps nested lists/maps independent).
  Note copy() =>
      Note.fromDoc(id, jsonDecode(jsonEncode(toMap())) as Map<String, dynamic>);

  /// Firestore-native map (no JSON strings needed — Firestore stores maps/lists).
  Map<String, dynamic> toMap() => {
        'type': type.name,
        'title': title,
        'content': content,
        'fields': fields,
        'tags': tags,
        'colorIndex': colorIndex,
        'favorite': favorite,
        'pinned': pinned,
        'archived': archived,
        'deleted': deleted,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  static Note fromDoc(String id, Map<String, dynamic> m) => Note(
        id: id,
        type: NoteType.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => NoteType.text,
        ),
        title: (m['title'] ?? '') as String,
        content: (m['content'] ?? '') as String,
        fields: Map<String, dynamic>.from(m['fields'] ?? {}),
        tags: List<String>.from(m['tags'] ?? []),
        colorIndex: (m['colorIndex'] ?? 0) as int,
        favorite: (m['favorite'] ?? false) == true,
        pinned: (m['pinned'] ?? false) == true,
        archived: (m['archived'] ?? false) == true,
        deleted: (m['deleted'] ?? false) == true,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((m['createdAt'] ?? 0) as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch((m['updatedAt'] ?? 0) as int),
      );
}

String relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays == 1) return 'yesterday';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return '${t.day}/${t.month}/${t.year}';
}
