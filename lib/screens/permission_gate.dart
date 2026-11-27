import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// First screen: asks for the audio permission, then shows the library.
class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> with WidgetsBindingObserver {
  final PermissionService _permissions = PermissionService();

  bool _granted = false;
  bool _checking = true;
  bool _busy = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may come back from the system Settings screen.
    if (state == AppLifecycleState.resumed && !_granted && !_busy && !_dialogOpen) {
      _recheck();
    }
  }

  Future<void> _bootstrap() async {
    final MediaPermissionState status = await _permissions.status();
    if (!mounted) return;
    if (status == MediaPermissionState.granted) {
      _onGranted();
    } else {
      await _requestFlow();
    }
  }

  Future<void> _recheck() async {
    final MediaPermissionState status = await _permissions.status();
    if (!mounted || _granted) return;
    if (status == MediaPermissionState.granted) {
      _onGranted();
    } else {
      _showDeniedDialog(status == MediaPermissionState.permanentlyDenied);
    }
  }

  Future<void> _requestFlow() async {
    _busy = true;
    final MediaPermissionState result = await _permissions.request();
    _busy = false;
    if (!mounted) return;
    if (result == MediaPermissionState.granted) {
      _onGranted();
    } else {
      setState(() => _checking = false);
      _showDeniedDialog(result == MediaPermissionState.permanentlyDenied);
    }
  }

  void _onGranted() {
    if (_granted) return;
    context.read<LibraryService>().scan();
    setState(() {
      _granted = true;
      _checking = false;
    });
  }

  Future<void> _showDeniedDialog(bool permanentlyDenied) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: AppColors.card,
            title: const Text('Permission needed'),
            content: Text(
              permanentlyDenied
                  ? 'Permission needed to find your music. Please allow "Music and audio" access for VibePlay in App Settings.'
                  : 'Permission needed to find your music',
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(permanentlyDenied ? 'Open Settings' : 'Grant Permission'),
              ),
            ],
          ),
        );
      },
    );
    _dialogOpen = false;
    if (!mounted) return;
    if (permanentlyDenied) {
      await _permissions.openSettings();
    } else {
      await _requestFlow();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_granted) return const HomeScreen();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, size: 64, color: Colors.black),
            ),
            const SizedBox(height: 24),
            const Text(
              'VibePlay',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              _checking ? 'Getting things ready...' : 'Waiting for permission',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            if (_checking) const CircularProgressIndicator(color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
