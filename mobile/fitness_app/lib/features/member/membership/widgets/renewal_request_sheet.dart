import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';

/// Bottom sheet for applying for a (re)newal: plan + months + optional note.
/// Returns a map {plan_name, months, note} when submitted, null otherwise.
class RenewalRequestSheet extends StatefulWidget {
  final String currentPlanName;

  const RenewalRequestSheet({super.key, required this.currentPlanName});

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String currentPlanName,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: ClayTokens.clayDarkSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
  final _noteController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apply for Membership Renewal',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'The admin will be notified and can accept or decline your request.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: 16),
            const Text('PLAN', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8E8E93),
            )),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _planButton('Daily')),
                const SizedBox(width: 10),
                Expanded(child: _planButton('Monthly')),
              ],
            ),
            if (_plan == 'Monthly') ...[
              const SizedBox(height: 16),
              const Text('MONTHS', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8E8E93),
              )),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final m in const [1, 3, 6, 12]) ...[
                    Expanded(child: _monthButton(m)),
                    if (m != 12) const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 16),
            _noteField(),
            const SizedBox(height: 20),
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
    );
  }

  Widget _planButton(String plan) {
    final selected = _plan == plan;
    return GestureDetector(
      onTap: () => setState(() {
        _plan = plan;
        if (plan == 'Daily') _months = 1;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? ClayTokens.clayPrimary : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? ClayTokens.clayPrimary : Colors.white.withAlpha(30),
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
            color: selected ? ClayTokens.clayPrimary : Colors.white.withAlpha(30),
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
        const Text('NOTE (OPTIONAL)', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8E8E93),
        )),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: _noteController,
          placeholder: 'Anything the admin should know?',
          style: const TextStyle(color: Colors.white, fontSize: 14),
          placeholderStyle: const TextStyle(color: Color(0xFF636366), fontSize: 14),
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
    Navigator.of(context).pop({
      'plan_name': _plan,
      'months': _plan == 'Daily' ? 1 : _months,
      'note': _noteController.text.trim(),
    });
  }
}
