import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../transactions/domain/transaction_draft.dart';

typedef TransactionSubmitter = Future<void> Function(TransactionDraft draft);

class TransactionForm extends StatefulWidget {
  const TransactionForm({
    super.key,
    required this.onSubmit,
    this.initialDraft,
    this.submitLabel = 'Save',
    this.clearOnSubmit = false,
    this.onSuccess,
  });

  final TransactionSubmitter onSubmit;
  final TransactionDraft? initialDraft;
  final String submitLabel;
  final bool clearOnSubmit;
  final VoidCallback? onSuccess;

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _noteController;
  late final TextEditingController _amountController;
  late DateTime _timestamp;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDraft ?? TransactionDraft.empty();
    _noteController = TextEditingController(text: initial.note);
    _amountController = TextEditingController(
      text: initial.amount != null ? initial.amount!.toStringAsFixed(2) : '',
    );
    _timestamp = initial.timestamp;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d — h:mm a');
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'e.g. Coffee with Alex',
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Note is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Amount is required';
              }
              final parsed = double.tryParse(value.trim());
              if (parsed == null) {
                return 'Enter a valid number';
              }
              if (parsed <= 0) {
                return 'Amount must be greater than zero';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date & time',
              border: OutlineInputBorder(),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(dateFormat.format(_timestamp)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDateTime,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(widget.submitLabel),
              onPressed: _submitting ? null : _handleSubmit,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _timestamp,
      firstDate: DateTime(_timestamp.year - 1),
      lastDate: DateTime(_timestamp.year + 1),
    );
    if (pickedDate == null) return;

    if (!mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
    );
    if (pickedTime == null) return;

    if (!mounted) return;

    setState(() {
      _timestamp = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.trim());
    final draft = TransactionDraft(
      note: _noteController.text.trim(),
      amount: amount,
      timestamp: _timestamp,
    );

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(draft);
      widget.onSuccess?.call();
      if (widget.clearOnSubmit) {
        _noteController.clear();
        _amountController.clear();
        setState(() {
          _timestamp = DateTime.now();
        });
      }
    } catch (_) {
      // Feedback surfaced by parent SnackBars.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
