import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/push/push_service.dart';
import '../design/colors.dart';
import '../state/goals_controller.dart';
import '../widgets/d_bottom_nav.dart';
import 'directory_screen.dart';
import 'events_screen.dart';
import 'mastermind_screen.dart';
import 'planner_screen.dart';
import 'pulse_screen.dart';

/// Каркас пяти корневых вкладок (раздел 9 спецификации).
/// Профиль и карта резидента — не вкладки: профиль открывается
/// с аватара в header, карта — с блока «Доступ в клуб» и из профиля.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Цель нужна уже на первом экране — грузим до первого кадра
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalsController>().load();

      // В браузере мог раньше входить другой человек — подписку
      // на уведомления переводим на вошедшего
      unawaited(context.read<PushService?>()?.syncIfGranted());
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      PulseScreen(onOpenTab: (i) => setState(() => _index = i)),
      const PlannerScreen(),
      const MastermindScreen(),
      const EventsScreen(),
      const DirectoryScreen(),
    ];

    return Scaffold(
      backgroundColor: DColors.of(context).background,
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: DBottomNav(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}
