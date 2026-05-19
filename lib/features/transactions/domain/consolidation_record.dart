import 'package:cloud_firestore/cloud_firestore.dart';

class ConsolidationRecord {
  const ConsolidationRecord({
    required this.id,
    required this.amount,
    required this.periodStart,
    required this.periodEnd,
    required this.settledAt,
  });

  final String id;
  final double amount;
  final DateTime? periodStart;
  final DateTime periodEnd;
  final DateTime settledAt;

  factory ConsolidationRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime? toDate(dynamic v) => v is Timestamp ? v.toDate().toLocal() : null;
    return ConsolidationRecord(
      id: doc.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      periodStart: toDate(data['periodStart']),
      periodEnd: toDate(data['periodEnd']) ?? DateTime.now(),
      settledAt: toDate(data['settledAt']) ?? DateTime.now(),
    );
  }
}
