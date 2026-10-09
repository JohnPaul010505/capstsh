import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/design_tokens.dart';

/// Bottom sheet for applying for a (re)newal: plan + months (or a custom
/// start/end window) + optional note.
/// Returns a map {plan_name, months, note, start_date, end_date} when
/// submitted, null otherwise.
class RenewalRequestSheet extends StatefulWidget {
  final String currentPlanName;

  const RenewalRequestSheet({super.key, required this.currentPlanName});

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String currentPlanName,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RenewalRequestSheet(currentPlanName: currentPlanName),
    );
  }

  @override
  State<RenewalRequestSheet> createState() => _RenewalRequestSheetState();
}

class _RenewalRequestSheetState extends State<RenewalRequestSheet> {
  late String _plan = widget.currentPlanName == 'Daily' ? 'Daily' : 'Monthly';
  int _months = 1;

  /// When the member turns on a custom window, they pick explicit start/end
  /// dates instead of a month count. [_useCustomDates] gates that section.
  bool _useCustomDates = false;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  final _noteController = TextEditingController();

  static const List<int> _monthOptions = [1, 2, 3, 4, 5, 6];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final first = isStart
        ? DateTime.now().subtract(const Duration(days: 1))
        : _startDate;
    var temp = initial.isBefore(first) ? first : initial;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GlassDatePicker(
        initial: temp,
        minimumDate: DateTime.now().subtract(const Duration(days: 365)),
        maximumDate: DateTime.now().add(const Duration(days: 365 * 3)),
        onChanged: (d) => temp = d,
      ),
    );
    if (!mounted) return;
    setState(() {
      if (isStart) {
        _startDate = temp;
        // Keep the window sane: end date can never precede the start date.
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      } else {
        _endDate = temp;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMonthly = _plan == 'Monthly';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _GlassSheet(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(60),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const Text(
                'Apply for Membership Renewal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'The admin will be notified and can accept or decline your request.',
                style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
              ),
              const SizedBox(height: 18),
              const _Label('PLAN'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _planButton('Daily')),
                  const SizedBox(width: 10),
                  Expanded(child: _planButton('Monthly')),
                ],
              ),
              if (isMonthly) ...[
                const SizedBox(height: 18),
                _customDatesToggle(),
                if (!_useCustomDates) ...[
                  const SizedBox(height: 14),
                  const _Label('MONTHS'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final m in _monthOptions) ...[
                        Expanded(child: _monthButton(m)),
                        if (m != _monthOptions.last) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  const _Label('CUSTOM DATES'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _dateButton(
                          label: 'Start',
                          date: _startDate,
                          isStart: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dateButton(
                          label: 'End',
                          date: _endDate,
                          isStart: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 18),
              _noteField(),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _submit,
                  child: const Text(
                    'Submit Request',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _customDatesToggle() {
    return GestureDetector(
      onTap: () => setState(() => _useCustomDates = !_useCustomDates),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _useCustomDates
              ? ClayTokens.clayPrimary.withAlpha(30)
              : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _useCustomDates
                ? ClayTokens.clayPrimary
                : Colors.white.withAlpha(30),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _useCustomDates
                  ? CupertinoIcons.checkmark_square_fill
                  : CupertinoIcons.square,
              size: 18,
              color: _useCustomDates
                  ? ClayTokens.clayPrimaryLight
                  : Colors.white70,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Custom start & end date',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime date,
    required bool isStart,
  }) {
    return GestureDetector(
      onTap: () => _pickDate(isStart: isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  CupertinoIcons.calendar,
                  size: 14,
                  color: ClayTokens.clayPrimaryLight,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM d, y').format(date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _planButton(String plan) {
    final selected = _plan == plan;
    return GestureDetector(
      onTap: () => setState(() {
        _plan = plan;
        if (plan == 'Daily') {
          _months = 1;
          _useCustomDates = false;
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? ClayTokens.clayPrimary : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? ClayTokens.clayPrimary
                : Colors.white.withAlpha(30),
          ),
        ),
        child: Text(
          plan,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFFA0A4B8),
          ),
        ),
      ),
    );
  }

  Widget _monthButton(int m) {
    final selected = _months == m;
    return GestureDetector(
      onTap: () => setState(() => _months = m),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? ClayTokens.clayPrimary : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? ClayTokens.clayPrimary
                : Colors.white.withAlpha(30),
          ),
        ),
        child: Text(
          '$m',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFFA0A4B8),
          ),
        ),
      ),
    );
  }

  Widget _noteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NOTE (OPTIONAL)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8E8E93),
          ),
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: _noteController,
          placeholder: 'Anything the admin should know?',
          style: const TextStyle(color: Colors.white, fontSize: 14),
          placeholderStyle: const TextStyle(
            color: Color(0xFF636366),
            fontSize: 14,
          ),
          maxLines: 2,
          minLines: 1,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
        ),
      ],
    );
  }

  void _submit() {
    // Derive a month count from a custom window so the admin still sees a
    // sensible number even when the member picked explicit dates.
    var months = _plan == 'Daily' ? 1 : _months;
    if (_plan == 'Monthly' && _useCustomDates) {
      var m = (_endDate.year - _startDate.year) * 12 +
          (_endDate.month - _startDate.month);
      if (_endDate.day < _startDate.day) m -= 1;
      months = m < 1 ? 1 : m;
    }
    Navigator.of(context).pop({
      'plan_name': _plan,
      'months': months,
      'note': _noteController.text.trim(),
      'start_date':
          (_plan == 'Monthly' && _useCustomDates) ? _startDate : null,
      'end_date': (_plan == 'Monthly' && _useCustomDates) ? _endDate : null,
    });
  }
}

/// Small uppercase field label used across the sheet.
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF8E8E93),
        letterSpacing: 0.4,
      ),
    );
  }
}

/// Liquid-glass container for the sheet body: blurred backdrop, navy to
/// indigo gradient, white rim.
class _GlassSheet extends StatelessWidget {
  final Widget child;
  const _GlassSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A1636).withAlpha(235),
                const Color(0xFF14142A).withAlpha(245),
              ],
            ),
            border: Border(
              top: BorderSide(color: Colors.white.withAlpha(38)),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassDatePicker extends StatefulWidget {
  final DateTime initial;
  final DateTime minimumDate;
  final DateTime maximumDate;
  final ValueChanged<DateTime> onChanged;

  const _GlassDatePicker({
    required this.initial,
    required this.minimumDate,
    required this.maximumDate,
    required this.onChanged,
  });

  @override
  State<_GlassDatePicker> createState() => _GlassDatePickerState();
}

class _GlassDatePickerState extends State<_GlassDatePicker> {
  late DateTime _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1636).withAlpha(240),
            const Color(0xFF14142A).withAlpha(250),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withAlpha(38))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () {
                    widget.onChanged(_selected);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: widget.initial,
                minimumDate: widget.minimumDate,
                maximumDate: widget.maximumDate,
                onDateTimeChanged: (d) => setState(() => _selected = d),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
