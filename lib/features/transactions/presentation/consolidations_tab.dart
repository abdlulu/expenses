import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/centered_message.dart';
import '../data/transactions_service.dart';
import '../domain/consolidation_record.dart';

class ConsolidationsTab extends StatelessWidget {
  const ConsolidationsTab({super.key, required this.service});

  final TransactionsService service;

  static final _currency = NumberFormat.simpleCurrency();
  static final _dateFormat = DateFormat('d MMM yyyy', 'ar');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConsolidationRecord>>(
      stream: service.watchConsolidations(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const CenteredMessage(
            icon: Icons.error_outline,
            message: 'تعذّر تحميل التسويات.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data!;
        if (records.isEmpty) {
          return const CenteredMessage(
            icon: Icons.handshake_outlined,
            message: 'لا توجد تسويات بعد.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) => _buildCard(context, records[index]),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, ConsolidationRecord record) {
    final theme = Theme.of(context);
    final periodStart = record.periodStart == null
        ? 'البداية'
        : _dateFormat.format(record.periodStart!);
    final periodEnd = _dateFormat.format(record.periodEnd);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.handshake_outlined,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  _dateFormat.format(record.settledAt),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  _currency.format(record.amount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'الفترة: $periodStart ← $periodEnd',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
