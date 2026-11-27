import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<int> _sleepOptions = <int>[0, 15, 30, 60];

  @override
  Widget build(BuildContext context) {
    final PlayerService player = context.watch<PlayerService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          const _SectionHeader('Sleep Timer'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sleepOptions.map((int minutes) {
                final bool selected = player.sleepMinutes == minutes;
                return ChoiceChip(
                  label: Text(minutes == 0 ? 'Off' : '$minutes min'),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.card,
                  labelStyle: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (bool _) {
                    player.setSleepTimer(minutes);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            minutes == 0
                                ? 'Sleep timer off'
                                : 'Music will stop in $minutes minutes',
                          ),
                        ),
                      );
                  },
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _SleepCountdown(endsAt: player.sleepEndsAt),
          ),
          const Divider(height: 24),
          const _SectionHeader('Theme'),
          const ListTile(
            leading: Icon(Icons.dark_mode_rounded),
            title: Text('Dark'),
            subtitle: Text('VibePlay uses the dark theme only'),
            trailing: Icon(Icons.check_circle_rounded, color: AppColors.accent),
          ),
          const Divider(height: 24),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.graphic_eq_rounded, color: AppColors.accent),
            title: Text('VibePlay'),
            subtitle: Text('Standard Offline Music Player  •  Version 1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _SleepCountdown extends StatelessWidget {
  const _SleepCountdown({required this.endsAt});

  final DateTime? endsAt;

  @override
  Widget build(BuildContext context) {
    final DateTime? end = endsAt;
    if (end == null) {
      return const Text(
        'Sleep timer is off',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    return StreamBuilder<int>(
      stream: Stream<int>.periodic(const Duration(seconds: 1), (int i) => i),
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        Duration remaining = end.difference(DateTime.now());
        if (remaining.isNegative) remaining = Duration.zero;
        final String mm = remaining.inMinutes.toString().padLeft(2, '0');
        final String ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');
        return Text(
          'Playback will stop in $mm:$ss',
          style: const TextStyle(color: AppColors.textSecondary),
        );
      },
    );
  }
}
