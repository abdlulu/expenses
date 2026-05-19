import 'package:flutter/material.dart';

import '../../../shared/feedback.dart';
import 'widgets/transaction_form.dart';
import '../data/transactions_service.dart';
import '../domain/transaction_draft.dart';

class AddTransactionTab extends StatelessWidget {
  AddTransactionTab({super.key, required this.service, required this.onFeedback});

  final TransactionsService service;
  final FeedbackCallback onFeedback;
  final FocusScopeNode focusNode = FocusScopeNode();

  Future<void> _create(TransactionDraft draft) async {
    try {
      await service.addTransaction(draft);
      onFeedback('Transaction added successfully');
      focusNode.unfocus();
    } catch (_) {
      onFeedback('Unable to add transaction', isError: true);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: focusNode,
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: GestureDetector(
          onTap: () => focusNode.unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TransactionForm(
                  submitLabel: 'Save transaction',
                  clearOnSubmit: true,
                  onSubmit: _create,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
