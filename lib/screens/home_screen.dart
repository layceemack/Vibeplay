import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import 'favourites_tab.dart';
import 'playlists_tab.dart';
import 'settings_screen.dart';
import 'songs_tab.dart';

/// Tabs: Songs | Favourites | Playlists, with the mini player docked at the bottom.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<String>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _messageSubscription = context.read<PlayerService>().messages.listen((String message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.graphic_eq_rounded, color: AppColors.accent),
              SizedBox(width: 8),
              Text('VibePlay', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (BuildContext _) => const SettingsScreen()),
                );
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: <Widget>[
              Tab(text: 'Songs'),
              Tab(text: 'Favourites'),
              Tab(text: 'Playlists'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            SongsTab(),
            FavouritesTab(),
            PlaylistsTab(),
          ],
        ),
        bottomNavigationBar: const MiniPlayer(),
      ),
    );
  }
}
