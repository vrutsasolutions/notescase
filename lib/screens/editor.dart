import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/note.dart';
import '../providers.dart';
import '../utils/password_generator.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.existing, this.isNew = false});

  final Note existing;
  final bool isNew;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late Note _note;
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _tagCtrl;
  final Map<String, TextEditingController> _fieldCtrls = {};
  final Map<String, bool> _revealed = {};
  late List<ChecklistItem> _items;
  late List<CustomRow> _rows;
  bool _saving = false;

  List<FieldSpec> get _specs => templates[_note.type] ?? const [];

  @override
  void initState() {
    super.initState();
    _note = widget.existing.copy();
    _titleCtrl = TextEditingController(text: _note.title);
    _contentCtrl = TextEditingController(text: _note.content);
    _tagCtrl = TextEditingController();
    for (final f in _specs) {
      _fieldCtrls[f.key] = TextEditingController(
          text: (_note.fields[f.key] ?? '').toString());
    }
    _items = _note.checklist;
    _rows = _note.customRows;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    for (final c in _fieldCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    _snack('Copied $label');
  }

  Note _buildNote() {
    final n = _note;
    n.title = _titleCtrl.text.trim();
    n.content = _contentCtrl.text;
    for (final f in _specs) {
      n.fields[f.key] = _fieldCtrls[f.key]!.text;
    }
    if (typeHasChecklist(n.type)) {
      n.checklist = _items.where((i) => i.text.trim().isNotEmpty).toList();
    }
    if (n.type == NoteType.custom) {
      n.customRows = _rows
          .where((r) => r.name.trim().isNotEmpty || r.value.trim().isNotEmpty)
          .toList();
    }
    if (n.title.isEmpty) {
      final fallback = (n.fields['app'] ??
              n.fields['site'] ??
              n.fields['network'] ??
              n.fields['software'] ??
              n.fields['bank'] ??
              n.fields['name'] ??
              '')
          .toString()
          .trim();
      n.title = fallback.isEmpty ? 'Untitled' : fallback;
    }
    return n;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(noteActionsProvider).upsert(_buildNote());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Save failed: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _duplicate() async {
    try {
      final n = _buildNote();
      final fresh = Note(
        id: const Uuid().v4(),
        type: n.type,
        title: '${n.title} (copy)',
        content: n.content,
        fields: n.copy().fields,
        tags: List.of(n.tags),
        colorIndex: n.colorIndex,
      );
      await ref.read(noteActionsProvider).upsert(fresh);
      _snack('Duplicated');
    } catch (e) {
      _snack('Duplicate failed: $e');
    }
  }

  void _share() {
    final n = _buildNote();
    final buf = StringBuffer('${n.title}\n');
    for (final f in _specs) {
      final v = (n.fields[f.key] ?? '').toString();
      if (v.isEmpty) continue;
      buf.writeln('${f.label}: ${f.secret ? '(hidden)' : v}');
    }
    for (final i in _items) {
      buf.writeln('${i.done ? '[x]' : '[ ]'} ${i.text}');
    }
    for (final r in _rows) {
      buf.writeln('${r.name}: ${r.secret ? '(hidden)' : r.value}');
    }
    if (n.content.isNotEmpty) buf.writeln('\n${n.content}');
    Share.share(buf.toString(), subject: n.title);
  }

  Future<void> _moveToTrash() async {
    try {
      await ref.read(noteActionsProvider).moveToTrash(_buildNote());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _openGenerator(TextEditingController target) async {
    final pwd = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const PasswordGeneratorSheet(),
    );
    if (pwd != null) {
      setState(() => target.text = pwd);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final meta = noteTypeMeta[_note.type]!;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isNew ? 'New ${meta.label.toLowerCase()}' : meta.label),
        actions: [
          IconButton(
            tooltip: _note.pinned ? 'Unpin' : 'Pin',
            icon: Icon(
                _note.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined),
            onPressed: () => setState(() => _note.pinned = !_note.pinned),
          ),
          IconButton(
            tooltip: _note.favorite ? 'Unfavorite' : 'Favorite',
            icon: Icon(
                _note.favorite ? Icons.star_rounded : Icons.star_border_rounded),
            onPressed: () => setState(() => _note.favorite = !_note.favorite),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'share':
                  _share();
                  break;
                case 'duplicate':
                  _duplicate();
                  break;
                case 'archive':
                  setState(() => _note.archived = !_note.archived);
                  break;
                case 'trash':
                  _moveToTrash();
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'share', child: Text('Share (secrets hidden)')),
              if (!widget.isNew)
                const PopupMenuItem(
                    value: 'duplicate', child: Text('Duplicate')),
              PopupMenuItem(
                  value: 'archive',
                  child: Text(_note.archived ? 'Unarchive' : 'Archive')),
              if (!widget.isNew)
                const PopupMenuItem(
                    value: 'trash', child: Text('Move to trash')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          TextField(
            controller: _titleCtrl,
            style: Theme.of(context).textTheme.headlineSmall,
            decoration: const InputDecoration(
              hintText: 'Title',
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 4),
          for (final f in _specs) ...[
            _FieldEditor(
              spec: f,
              controller: _fieldCtrls[f.key]!,
              revealed: _revealed[f.key] ?? false,
              onToggleReveal: () => setState(
                  () => _revealed[f.key] = !(_revealed[f.key] ?? false)),
              onCopy: () =>
                  _copy(f.label.toLowerCase(), _fieldCtrls[f.key]!.text),
              onGenerate: f.canGenerate
                  ? () => _openGenerator(_fieldCtrls[f.key]!)
                  : null,
            ),
            const SizedBox(height: 12),
          ],
          if (typeHasChecklist(_note.type)) _buildChecklist(cs),
          if (_note.type == NoteType.custom) _buildCustomRows(cs),
          if (_specs.isNotEmpty ||
              typeHasChecklist(_note.type) ||
              _note.type == NoteType.custom)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text('Notes',
                  style:
                      TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            ),
          TextField(
            controller: _contentCtrl,
            maxLines: null,
            minLines:
                _specs.isEmpty && !typeHasChecklist(_note.type) ? 10 : 4,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: _specs.isEmpty ? 'Write anything…' : 'Anything extra…',
            ),
          ),
          const SizedBox(height: 20),
          Text('Tags',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final t in _note.tags)
                InputChip(
                  label: Text('#$t'),
                  onDeleted: () => setState(() => _note.tags.remove(t)),
                ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _tagCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Add tag…',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (v) {
                    final tag = v.trim().replaceAll('#', '');
                    if (tag.isNotEmpty && !_note.tags.contains(tag)) {
                      setState(() => _note.tags.add(tag));
                    }
                    _tagCtrl.clear();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Color label',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              for (var i = 0; i < noteColors.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _note.colorIndex = i),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: noteColors[i] ?? cs.surfaceContainerHighest,
                      border: Border.all(
                        width: _note.colorIndex == i ? 3 : 1,
                        color: _note.colorIndex == i
                            ? cs.primary
                            : cs.outlineVariant,
                      ),
                    ),
                    child: i == 0
                        ? Icon(Icons.block_rounded,
                            size: 16, color: cs.outline)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.check_rounded),
        label: Text(_saving ? 'Saving…' : 'Save'),
      ),
    );
  }

  Widget _buildChecklist(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Items',
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        for (var i = 0; i < _items.length; i++)
          Row(
            children: [
              Checkbox(
                value: _items[i].done,
                onChanged: (v) => setState(() => _items[i].done = v ?? false),
              ),
              Expanded(
                child: TextFormField(
                  initialValue: _items[i].text,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Item…',
                  ),
                  style: TextStyle(
                    decoration: _items[i].done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                  onChanged: (v) => _items[i].text = v,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() => _items.removeAt(i)),
              ),
            ],
          ),
        TextButton.icon(
          onPressed: () => setState(() => _items.add(ChecklistItem(''))),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add item'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCustomRows(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fields',
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: _rows[i].name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged: (v) => _rows[i].name = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: _rows[i].value,
                    obscureText: _rows[i].secret,
                    decoration: const InputDecoration(labelText: 'Value'),
                    onChanged: (v) => _rows[i].value = v,
                  ),
                ),
                IconButton(
                  tooltip: _rows[i].secret ? 'Sensitive' : 'Mark sensitive',
                  icon: Icon(
                    _rows[i].secret
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_outlined,
                    size: 19,
                    color: _rows[i].secret ? cs.primary : cs.outline,
                  ),
                  onPressed: () =>
                      setState(() => _rows[i].secret = !_rows[i].secret),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() => _rows.removeAt(i)),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() => _rows.add(CustomRow())),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add field'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FieldEditor extends StatelessWidget {
  const _FieldEditor({
    required this.spec,
    required this.controller,
    required this.revealed,
    required this.onToggleReveal,
    required this.onCopy,
    this.onGenerate,
  });

  final FieldSpec spec;
  final TextEditingController controller;
  final bool revealed;
  final VoidCallback onToggleReveal;
  final VoidCallback onCopy;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: spec.secret && !revealed,
      maxLines: spec.multiline ? 3 : 1,
      keyboardType: spec.multiline ? TextInputType.multiline : spec.keyboard,
      autocorrect: !spec.secret,
      enableSuggestions: !spec.secret,
      decoration: InputDecoration(
        labelText: spec.label,
        hintText: spec.hint.isEmpty ? null : spec.hint,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onGenerate != null)
              IconButton(
                tooltip: 'Generate password',
                icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
                onPressed: onGenerate,
              ),
            if (spec.secret)
              IconButton(
                tooltip: revealed ? 'Hide' : 'Show',
                icon: Icon(
                    revealed
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20),
                onPressed: onToggleReveal,
              ),
            if (spec.copyable)
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: onCopy,
              ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Password generator sheet
/// ---------------------------------------------------------------------------

class PasswordGeneratorSheet extends StatefulWidget {
  const PasswordGeneratorSheet({super.key});

  @override
  State<PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<PasswordGeneratorSheet> {
  double _length = 16;
  bool _upper = true;
  bool _lower = true;
  bool _digits = true;
  bool _symbols = true;
  late String _password;

  @override
  void initState() {
    super.initState();
    _regen();
  }

  void _regen() {
    _password = PasswordGenerator.generate(
      length: _length.round(),
      upper: _upper,
      lower: _lower,
      digits: _digits,
      symbols: _symbols,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Password generator',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _password,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 16),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Regenerate',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _regen,
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _password));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied password')));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Length: ${_length.round()}'),
                Expanded(
                  child: Slider(
                    value: _length,
                    min: 8,
                    max: 40,
                    divisions: 32,
                    onChanged: (v) {
                      _length = v;
                      _regen();
                    },
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                    label: const Text('A–Z'),
                    selected: _upper,
                    onSelected: (v) {
                      _upper = v;
                      _regen();
                    }),
                FilterChip(
                    label: const Text('a–z'),
                    selected: _lower,
                    onSelected: (v) {
                      _lower = v;
                      _regen();
                    }),
                FilterChip(
                    label: const Text('0–9'),
                    selected: _digits,
                    onSelected: (v) {
                      _digits = v;
                      _regen();
                    }),
                FilterChip(
                    label: const Text('!@#'),
                    selected: _symbols,
                    onSelected: (v) {
                      _symbols = v;
                      _regen();
                    }),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _password),
                child: const Text('Use this password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
