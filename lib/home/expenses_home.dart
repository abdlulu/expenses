import 'package:flutter/material.dart';

import '../features/transactions/data/transactions_service.dart';
import '../features/transactions/presentation/add_transaction_tab.dart';
import '../features/transactions/presentation/consolidations_tab.dart';
import '../features/transactions/presentation/history_tab.dart';

class ExpensesHome extends StatefulWidget {
  const ExpensesHome({super.key, required this.service});

  final TransactionsService service;

  @override
  State<ExpensesHome> createState() => _ExpensesHomeState();
}

class _ExpensesHomeState extends State<ExpensesHome> {
  int _currentIndex = 0;

  void _handleFeedback(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      AddTransactionTab(service: widget.service, onFeedback: _handleFeedback),
      HistoryTab(service: widget.service, onFeedback: _handleFeedback),
      ConsolidationsTab(service: widget.service),
    ];

    const titles = ['إضافة', 'السجل', 'التسويات'];

    return Scaffold(
      appBar: AppBar(title: Text('المعاملات · ${titles[_currentIndex]}')),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outlined),
            label: 'إضافة',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'السجل'),
          BottomNavigationBarItem(
            icon: Icon(Icons.handshake_outlined),
            label: 'التسويات',
          ),
        ],
      ),
    );
  }
}
