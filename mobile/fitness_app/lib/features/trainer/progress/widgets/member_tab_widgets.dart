import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../../../shared/widgets/glass_card.dart';

/// Shared building blocks for the three list-style Member Progress tabs
/// (Workouts / Nutrition / Check-ins). Each tab keeps its own date window, so
/// the range bar and pager are parameterised and stateless.

// ---------------------------------------------------------------------------
// Range bar (start/end + preset chips)
// ---------------------------------------------------------------------------

class MemberTabRangeBar extends StatelessWidget {
  final String preset;
  final DateTime start;
  final DateTime end;
  final void Function(String preset) onPreset;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const MemberTabRangeBar({
    super.key,
    required this.preset,
    required this.start,
    required this.end,
    required this.onPreset,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DateField(label: 'Start date', date: start, onTap: onPickStart),
              const SizedBox(width: 8),
              _DateField(label: 'End date', date: end, onTap: onPickEnd),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PresetChip(
                label: 'Today',
                value: 'today',
                selected: preset == 'today',
                onTap: onPreset,
              ),
              _PresetChip(
                label: 'Last 7 days',
                value: 'last7',
                selected: preset == 'last7',
                onTap: onPreset,
              ),
              _PresetChip(
                label: 'This month',
                value: 'month',
                selected: preset == 'month',
                onTap: onPreset,
              ),
              _PresetChip(
                label: 'All time',
                value: 'all',
                selected: preset == 'all',
                onTap: onPreset,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.calendar,
                size: 13,
                color: ClayTokens.clayDarkTextTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      DateFormat('MMM d, y').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ClayTokens.clayDarkTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final void Function(String preset) onTap;

  const _PresetChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? ClayTokens.clayPrimary
              : Colors.white.withAlpha(14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? ClayTokens.clayPrimary
                : Colors.white.withAlpha(30),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : ClayTokens.clayDarkTextSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared error / empty / pager states
// ---------------------------------------------------------------------------

/// Error state used by every Member Progress tab.
class MemberTabError extends StatelessWidget {
  final String message;
  const MemberTabError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: ClayTokens.clayDarkTextTertiary,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              'Could not load this tab',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ClayTokens.clayDarkTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: ClayTokens.clayDarkTextTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Friendly empty state with an icon + message (e.g. "No workouts logged").
class MemberTabEmpty extends StatelessWidget {
  final IconData icon;
  final String message;
  const MemberTabEmpty({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: ClayTokens.clayDarkTextTertiary),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: ClayTokens.clayDarkTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Prev/Next pager with a "Page X of Y" readout, used by every list tab.
class MemberTabPager extends StatelessWidget {
  final int page;
  final int totalPages;
  final void Function(int page) onPage;

  const MemberTabPager({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PagerButton(
          icon: CupertinoIcons.chevron_left,
          enabled: page > 0,
          onTap: () => onPage(page - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Page ${page + 1} of $totalPages',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
        ),
        _PagerButton(
          icon: CupertinoIcons.chevron_right,
          enabled: page < totalPages - 1,
          onTap: () => onPage(page + 1),
        ),
      ],
    );
  }
}

class _PagerButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PagerButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(enabled ? 18 : 8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withAlpha(enabled ? 30 : 12),
          ),
        ),
        child: Icon(
          icon,
          size: 15,
          color: enabled
              ? ClayTokens.clayDarkTextPrimary
              : ClayTokens.clayDarkTextTertiary,
        ),
      ),
    );
  }
}

/// Convenience: pick a closed window for the given preset. `now` is injectable
/// so callers share a single "now" across a build. Returns [start, end] with
/// `end` pinned to the last millisecond of the day.
({DateTime start, DateTime end}) presetWindow(String preset, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  DateTime start;
  switch (preset) {
    case 'today':
      start = today;
      break;
    case 'all':
      start = DateTime(2023, 1, 1);
      break;
    case 'last7':
    default:
      start = today.subtract(const Duration(days: 6));
      break;
  }
  return (start: start, end: end);
}

