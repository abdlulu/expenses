import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/feedback.dart';
import '../../data/transactions_service.dart';
import '../../domain/transaction_entry.dart';

class ConsolidateSheet extends StatefulWidget {
  const ConsolidateSheet({super.key, required this.service, required this.onFeedback});

  final TransactionsService service;
  final FeedbackCallback onFeedback;

  @override
  State<ConsolidateSheet> createState() => _ConsolidateSheetState();
}

class _ConsolidateSheetState extends State<ConsolidateSheet> {
  static final _currency = NumberFormat.simpleCurrency();
  static final _dateFormat = DateFormat('d MMM yyyy', 'ar');

  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DateTime?>(
      future: widget.service.getLastConsolidationDate(),
      builder: (context, dateSnap) {
        if (dateSnap.connectionState == ConnectionState.waiting) {
          return const _SheetShell(child: Center(child: CircularProgressIndicator()));
        }
        final lastDate = dateSnap.data;

        return StreamBuilder<List<TransactionEntry>>(
          stream: widget.service.watchSince(lastDate),
          builder: (context, txSnap) {
            if (txSnap.hasError) {
              return _SheetShell(child: Center(child: Text('خطأ: ${txSnap.error}')));
            }
            if (!txSnap.hasData) {
              return const _SheetShell(child: Center(child: CircularProgressIndicator()));
            }

            final entries = txSnap.data!.where((e) => !e.isSettlement).toList();
            final income = entries
                .where((e) => e.amount > 0)
                .fold<double>(0, (sum, e) => sum + e.amount);
            final expenses = entries
                .where((e) => e.amount < 0)
                .fold<double>(0, (sum, e) => sum + e.amount.abs());
            final net = income - expenses;
            final halfNet = net / 2; // (income - expense) / 2, negative when owed
            final settlementAmount = -halfNet; // positive transaction recorded on settle

            final periodLabel = lastDate == null
                ? 'منذ البداية'
                : 'منذ ${_dateFormat.format(lastDate)}';

            return _SheetShell(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(Icons.handshake_outlined, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'تسوية الحساب',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الفترة: $periodLabel حتى اليوم',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Breakdown
                  _MetricRow(label: 'الدخل', value: _currency.format(income)),
                  _MetricRow(label: 'المصاريف', value: _currency.format(expenses)),
                  _MetricRow(
                    label: 'الرصيد الصافي',
                    value: _currency.format(net),
                    valueColor: net < 0 ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
                  ),
                  const Divider(height: 24),
                  _MetricRow(
                    label: 'المستحق التحصيل',
                    value: _currency.format(halfNet),
                    valueColor: const Color(0xFFD32F2F),
                    bold: true,
                  ),
                  const SizedBox(height: 24),

                  // Action button
                  if (halfNet < 0)
                    FilledButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _confirm(context, settlementAmount, lastDate),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('تأكيد التسوية: ${_currency.format(settlementAmount)}'),
                    )
                  else
                    OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _markSettled(context, lastDate, halfNet),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('تم التسوية بالكامل'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _markSettled(BuildContext context, DateTime? periodStart, double amount) async {
    setState(() => _isSubmitting = true);
    try {
      await widget.service.recordConsolidation(
        amount: amount,
        periodStart: periodStart,
        settledAt: DateTime.now(),
      );
      if (context.mounted) Navigator.of(context).maybePop();
      widget.onFeedback('تم تحديث تاريخ التسوية');
    } catch (_) {
      widget.onFeedback('تعذّر تحديث التسوية', isError: true);
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirm(BuildContext context, double amount, DateTime? periodStart) async {
    setState(() => _isSubmitting = true);
    try {
      await widget.service.recordConsolidation(
        amount: amount,
        periodStart: periodStart,
        settledAt: DateTime.now(),
      );
      if (context.mounted) Navigator.of(context).maybePop();
      widget.onFeedback('تمت التسوية بنجاح');
    } catch (_) {
      widget.onFeedback('تعذّر إتمام التسوية', isError: true);
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value, this.valueColor, this.bold = false});

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
