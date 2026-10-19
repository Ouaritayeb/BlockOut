import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/installed_app.dart';
import 'services/app_blocker_service.dart';

void main() {
  runApp(const BlockOutApp());
}

class BlockOutApp extends StatelessWidget {
  const BlockOutApp({super.key});

  @override
  Widget build(BuildContext context) {
    const forest = Color(0xFF12221C);
    const canvas = Color(0xFFF4F5EF);

    return MaterialApp(
      title: 'BlockOut',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D674C),
          brightness: Brightness.light,
          surface: canvas,
        ),
        fontFamily: 'Roboto',
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: forest,
          selectionColor: Color(0x443C8B64),
        ),
      ),
      home: const BlockOutHomePage(),
    );
  }
}

class BlockOutHomePage extends StatefulWidget {
  const BlockOutHomePage({super.key});

  @override
  State<BlockOutHomePage> createState() => _BlockOutHomePageState();
}

class _BlockOutHomePageState extends State<BlockOutHomePage>
    with WidgetsBindingObserver {
  static const _ink = Color(0xFF12221C);
  static const _muted = Color(0xFF738078);
  static const _green = Color(0xFF2D674C);
  static const _lime = Color(0xFFD6F58E);
  static const _line = Color(0xFFE4E8DF);
  static const _durations = <int>[15, 25, 45, 60];

  final TextEditingController _searchController = TextEditingController();

  List<InstalledApp> _apps = const [];
  Set<String> _selectedPackages = <String>{};
  bool _hasAccessibility = false;
  bool _loading = true;
  bool _busy = false;
  bool _awaitingAccessibility = false;
  bool _endingExpiredSession = false;
  String? _loadError;
  int _durationMinutes = 25;
  DateTime? _endsAt;
  Timer? _ticker;

  bool get _sessionActive => _endsAt != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait<Object>([
        AppBlockerService.getInstalledApps(),
        AppBlockerService.getSavedSelection(),
        AppBlockerService.isAccessibilityEnabled(),
        AppBlockerService.getSession(),
      ]);
      final apps = results[0] as List<InstalledApp>;
      final saved = results[1] as Set<String>;
      final permission = results[2] as bool;
      final session = results[3] as FocusSession;
      if (!mounted) return;

      final installedPackages = apps.map((app) => app.packageName).toSet();
      setState(() {
        _apps = apps;
        _selectedPackages = (session.active ? session.packageNames : saved)
            .intersection(installedPackages);
        _hasAccessibility = permission;
        _endsAt = session.active ? session.endsAt : null;
        _loading = false;
      });
      if (_sessionActive && _selectedPackages.isEmpty) {
        await _finishExpiredSession();
      }
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError =
            'BlockOut’s Android app services are not available on this device.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Couldn’t load your apps. Please try again.';
      });
    }
  }

  Future<void> _onResume() async {
    try {
      final enabled = await AppBlockerService.isAccessibilityEnabled();
      if (!mounted) return;
      setState(() => _hasAccessibility = enabled);
      if (_awaitingAccessibility && enabled) {
        _awaitingAccessibility = false;
        await _startSession();
      } else {
        await _restoreSession();
      }
    } catch (_) {
      // Keep the current screen state; a later resume can refresh the status.
    }
  }

  Future<void> _restoreSession() async {
    try {
      final session = await AppBlockerService.getSession();
      if (!mounted) return;
      setState(() {
        _endsAt = session.active ? session.endsAt : null;
        if (session.active) _selectedPackages = session.packageNames;
      });
    } catch (_) {
      // The existing countdown remains visible if the platform is temporarily
      // unavailable while the app returns from the background.
    }
  }

  Future<void> _tick() async {
    final end = _endsAt;
    if (end == null || !mounted) return;
    if (!end.isAfter(DateTime.now())) {
      await _finishExpiredSession();
      return;
    }
    setState(() {});
  }

  Future<void> _finishExpiredSession() async {
    if (_endingExpiredSession) return;
    _endingExpiredSession = true;
    try {
      await AppBlockerService.stopSession();
    } catch (_) {
      // The native service also stops enforcing an expired deadline.
    }
    if (mounted) {
      setState(() {
        _endsAt = null;
        _endingExpiredSession = false;
      });
      _showMessage('Focus session complete. Nice work.');
    } else {
      _endingExpiredSession = false;
    }
  }

  Future<void> _enableAccessibility({bool startWhenEnabled = false}) async {
    try {
      _awaitingAccessibility = startWhenEnabled;
      await AppBlockerService.openAccessibilitySettings();
    } catch (_) {
      _awaitingAccessibility = false;
      _showMessage('Couldn’t open Accessibility settings.');
    }
  }

  Future<void> _toggleApp(InstalledApp app) async {
    if (_sessionActive || _busy) return;
    final updated = Set<String>.of(_selectedPackages);
    if (!updated.add(app.packageName)) updated.remove(app.packageName);
    setState(() => _selectedPackages = updated);
    try {
      await AppBlockerService.saveSelection(updated);
    } catch (_) {
      _showMessage('Couldn’t save your app selection.');
    }
  }

  Future<void> _startSession() async {
    if (_busy || _sessionActive) return;
    if (_selectedPackages.isEmpty) {
      _showMessage('Choose at least one app to block.');
      return;
    }
    if (!_hasAccessibility) {
      await _enableAccessibility(startWhenEnabled: true);
      return;
    }

    setState(() => _busy = true);
    final end = DateTime.now().add(Duration(minutes: _durationMinutes));
    try {
      await AppBlockerService.startSession(
        packageNames: _selectedPackages,
        endsAt: end,
      );
      if (!mounted) return;
      setState(() {
        _endsAt = end;
        _busy = false;
      });
      _showMessage('Focus session started.');
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (error.code == 'ACCESSIBILITY_REQUIRED') {
        setState(() => _hasAccessibility = false);
        await _enableAccessibility(startWhenEnabled: true);
      } else {
        _showMessage('Couldn’t start the focus session. Try again.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('Couldn’t start the focus session. Try again.');
    }
  }

  Future<void> _stopSession() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AppBlockerService.stopSession();
      if (!mounted) return;
      setState(() {
        _endsAt = null;
        _busy = false;
      });
      _showMessage('Focus session ended.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('Couldn’t end the session. Try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String get _remainingTime {
    final end = _endsAt;
    if (end == null) return '';
    final seconds = end.difference(DateTime.now()).inSeconds.clamp(0, 599999);
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainder = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${remainder.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainder.toString().padLeft(2, '0')}';
  }

  List<InstalledApp> get _visibleApps {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _apps;
    return _apps
        .where(
          (app) =>
              app.name.toLowerCase().contains(query) ||
              app.packageName.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _green))
            : RefreshIndicator(
                color: _green,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 27),
                    _buildIntro(),
                    const SizedBox(height: 22),
                    _sessionActive ? _buildActiveSession() : _buildTimerCard(),
                    const SizedBox(height: 18),
                    _buildPermissionCard(),
                    const SizedBox(height: 26),
                    _buildAppPicker(),
                    if (_loadError != null) ...[
                      const SizedBox(height: 14),
                      _buildErrorCard(),
                    ],
                    const SizedBox(height: 22),
                    _buildPrimaryAction(),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'Your app choices stay on this device.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.block_rounded, color: _lime, size: 22),
        ),
        const SizedBox(width: 11),
        const Text(
          'BLOCKOUT',
          style: TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        const Spacer(),
        if (_sessionActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F1D4),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: _green, size: 7),
                SizedBox(width: 6),
                Text(
                  'FOCUS ON',
                  style: TextStyle(
                    color: _green,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _sessionActive ? 'You’re in focus.' : 'Make room for\nwhat matters.',
          style: const TextStyle(
            color: _ink,
            height: 1.04,
            fontSize: 35,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _sessionActive
              ? 'Your selected apps are paused. Stay with what you started.'
              : 'Choose the apps that pull you away. We’ll hold them until time’s up.',
          style: const TextStyle(color: _muted, height: 1.45, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildTimerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer_outlined, color: _lime, size: 18),
              SizedBox(width: 8),
              Text(
                'FOCUS DURATION',
                style: TextStyle(
                  color: Color(0xFFC5D2C8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_durationMinutes',
                style: const TextStyle(
                  color: Colors.white,
                  height: 0.95,
                  fontSize: 53,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2.5,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 7, bottom: 5),
                child: Text(
                  'minutes',
                  style: TextStyle(
                    color: Color(0xFFC5D2C8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _durations
                .map(
                  (minutes) => _DurationChip(
                    minutes: minutes,
                    selected: minutes == _durationMinutes,
                    onTap: _sessionActive
                        ? null
                        : () => setState(() => _durationMinutes = minutes),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSession() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_clock_rounded, color: _lime, size: 18),
              SizedBox(width: 8),
              Text(
                'TIME LEFT',
                style: TextStyle(
                  color: Color(0xFFC5D2C8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            _remainingTime,
            style: const TextStyle(
              color: Colors.white,
              height: 1,
              fontSize: 52,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            '${_selectedPackages.length} '
            '${_selectedPackages.length == 1 ? 'app is' : 'apps are'} '
            'blocked until your timer ends.',
            style: const TextStyle(
              color: Color(0xFFC5D2C8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard() {
    final enabled = _hasAccessibility;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFE8F1E5) : const Color(0xFFFFF1D9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled ? const Color(0xFFD5E4D2) : const Color(0xFFF3E2BF),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            enabled ? Icons.verified_user_outlined : Icons.shield_outlined,
            color: enabled ? _green : const Color(0xFF926621),
            size: 20,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'App blocking is ready' : 'One-time setup',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  enabled
                      ? 'Accessibility access is on for this device.'
                      : 'Allow BlockOut in Accessibility settings to block selected apps.',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (!enabled)
            TextButton(
              onPressed: _enableAccessibility,
              style: TextButton.styleFrom(
                foregroundColor: _ink,
                padding: const EdgeInsets.symmetric(horizontal: 5),
              ),
              child: const Text(
                'Enable',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppPicker() {
    final visibleApps = _visibleApps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text(
                'Apps to block',
                style: TextStyle(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Text(
              '${_selectedPackages.length} selected',
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          'Pick the apps you want to leave for later.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _searchController,
          enabled: !_sessionActive,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search your apps',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: _line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: _green, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_apps.isEmpty)
          _buildEmptyApps()
        else if (visibleApps.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No apps match your search.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _line),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleApps.length,
              separatorBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(left: 61),
                child: Divider(height: 1, color: _line),
              ),
              itemBuilder: (context, index) {
                final app = visibleApps[index];
                final selected = _selectedPackages.contains(app.packageName);
                return _AppRow(
                  app: app,
                  selected: selected,
                  enabled: !_sessionActive,
                  onTap: () => _toggleApp(app),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyApps() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: const Column(
        children: [
          Icon(Icons.apps_rounded, color: _green, size: 24),
          SizedBox(height: 8),
          Text(
            'No launchable apps found',
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Install an app or refresh this screen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE8E6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFAD332B), size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _loadError!,
              style: const TextStyle(
                color: Color(0xFF7B2A24),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildPrimaryAction() {
    final isDisabled = _busy || (!_sessionActive && _selectedPackages.isEmpty);
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: isDisabled
            ? null
            : _sessionActive
            ? _stopSession
            : _startSession,
        style: FilledButton.styleFrom(
          backgroundColor: _green,
          disabledBackgroundColor: const Color(0xFFCBD5CD),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: _busy
            ? const SizedBox(
                height: 21,
                width: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _sessionActive
                        ? Icons.stop_circle_outlined
                        : Icons.lock_outline_rounded,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _sessionActive
                        ? 'End focus session'
                        : _hasAccessibility
                        ? 'Start $_durationMinutes-minute focus'
                        : 'Enable app blocking',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFD6F58E) : const Color(0xFF293A32),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            '$minutes min',
            style: TextStyle(
              color: selected ? const Color(0xFF12221C) : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final InstalledApp app;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFE5F1D4)
                      : const Color(0xFFF1F3ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  app.monogram,
                  style: const TextStyle(
                    color: Color(0xFF2D674C),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF12221C),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.packageName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF738078),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 23,
                height: 23,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF2D674C) : Colors.white,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF2D674C)
                        : const Color(0xFFD3DAD3),
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
