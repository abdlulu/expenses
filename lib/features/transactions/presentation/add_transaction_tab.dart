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
      onFeedback('تمت إضافة المعاملة بنجاح');
      focusNode.unfocus();
    } catch (_) {
      onFeedback('تعذّر إضافة المعاملة', isError: true);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FocusScope(
      node: focusNode,
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: GestureDetector(
          onTap: () => focusNode.unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 2, bottom: 16),
                  child: Text(
                    'معاملة جديدة',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: TransactionForm(
                      submitLabel: 'حفظ المعاملة',
                      clearOnSubmit: true,
                      onSubmit: _create,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
