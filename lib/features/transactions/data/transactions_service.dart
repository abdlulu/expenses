import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/transaction_draft.dart';
import '../domain/transaction_entry.dart';

class TransactionsService {
  TransactionsService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection('transactions');

  Stream<List<TransactionEntry>> watchAll() {
    return _transactions
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(TransactionEntry.fromDoc).toList());
  }

  Stream<List<TransactionEntry>> watchMonth(DateTime anchor) {
    final start = DateTime(anchor.year, anchor.month);
    final end = DateTime(anchor.year, anchor.month + 1);
    return _transactions
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(TransactionEntry.fromDoc).toList());
  }

  Future<double> getPreviousMonthTotal() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1);
    final end = DateTime(now.year, now.month);
    final querySnapshot = await _transactions
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .aggregate(sum('amount'))
        .get();

    // Get the sum result (num? -> double)
    final num? sumAmount = querySnapshot.getSum('amount');
    return (sumAmount ?? 0).toDouble();
  }

  Future<void> addTransaction(TransactionDraft draft) async {
    if (draft.amount == null) {
      throw ArgumentError('Amount is required');
    }

    await _transactions.add({
      'note': draft.note,
      'amount': draft.amount,
      'timestamp': Timestamp.fromDate(draft.timestamp),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTransaction(String id, TransactionDraft draft) async {
    if (draft.amount == null) {
      throw ArgumentError('Amount is required');
    }

    await _transactions.doc(id).update({
      'note': draft.note,
      'amount': draft.amount,
      'timestamp': Timestamp.fromDate(draft.timestamp),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTransaction(String id) async {
    await _transactions.doc(id).delete();
  }

  /// Fetch a single page of transactions ordered by timestamp desc, then id desc.
  /// Provide [cursor] from the previous page to fetch the next page.
  Future<TransactionPage> fetchPage({TransactionPageCursor? cursor, int limit = 20}) async {
    Query<Map<String, dynamic>> query = _transactions
        .orderBy('timestamp', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit);

    if (cursor != null) {
      query = query.startAfter([Timestamp.fromDate(cursor.lastTimestamp.toUtc()), cursor.lastId]);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;
    final entries = docs.map(TransactionEntry.fromDoc).toList();

    final hasMore = docs.length == limit;
    TransactionPageCursor? nextCursor;
    if (docs.isNotEmpty) {
      final last = docs.last;
      final ts = (last.data()['timestamp'] as Timestamp).toDate().toLocal();
      nextCursor = TransactionPageCursor(lastTimestamp: ts, lastId: last.id);
    }

    return TransactionPage(
      items: entries,
      nextCursor: hasMore ? nextCursor : null,
      hasMore: hasMore,
    );
  }
}

class TransactionPageCursor {
  TransactionPageCursor({required this.lastTimestamp, required this.lastId});

  final DateTime lastTimestamp;
  final String lastId;
}

class TransactionPage {
  TransactionPage({required this.items, required this.nextCursor, required this.hasMore});

  final List<TransactionEntry> items;
  final TransactionPageCursor? nextCursor;
  final bool hasMore;
}
