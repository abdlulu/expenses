class TransactionDraft {
  const TransactionDraft({
    required this.note,
    required this.amount,
    required this.timestamp,
  });

  factory TransactionDraft.empty() =>
      TransactionDraft(note: '', amount: null, timestamp: DateTime.now());

  final String note;
  final double? amount;
  final DateTime timestamp;

  TransactionDraft copyWith({
    String? note,
    double? amount,
    DateTime? timestamp,
  }) {
    return TransactionDraft(
      note: note ?? this.note,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
