import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../transactions/domain/transaction_draft.dart';

typedef TransactionSubmitter = Future<void> Function(TransactionDraft draft);

class TransactionForm extends StatefulWidget {
  const TransactionForm({
    super.key,
    required this.onSubmit,
    this.initialDraft,
    this.submitLabel = 'حفظ',
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

  TextInputType get _amountKeyboardType {
    if (kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return TextInputType.text;
    }

    return const TextInputType.numberWithOptions(decimal: true, signed: true);
  }

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
    final dateFormat = DateFormat('EEE، d MMM — h:mm a', 'ar');

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الوصف
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'الوصف',
              hintText: 'مثال: قهوة مع أحمد',
              prefixIcon: const Icon(Icons.description_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'الوصف مطلوب';
              return null;
            },
          ),
          const SizedBox(height: 16),
          // المبلغ
          TextFormField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'المبلغ',
              hintText: 'مثال: -15.00 أو 100.00',
              prefixIcon: const Icon(Icons.attach_money_outlined),
              prefixText: '\$ ',
              suffixIcon: IconButton(
                tooltip: 'تبديل الإشارة',
                icon: const Icon(Icons.exposure_neg_1_outlined),
                onPressed: _toggleAmountSign,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: _amountKeyboardType,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'المبلغ مطلوب';
              final parsed = double.tryParse(value.trim());
              if (parsed == null) return 'أدخل رقماً صحيحاً';
              if (parsed == 0) return 'المبلغ لا يمكن أن يكون صفراً';
              return null;
            },
          ),
          const SizedBox(height: 16),
          // التاريخ والوقت
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'التاريخ والوقت',
              prefixIcon: const Icon(Icons.calendar_today_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateFormat.format(_timestamp)),
                    const Icon(Icons.edit_calendar_outlined, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          // زر الحفظ
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(
                widget.submitLabel,
                style: const TextStyle(fontSize: 16),
              ),
              onPressed: _submitting ? null : _handleSubmit,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleAmountSign() {
    final text = _amountController.text.trim();
    final nextText = text.startsWith('-') ? text.substring(1) : '-$text';
    _amountController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
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
        setState(() => _timestamp = DateTime.now());
      }
    } catch (_) {
      // Feedback surfaced by parent.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
