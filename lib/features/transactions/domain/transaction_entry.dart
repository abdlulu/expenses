import 'package:cloud_firestore/cloud_firestore.dart';

import 'transaction_draft.dart';

class TransactionEntry {
  TransactionEntry({
    required this.id,
    required this.note,
    required this.amount,
    required this.timestamp,
    this.createdAt,
    this.updatedAt,
    this.type,
  });

  final String id;
  final String note;
  final double amount;
  final DateTime timestamp;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? type;

  bool get isSettlement => type == 'settlement';

  factory TransactionEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    DateTime? toDateOrNull(dynamic value) {
      if (value is Timestamp) return value.toDate().toLocal();
      return null;
    }

    return TransactionEntry(
      id: doc.id,
      note: (data['note'] as String?) ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      timestamp: toDateOrNull(data['timestamp']) ?? DateTime.now(),
      createdAt: toDateOrNull(data['createdAt']),
      updatedAt: toDateOrNull(data['updatedAt']),
      type: data['type'] as String?,
    );
  }

  TransactionDraft toDraft() =>
      TransactionDraft(note: note, amount: amount, timestamp: timestamp);
}
