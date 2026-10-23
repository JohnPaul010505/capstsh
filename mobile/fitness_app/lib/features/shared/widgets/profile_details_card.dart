import 'pressable.dart';
import 'app_glow_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:async';

import 'glass_card.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared/services/supabase_client.dart';

import 'package:shared/providers/auth_provider.dart';
import 'package:shared/models/profile.dart';

import '../../../../app/design_tokens.dart';
import '../../../shared/utils/trainer_availability_time.dart';

String _clockLabel(String value) {
  final parts = value.split(':');
  final hour = int.parse(parts[0]);
  return '${hour % 12 == 0 ? 12 : hour % 12}:${parts[1]} ${hour < 12 ? 'AM' : 'PM'}';
}

String _scheduleLabel(String? value) {
  return formatTrainerAvailability(value).replaceAll(',', '\n');
}

const personalFields = <String, String>{
  'full_name': 'Full name',

  'phone': 'Phone',

  'date_of_birth': 'Date of birth (YYYY-MM-DD)',

  'gender': 'Gender',

  'civil_status': 'Civil status',

  'religion': 'Religion',

  'religion_other': 'Other religion',

  'address': 'Address',

  'emergency_contact_name': 'Emergency contact',

  'emergency_contact_phone': 'Emergency phone',
};

class PersonalDetails extends ConsumerStatefulWidget {
  final String userId;

  final bool editable;

  final bool trainer;

  const PersonalDetails({
    super.key,

    required this.userId,

    this.editable = false,

    this.trainer = false,
  });

  @override
  ConsumerState<PersonalDetails> createState() => _PersonalDetailsState();
}

class _PersonalDetailsState extends ConsumerState<PersonalDetails> {
  final fields = <String, TextEditingController>{};

  Map<String, dynamic>? profile;

  String? error;

  bool saving = false;

  bool editing = false;

  StreamSubscription? subscription;

  Map<String, String> get labels => {
    ...personalFields,

    if (widget.trainer) ...{
      'specialty': 'Specialty',

      'available_days': 'Availability (Mon 08:00-17:00, Tue 09:00-18:00)',
    },
  };

  @override
  void initState() {
    super.initState();

    _load();

    subscription = SupabaseClientService().client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', widget.userId)
        .listen((rows) {
          if (rows.isNotEmpty && mounted && !editing && !saving) {
            _receive(rows.first);
          }
        });
  }

  Future<void> _load() async {
    try {
      final row = await SupabaseClientService().client
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .single();

      if (!mounted) return;

      _receive(row);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not load details. Please try again.');
      }
    }
  }

  void _receive(Map<String, dynamic> row) {
    for (final key in labels.keys) {
      final controller = fields.putIfAbsent(key, () => TextEditingController());

      controller.text = row[key]?.toString() ?? '';
    }

    setState(() => profile = row);
  }

  @override
  void dispose() {
    subscription?.cancel();

    for (final controller in fields.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;

    final client = SupabaseClientService().client;

    if (client.auth.currentUser?.id != widget.userId) {
      setState(() => error = 'Your session has ended. Sign in again to save.');
      return;
    }

    final updates = <String, dynamic>{
      for (final entry in fields.entries)
        entry.key: entry.value.text.trim().isEmpty
            ? null
            : entry.value.text.trim(),
    };

    if (updates['full_name'] == null) {
      setState(() => error = 'Full name is required.');

      return;
    }

    final birth = updates['date_of_birth'] as String?;

    if (birth != null &&
        (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(birth) ||
            DateTime.tryParse(birth) == null)) {
      setState(() => error = 'Enter a valid birth date as YYYY-MM-DD.');

      return;
    }

    if (widget.trainer && updates['available_days'] != null) {
      for (final day in (updates['available_days'] as String).split(',')) {
        final match = RegExp(
          r'^(Mon|Tue|Wed|Thu|Fri|Sat|Sun) ([0-2]\d:[0-5]\d)-([0-2]\d:[0-5]\d)$',
        ).firstMatch(day.trim());

        if (match == null ||
            match[2]!.compareTo(match[3]!) >= 0 ||
            int.parse(match[2]!.substring(0, 2)) > 23 ||
            int.parse(match[3]!.substring(0, 2)) > 23) {
          setState(
            () => error =
                'Check ${day.trim().split(' ').first}: select both times and make the end time later than the start time.',
          );

          return;
        }
      }
    }

    setState(() {
      saving = true;

      error = null;
    });

    try {
      String? warning;

      // Both roles save through their own authenticated Supabase session.
      // A phone must not depend on the admin PC's localhost API to save.
      final previous = profile!;
      final saved = await client
          .from('profiles')
          .update(updates)
          .eq('id', widget.userId)
          .select()
          .single();

      if (!mounted) return;
      setState(() {
        profile = saved;
        editing = false;
      });

      ref.read(authProvider.notifier).setProfile(Profile.fromJson(saved));
      setState(() => saving = false);

      if (widget.trainer &&
          (previous['specialty'] != saved['specialty'] ||
              previous['available_days'] != saved['available_days'])) {
        try {
          final assignments = await client
              .from('trainer_assignments')
              .select('member_id')
              .eq('trainer_id', widget.userId)
              .eq('status', 'active');
          final recipients = assignments
              .map((row) => row['member_id'] as String)
              .toSet();
          if (recipients.isNotEmpty) {
            await client.from('notifications').insert([
              for (final id in recipients)
                {
                  'user_id': id,
                  'title': 'Trainer details updated',
                  'sender_name': saved['full_name'],
                  'body':
                      '${saved['full_name']} updated their details. '
                      'Specialty: ${saved['specialty'] ?? 'Not specified'}. '
                      'Availability: ${saved['available_days'] ?? 'Not provided'}.',
                },
            ]);
          }
        } catch (_) {
          warning = 'Details saved. Member notifications could not be sent.';
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(warning ?? 'Details saved')));
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => error = 'Could not save details: ${e.message}');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not connect to save your details. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Padding(
        padding: const EdgeInsets.all(16),

        child: error == null
            ? const Center(child: CircularProgressIndicator())
            : Text(error!),
      );
    }

    Widget field(String key) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: editing
          ? TextField(
              controller: fields[key],
              enabled: !saving,
              style: TextStyle(color: ClayTokens.clayDarkTextPrimary),
              decoration: InputDecoration(
                labelText: labels[key],
                border: const OutlineInputBorder(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labels[key]!,
                  style: TextStyle(
                    fontSize: 12,
                    color: ClayTokens.clayDarkTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile![key]?.toString() ?? 'Not provided',
                  style: TextStyle(
                    color: ClayTokens.clayDarkTextPrimary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
    );

    Widget card(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MemberGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ClayTokens.clayDarkTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card('Personal information', [
            Text(
              'Email: ${profile!['email'] ?? '—'}',
              style: TextStyle(color: ClayTokens.clayDarkTextSecondary),
            ),
            Text(
              'ID: ${profile!['code'] ?? '—'}',
              style: TextStyle(color: ClayTokens.clayDarkTextSecondary),
            ),
            for (final key in personalFields.keys) field(key),
          ]),

          if (widget.trainer) card('Specialty', [field('specialty')]),

          if (widget.trainer)
            card('Availability', [
              editing
                  ? _schedule()
                  : Text(
                      _scheduleLabel(profile!['available_days'] as String?),
                      style: TextStyle(color: ClayTokens.clayDarkTextPrimary),
                    ),
            ]),

          if (widget.editable) ...[
            if (editing)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton(
                    onPressed: saving
                        ? null
                        : () {
                            setState(() {
                              editing = false;
                              error = null;
                            });
                            _load();
                          },
                    style: FilledButton.styleFrom(
                      fixedSize: const Size(240, 48),
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            Center(
              child: FilledButton(
                onPressed: saving
                    ? null
                    : editing
                    ? _save
                    : () => setState(() => editing = true),
                style: FilledButton.styleFrom(
                  fixedSize: const Size(240, 48),
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  saving
                      ? 'Saving…'
                      : editing
                      ? 'Save details'
                      : 'Edit details',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _schedule() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const purple = Color(0xFF7C3AED);
    final schedule = <String, List<String>>{};

    for (final value in fields['available_days']!.text.split(',')) {
      final parts = value.trim().split(' ');

      if (days.contains(parts.first)) {
        final times = parts.length > 1 ? parts[1].split('-') : <String>[];
        schedule[parts.first] = times.length == 2 ? times : ['', ''];
      }
    }

    void update() => setState(
      () => fields['available_days']!.text = days
          .where(schedule.containsKey)
          .map((day) => '$day ${schedule[day]![0]}-${schedule[day]![1]}')
          .join(','),
    );

    Future<void> time(String day, int index) async {
      final parts = schedule[day]![index].split(':');

      final picked = await showTimePicker(
        context: context,
        builder: (context, child) {
          final theme = Theme.of(context);
          return Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                primary: purple,
                onPrimary: Colors.white,
                primaryContainer: purple,
                onPrimaryContainer: Colors.white,
              ),
            ),
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(alwaysUse24HourFormat: false),
              child: child!,
            ),
          );
        },
        initialTime: parts.length == 2
            ? TimeOfDay(
                hour: int.tryParse(parts[0]) ?? 9,
                minute: int.tryParse(parts[1]) ?? 0,
              )
            : const TimeOfDay(hour: 9, minute: 0),
      );

      if (picked != null && mounted) {
        schedule[day]![index] =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        update();
      }
    }

    Widget timeButton(String day, int index) {
      final value = schedule[day]![index];
      return Expanded(
        child: OutlinedButton(
          onPressed: saving ? null : () => time(day, index),
          style: OutlinedButton.styleFrom(
            foregroundColor: ClayTokens.clayDarkTextPrimary,
            side: BorderSide(color: purple.withAlpha(100)),
            backgroundColor: purple.withAlpha(18),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Column(
            children: [
              Text(
                index == 0 ? 'Start time' : 'End time',
                style: TextStyle(
                  fontSize: 11,
                  color: ClayTokens.clayDarkTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isEmpty ? 'Set time' : _clockLabel(value),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ClayTokens.clayDarkTextPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose your working days, then set the start and end time for each day.',
          style: TextStyle(
            fontSize: 13,
            color: ClayTokens.clayDarkTextSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final day in days)
              FilterChip(
                label: Text(
                  day,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: schedule.containsKey(day)
                        ? Colors.white
                        : ClayTokens.clayDarkTextPrimary,
                  ),
                ),
                selectedColor: purple,
                checkmarkColor: Colors.white,
                backgroundColor: purple.withAlpha(12),
                selected: schedule.containsKey(day),
                onSelected: saving
                    ? null
                    : (selected) {
                        if (selected) {
                          schedule[day] = ['09:00', '17:00'];
                        } else {
                          schedule.remove(day);
                        }
                        update();
                      },
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (schedule.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No available days selected.',
              style: TextStyle(color: ClayTokens.clayDarkTextSecondary),
            ),
          ),
        for (final day in days.where(schedule.containsKey))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  child: Text(
                    day,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ClayTokens.clayDarkTextPrimary,
                    ),
                  ),
                ),
                timeButton(day, 0),
                const SizedBox(width: 8),
                timeButton(day, 1),
              ],
            ),
          ),
      ],
    );
  }
}

class TrainerProfileTabs extends StatefulWidget {
  final String trainerId;

  const TrainerProfileTabs({super.key, required this.trainerId});

  @override
  State<TrainerProfileTabs> createState() => _TrainerProfileTabsState();
}

class _TrainerProfileTabsState extends State<TrainerProfileTabs> {
  Future<List<Map<String, dynamic>>>
  _ratings() async => List<Map<String, dynamic>>.from(
    await SupabaseClientService().client
        .from('trainer_feedback')
        .select(
          'rating, member:profiles!trainer_feedback_member_id_fkey(full_name)',
        )
        .eq('trainer_id', widget.trainerId)
        .not('rating', 'is', null)
        .order('created_at', ascending: false),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final item in [false, true])
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: PressableCard(
            glass: true,
            borderRadius: BorderRadius.circular(12),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: ListTile(
              minTileHeight: 48,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              leading: Icon(
                item ? Icons.person_outline : Icons.star_outline,
                size: 20,
                color: const Color(0xFF7C3AED),
              ),
              title: Text(
                item ? 'Details' : 'Ratings',
                style: TextStyle(
                  fontSize: 14,
                  color: ClayTokens.clayDarkTextPrimary,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                size: 20,
                color: ClayTokens.clayDarkTextSecondary,
              ),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    appBar: AppBar(title: Text(item ? 'Details' : 'Ratings')),
                    body: AppGlowBackground(
                      child: SingleChildScrollView(
                        child: item
                            ? PersonalDetails(
                                userId: widget.trainerId,
                                editable: true,
                                trainer: true,
                              )
                            : _ratingList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _ratingList() => FutureBuilder<List<Map<String, dynamic>>>(
    future: _ratings(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return const Text('Could not load ratings.');

      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final rows = snapshot.data!;

      final avg = rows.isEmpty
          ? null
          : rows.fold<double>(
                  0,
                  (s, r) => s + (r['rating'] as num).toDouble(),
                ) /
                rows.length;

      return Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: MemberGlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF5B301),
                      size: 56,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      avg == null
                          ? 'No ratings yet'
                          : '${avg.toStringAsFixed(1)} / 5',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: ClayTokens.clayDarkTextPrimary,
                      ),
                    ),
                    Text(
                      '${rows.length} ratings',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ClayTokens.clayDarkTextSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            MemberGlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Member ratings',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: ClayTokens.clayDarkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Most recent first',
                    style: TextStyle(
                      fontSize: 12,
                      color: ClayTokens.clayDarkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Your member ratings will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ClayTokens.clayDarkTextSecondary,
                        ),
                      ),
                    ),
                  for (var index = 0; index < rows.length; index++) ...[
                    if (index > 0)
                      Divider(
                        color: ClayTokens.clayDarkTextSecondary.withAlpha(35),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              (rows[index]['member'] as Map?)?['full_name']
                                      ?.toString() ??
                                  'Member',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: ClayTokens.clayDarkTextPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF5B301),
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${rows[index]['rating']} / 5',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: ClayTokens.clayDarkTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class ProfileDetailsPage extends StatelessWidget {
  final String userId;
  const ProfileDetailsPage({super.key, required this.userId});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(title: const Text('Personal details')),
    body: AppGlowBackground(
      child: SingleChildScrollView(
        child: PersonalDetails(userId: userId, editable: true),
      ),
    ),
  );
}
