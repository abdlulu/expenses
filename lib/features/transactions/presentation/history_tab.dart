import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/feedback.dart';
import '../../../shared/widgets/centered_message.dart';
import '../data/transactions_service.dart';
import '../domain/transaction_entry.dart';
import 'widgets/summary_metric.dart';
import 'widgets/transaction_form.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.service, required this.onFeedback});

  final TransactionsService service;
  final FeedbackCallback onFeedback;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _scrollController = ScrollController();
  final List<TransactionEntry> _items = [];
  TransactionPageCursor? _cursor;
  bool _isLoading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency();
    final dateFormat = DateFormat('MMM d, yyyy · h:mm a');

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Summary section (current month)
        StreamBuilder<List<TransactionEntry>>(
          stream: widget.service.watchMonth(DateTime.now()),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CenteredMessage(
                    icon: Icons.error_outline,
                    message: 'Unable to load summary.',
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

            final entries = snapshot.data!;
            final total = entries.fold<double>(0, (running, e) => running + e.amount);
            final count = entries.length;
            final dailyTotals = _groupByDay(entries);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        FutureBuilder(
                          future: widget.service.getPreviousMonthTotal(),
                          builder: (context, snapshot) {
                            String valueText;
                            if (snapshot.hasError) {
                              valueText = 'Error';
                            } else if (!snapshot.hasData) {
                              valueText = '...';
                            } else {
                              valueText = currency.format(snapshot.data!);
                            }
                            return SummaryMetric(
                              label: 'Previous month',
                              value: valueText,
                              icon: Icons.history_outlined,
                            );
                          },
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
        ),

        const SizedBox(height: 16),

        // History section (paginated)
        if (_error != null && _items.isEmpty)
          CenteredMessage(icon: Icons.error_outline, message: 'Something went wrong.\n$_error')
        else if (_items.isEmpty && _isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_items.isEmpty)
          const CenteredMessage(
            icon: Icons.inbox_outlined,
            message: 'No transactions yet.\nAdd one to get started.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = _items[index];
              return Dismissible(
                key: ValueKey(entry.id),
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    // Swipe right to edit
                    _editEntry(context, entry);
                    return false; // Do not dismiss
                  }
                  if (direction == DismissDirection.endToStart) {
                    // Swipe left to delete
                    final deleted = await _confirmDelete(context, entry);
                    return deleted;
                  }
                  return false;
                },
                onDismissed: (direction) {
                  // Remove locally after successful delete
                  setState(() {
                    _items.removeWhere((e) => e.id == entry.id);
                  });
                },
                child: Card(
                  child: ListTile(
                    title: Text(entry.note, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(dateFormat.format(entry.timestamp)),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        Text(
                          currency.format(entry.amount),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        // IconButton(
                        //   tooltip: 'Edit',
                        //   icon: const Icon(Icons.edit_outlined),
                        //   onPressed: () => _editEntry(context, entry),
                        // ),
                        // IconButton(
                        //   tooltip: 'Delete',
                        //   icon: const Icon(Icons.delete_outline),
                        //   onPressed: () => _confirmDelete(context, entry),
                        // ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

        if (_isLoading && _items.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  void _onScroll() {
    if (!_hasMore || _isLoading) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _error = null;
      _isLoading = true;
      _hasMore = true;
      _items.clear();
      _cursor = null;
    });
    try {
      final page = await widget.service.fetchPage(limit: 20);
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final page = await widget.service.fetchPage(cursor: _cursor, limit: 20);
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _isLoading = false;
      });
      widget.onFeedback('Unable to load more transactions', isError: true);
    }
  }

  void _editEntry(BuildContext context, TransactionEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: TransactionForm(
              initialDraft: entry.toDraft(),
              submitLabel: 'Save changes',
              onSuccess: () => Navigator.of(context).maybePop(),
              onSubmit: (draft) async {
                try {
                  await widget.service.updateTransaction(entry.id, draft);
                  // Update the local list immediately so the UI reflects changes
                  if (mounted) {
                    setState(() {
                      final index = _items.indexWhere((e) => e.id == entry.id);
                      if (index != -1) {
                        _items[index] = TransactionEntry(
                          id: entry.id,
                          note: draft.note,
                          amount: draft.amount!,
                          timestamp: draft.timestamp,
                          createdAt: entry.createdAt,
                          updatedAt: DateTime.now(),
                        );
                        // Keep list roughly in server order (newest first)
                        _items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                      }
                    });
                  }
                  widget.onFeedback('Transaction updated');
                } catch (_) {
                  widget.onFeedback('Unable to update transaction', isError: true);
                  rethrow;
                }
              },
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
          title: const Text('Delete transaction?'),
          content: Text('This will permanently remove "${entry.note}".'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return false;

    try {
      await widget.service.deleteTransaction(entry.id);
      widget.onFeedback('Transaction deleted');
      return true;
    } catch (_) {
      widget.onFeedback('Unable to delete transaction', isError: true);
      return false;
    }
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
