import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/centered_message.dart';
import '../data/transactions_service.dart';
import '../domain/transaction_entry.dart';
import 'widgets/summary_metric.dart';

class SummaryTab extends StatelessWidget {
  const SummaryTab({super.key, required this.service});

  final TransactionsService service;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return StreamBuilder<List<TransactionEntry>>(
      stream: service.watchMonth(now),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return CenteredMessage(
            icon: Icons.error_outline,
            message: 'Unable to load summary.\n${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = snapshot.data!;
        final currency = NumberFormat.simpleCurrency();
        final total = entries.fold<double>(0, (running, e) => running + e.amount);
        final count = entries.length;
        final dailyTotals = _groupByDay(entries);

        return ListView(
          primary: false,
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current month', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SummaryMetric(
                      label: 'Total',
                      value: currency.format(total),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    SummaryMetric(
                      label: 'Transactions',
                      value: count.toString(),
                      icon: Icons.receipt_long_outlined,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Per-day breakdown', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (dailyTotals.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CenteredMessage(
                          icon: Icons.event_available_outlined,
                          message: 'No data yet this month.',
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: dailyTotals.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = dailyTotals[index];
                          final label = DateFormat('MMM d (EEE)').format(entry.key);
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(label),
                            trailing: Text(currency.format(entry.value)),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<MapEntry<DateTime, double>> _groupByDay(List<TransactionEntry> entries) {
    final map = <DateTime, double>{};
    for (final entry in entries) {
      final day = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      map[day] = (map[day] ?? 0) + entry.amount;
    }
    final result = map.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return result;
  }
}
