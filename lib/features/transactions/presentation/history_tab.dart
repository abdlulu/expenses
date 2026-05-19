import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/feedback.dart';
import '../../../shared/widgets/centered_message.dart';
import '../data/transactions_service.dart';
import '../domain/transaction_entry.dart';
import 'widgets/consolidate_sheet.dart';
import 'widgets/summary_metric.dart';
import 'widgets/transaction_form.dart';

const _kExpenseColor = Color(0xFFD32F2F);
const _kIncomeColor = Color(0xFF388E3C);

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.service, required this.onFeedback});

  final TransactionsService service;
  final FeedbackCallback onFeedback;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _scrollController = ScrollController();
  final Set<String> _pendingDelete = {};

  static final _currency = NumberFormat.simpleCurrency();
  static final _dateHeaderFormat = DateFormat('EEEE، d MMMM', 'ar');
  static final _timeFormat = DateFormat('h:mm a', 'ar');
  static final _dayBreakdownFormat = DateFormat('d MMM (EEE)', 'ar');
  static final _periodDateFormat = DateFormat('d MMM yyyy', 'ar');

  late Future<DateTime?> _consolidationDateFuture;

  @override
  void initState() {
    super.initState();
    _consolidationDateFuture = widget.service.getLastConsolidationDate();
  }

  void _refreshConsolidationDate() {
    _consolidationDateFuture = widget.service.getLastConsolidationDate();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _amountColor(double amount) => amount < 0 ? _kExpenseColor : _kIncomeColor;

  String _formatAmount(double amount) {
    final abs = _currency.format(amount.abs());
    return amount < 0 ? '-$abs' : '+$abs';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummarySection(),
        const SizedBox(height: 24),
        _buildHistorySection(context),
      ],
    );
  }

  Widget _buildSummarySection() {
    return FutureBuilder<DateTime?>(
      future: _consolidationDateFuture,
      builder: (context, dateSnap) {
        if (dateSnap.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final lastDate = dateSnap.data;
        final periodLabel = lastDate == null
            ? 'منذ البداية'
            : 'منذ ${_periodDateFormat.format(lastDate)}';

        return StreamBuilder<List<TransactionEntry>>(
          stream: widget.service.watchSince(lastDate),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CenteredMessage(
                    icon: Icons.error_outline,
                    message: 'تعذّر تحميل الملخص.',
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final entries = snapshot.data!.where((e) => !e.isSettlement).toList();
            final income = entries
                .where((e) => e.amount > 0)
                .fold<double>(0, (sum, e) => sum + e.amount);
            final expenses = entries
                .where((e) => e.amount < 0)
                .fold<double>(0, (sum, e) => sum + e.amount.abs());
            final balance = income - expenses;
            final count = entries.length;
            final dailyTotals = _groupByDay(entries);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.history_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              periodLabel,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        SummaryMetric(
                          label: 'الرصيد',
                          value: _formatAmount(balance),
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: _amountColor(balance),
                          valueColor: _amountColor(balance),
                        ),
                        SummaryMetric(
                          label: 'الدخل',
                          value: income > 0 ? '+${_currency.format(income)}' : _currency.format(0),
                          icon: Icons.arrow_upward_rounded,
                          iconColor: _kIncomeColor,
                          valueColor: income > 0 ? _kIncomeColor : null,
                        ),
                        SummaryMetric(
                          label: 'المصروفات',
                          value: expenses > 0 ? _currency.format(expenses) : _currency.format(0),
                          icon: Icons.arrow_downward_rounded,
                          iconColor: expenses > 0 ? _kExpenseColor : null,
                          valueColor: expenses > 0 ? _kExpenseColor : null,
                        ),
                        SummaryMetric(
                          label: 'عدد المعاملات',
                          value: count.toString(),
                          icon: Icons.receipt_long_outlined,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showConsolidateSheet(context),
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('تسوية الحساب'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                if (dailyTotals.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'التفاصيل اليومية',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: dailyTotals.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final entry = dailyTotals[index];
                              final dayNet = entry.value;
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _amountColor(dayNet),
                                  ),
                                ),
                                title: Text(_dayBreakdownFormat.format(entry.key)),
                                trailing: Text(
                                  _formatAmount(dayNet),
                                  style: TextStyle(
                                    color: _amountColor(dayNet),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHistorySection(BuildContext context) {
    return StreamBuilder<List<TransactionEntry>>(
      stream: widget.service.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const CenteredMessage(
            icon: Icons.error_outline,
            message: 'حدث خطأ ما.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!
            .where((e) => !_pendingDelete.contains(e.id))
            .toList();

        if (items.isEmpty) {
          return const CenteredMessage(
            icon: Icons.inbox_outlined,
            message: 'لا توجد معاملات بعد.\nأضف معاملة للبدء.',
          );
        }

        final listItems = _buildListItems(items);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 2, bottom: 12),
              child: Text(
                'سجل المعاملات',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: listItems.length,
              itemBuilder: (context, index) {
                final item = listItems[index];
                if (item.isHeader) return _buildDateHeader(context, item.date!);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildTransactionCard(context, item.entry!),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(BuildContext context, DateTime date) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final yesterday = today.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    String label;
    if (isToday) {
      label = 'اليوم  ·  ${_dateHeaderFormat.format(date)}';
    } else if (isYesterday) {
      label = 'أمس  ·  ${_dateHeaderFormat.format(date)}';
    } else {
      label = _dateHeaderFormat.format(date);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, TransactionEntry entry) {
    final color = _amountColor(entry.amount);
    return Dismissible(
      key: ValueKey(entry.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.edit_outlined,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _editEntry(context, entry);
          return false;
        }
        if (direction == DismissDirection.endToStart) {
          setState(() => _pendingDelete.add(entry.id));
          final deleted = await _confirmDelete(context, entry);
          if (!deleted) setState(() => _pendingDelete.remove(entry.id));
          return deleted;
        }
        return false;
      },
      onDismissed: (_) => _pendingDelete.remove(entry.id),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            // ignore: deprecated_member_use
            color: color.withOpacity(0.25),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(12, 4, 16, 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              entry.isSettlement
                  ? Icons.handshake_outlined
                  : (entry.amount < 0
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded),
              color: color,
              size: 20,
            ),
          ),
          title: Text(
            entry.note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            _timeFormat.format(entry.timestamp),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          trailing: Text(
            _formatAmount(entry.amount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  void _showConsolidateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ConsolidateSheet(
        service: widget.service,
        onFeedback: widget.onFeedback,
      ),
    ).then((_) {
      if (mounted) setState(_refreshConsolidationDate);
    });
  }

  void _editEntry(BuildContext context, TransactionEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'تعديل المعاملة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                TransactionForm(
                  initialDraft: entry.toDraft(),
                  submitLabel: 'حفظ التغييرات',
                  onSuccess: () => Navigator.of(context).maybePop(),
                  onSubmit: (draft) async {
                    try {
                      await widget.service.updateTransaction(entry.id, draft);
                      widget.onFeedback('تم تحديث المعاملة');
                    } catch (_) {
                      widget.onFeedback('تعذّر تحديث المعاملة', isError: true);
                      rethrow;
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context, TransactionEntry entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف المعاملة؟'),
          content: Text('سيتم حذف "${entry.note}" بشكل نهائي.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: _kExpenseColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return false;

    try {
      await widget.service.deleteTransaction(entry.id);
      widget.onFeedback('تم حذف المعاملة');
      return true;
    } catch (_) {
      widget.onFeedback('تعذّر حذف المعاملة', isError: true);
      return false;
    }
  }

  List<MapEntry<DateTime, double>> _groupByDay(List<TransactionEntry> entries) {
    final map = <DateTime, double>{};
    for (final entry in entries) {
      final day = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      map[day] = (map[day] ?? 0) + entry.amount;
    }
    return map.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
  }

  List<_ListItem> _buildListItems(List<TransactionEntry> items) {
    final result = <_ListItem>[];
    DateTime? lastDay;
    for (final entry in items) {
      final day = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      if (lastDay == null || day != lastDay) {
        result.add(_ListItem.header(day));
        lastDay = day;
      }
      result.add(_ListItem.transaction(entry));
    }
    return result;
  }
}

class _ListItem {
  _ListItem.header(DateTime this.date) : entry = null;
  _ListItem.transaction(TransactionEntry this.entry) : date = null;

  final DateTime? date;
  final TransactionEntry? entry;

  bool get isHeader => date != null;
}
