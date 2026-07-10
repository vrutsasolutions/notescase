import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';

/// Repository: the only class in the app that talks to Firestore.
///
/// Data layout:  users/{uid}/notes/{noteId}
class NoteRepository {
  NoteRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _notes(String uid) =>
      _db.collection('users').doc(uid).collection('notes');

  /// Realtime stream of every note, newest first.
  Stream<List<Note>> watchAll(String uid) => _notes(uid)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => Note.fromDoc(d.id, d.data())).toList());

  /// Create or update (full overwrite of the document).
  Future<void> upsert(String uid, Note n) => _notes(uid).doc(n.id).set(n.toMap());

  /// Permanent delete.
  Future<void> deleteForever(String uid, String id) =>
      _notes(uid).doc(id).delete();

  /// Permanently delete everything currently in the trash.
  Future<void> emptyTrash(String uid) async {
    final snap = await _notes(uid).where('deleted', isEqualTo: true).get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  /// Auto-purge trash older than 30 days (uses the composite index in
  /// firestore.indexes.json: deleted ASC + updatedAt ASC).
  Future<void> purgeOldTrash(String uid) async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    final snap = await _notes(uid)
        .where('deleted', isEqualTo: true)
        .where('updatedAt', isLessThan: cutoff)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}
