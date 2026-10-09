// 操作延迟探针：逐项测量主要用户操作「触发 → 目标出现」与「触发 → 画面静止」
// 所需的帧数（按 60Hz 逐帧推进）和调试构建下测试线程的实际耗时。
//
// 非常规回归套件；手动运行：
//   flutter test -r expanded test/app/operation_latency_probe.dart
//
// 说明：widget 测试跑在调试构建且无真实 GPU，墙钟时间只作相对参照；
// 帧数更接近 60Hz 下的动画时长（帧数 × 16.7ms）。所有耗时断言均不进入
// 常规套件，结论不能被当作真机帧率。
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/presentation/goal_management_page.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/activity/activity_recording_entry.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_summary_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_shell.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep/sleep_recording_page.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_context_page.dart';
import 'package:time_pet_ledger/features/settings/data/drift_app_preferences_store.dart';

import '../support/home_feed.dart';

const _frameMs = 16; // 60Hz 逐帧步进
const _maxVisible = 600;
const _maxSettle = 900;

void main() {
  testWidgets('operation latency probe', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _boot(tester);
    final todayTitle = _title(tester);
    // ignore: avoid_print
    print('PROBE 视口=390×844 今日标题=$todayTitle');

    final cold = await _pass(tester, enabled: true, todayTitle: todayTitle);
    final warm = await _pass(tester, enabled: true, todayTitle: todayTitle);
    for (final m in cold) {
      // ignore: avoid_print
      print(m.line('冷启动轮'));
    }
    for (final m in warm) {
      // ignore: avoid_print
      print(m.line('热态轮'));
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

Future<void> _boot(WidgetTester tester) async {
  final db = (await tester.runAsync(
    () => AppDatabase.open(NativeDatabase.memory()),
  ))!;
  final recording = (await tester.runAsync(
    () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
  ))!;
  final sleepDrafts = (await tester.runAsync(
    () => DriftSleepDraftStore.open(NativeDatabase.memory()),
  ))!;
  final openings = (await tester.runAsync(
    () => DriftSleepOpeningStore.open(NativeDatabase.memory()),
  ))!;
  final drafts = (await tester.runAsync(
    () => DriftReviewDraftStore.open(NativeDatabase.memory()),
  ))!;
  final preferences = (await tester.runAsync(
    () => DriftAppPreferencesStore.open(NativeDatabase.memory()),
  ))!;
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.runAsync(() async {
    await DriftLedgerRepository(db).createTimeBlock(
      id: '00000000-0000-4000-8000-000000000001',
      startedAt: DateTime(2026, 10, 2, 8).millisecondsSinceEpoch,
      endedAt: DateTime(2026, 10, 2, 9).millisecondsSinceEpoch,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '十月的活动',
      now: 1,
    );
  });
  await tester.pumpWidget(
    AppBootstrap(
      openDatabase: () async => db,
      openDrafts: () async => recording,
      openSleepDrafts: () async => sleepDrafts,
      openSleepOpenings: () async => openings,
      openReviewDrafts: () async => drafts,
      openPreferences: () async => preferences,
      now: () => DateTime(2026, 10, 2, 12),
    ),
  );
  await settleNative(tester);
}

String? _title(WidgetTester tester) {
  final finder = find.byKey(const ValueKey('home-date-title'));
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Text>(finder.last).data;
}

Future<List<_M>> _pass(
  WidgetTester tester, {
  required bool enabled,
  required String? todayTitle,
}) async {
  final p = _Probe(tester, enabled: enabled);
  final scrim = find.byKey(const ValueKey('home-quick-panel-scrim'));
  final homeMenu = find.byKey(const ValueKey('home-menu'));
  final surface = find.byKey(const ValueKey('home-reading-surface'));
  // 快捷区打开时整张首页右移（= 快捷区宽度），遮罩中心会超出视口；
  // 点遮罩必须落在右移后仍可见的首页条带上。
  final view = tester.view.physicalSize / tester.view.devicePixelRatio;
  final scrimPoint = Offset(view.width - 30, view.height / 2);

  Future<void> tapKey(String key) => tester.tap(find.byKey(ValueKey(key)));
  Future<void> popRoute() => tester.binding.handlePopRoute();
  Future<void> openPanel() async {
    if (scrim.evaluate().isEmpty) {
      await tester.tap(homeMenu);
      await settleNative(tester);
    }
    if (scrim.evaluate().isEmpty) {
      throw StateError('快捷区未打开，探针无法继续');
    }
  }

  Future<void> ensureKey(String key) async {
    var finder = find.byKey(ValueKey(key));
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await settleNative(tester);
    } else {
      await tester.ensureVisible(finder);
      await tester.pump();
    }
  }

  Future<void> openSheetRow(String key) async {
    await ensureKey(key);
    await tapKey(key);
    await settleNative(tester);
  }

  bool choiceChecked(String key) {
    final icons = find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(Icon),
    );
    return tester
        .widgetList<Icon>(icons)
        .any((icon) => icon.icon == Icons.radio_button_checked);
  }

  // —— 首页与快捷区 ——
  await p.measure(
    '打开快捷区（点菜单）',
    () => tapKey('home-menu'),
    visible: () => scrim.evaluate().isNotEmpty,
  );
  await p.measure(
    '关闭快捷区（点遮罩）',
    () => tester.tapAt(scrimPoint),
    visible: () => scrim.evaluate().isEmpty,
  );
  await p.measure(
    '时间轴横滑露出快捷区（手势）',
    () => tester.fling(surface, const Offset(290, 0), 1200),
    visible: () => scrim.evaluate().isNotEmpty,
  );
  if (scrim.evaluate().isNotEmpty) {
    await p.measure(
      '关闭快捷区（手势后点遮罩）',
      () => tester.tapAt(scrimPoint),
      visible: () => scrim.evaluate().isEmpty,
    );
  }
  if (scrim.evaluate().isNotEmpty) {
    await tester.tapAt(scrimPoint);
    await settleNative(tester);
  }
  await p.measure(
    '时间轴纵滑半屏（含惯性收束）',
    () => tester.fling(surface, const Offset(0, -420), 1500),
  );

  // —— 快捷区导航入口 ——
  await openPanel();
  await p.measure(
    '快捷区→设置（直跳）',
    () => tapKey('menu-settings'),
    visible: () =>
        find.byKey(const ValueKey('settings-back')).evaluate().isNotEmpty,
  );
  await p.measure(
    '设置→返回首页',
    () => tapKey('settings-back'),
    visible: () => homeMenu.evaluate().isNotEmpty,
  );

  await openPanel();
  await p.measure(
    '快捷区→我的目标',
    () => tapKey('menu-goals'),
    visible: () => find.byType(GoalManagementPage).evaluate().isNotEmpty,
  );
  await p.measure(
    '我的目标→返回首页',
    popRoute,
    visible: () => homeMenu.evaluate().isNotEmpty,
  );

  await openPanel();
  await p.measure(
    '快捷区→当日概览',
    () => tapKey('menu-summary'),
    visible: () => find.byType(DaySummaryPage).evaluate().isNotEmpty,
  );
  await p.measure(
    '当日概览→返回首页',
    popRoute,
    visible: () => homeMenu.evaluate().isNotEmpty,
  );

  await openPanel();
  await p.measure(
    '快捷区→当日复盘',
    () => tapKey('menu-review'),
    visible: () => find.byType(ReviewContextPage).evaluate().isNotEmpty,
  );
  await p.measure(
    '当日复盘→返回首页',
    popRoute,
    visible: () => homeMenu.evaluate().isNotEmpty,
  );

  // 先离开今天，「返回今天」才有内容。
  final dynamic shell = tester.state(find.byType(HomeShell));
  await shell.openDate(CivilDate(year: 2026, month: 10, day: 1));
  await settleNative(tester);
  await openPanel();
  await p.measure(
    '快捷区→返回今天',
    () => tapKey('menu-today'),
    visible: () => _title(tester) == todayTitle,
  );

  // —— 记录入口 ——
  await p.measure(
    '记录睡眠（打开）',
    () => tapKey('home-record-sleep'),
    visible: () => find.byType(SleepRecordingPage).evaluate().isNotEmpty,
  );
  await p.measure(
    '记录睡眠→返回首页',
    popRoute,
    visible: () => homeMenu.evaluate().isNotEmpty,
  );
  await p.measure(
    '记录一笔（打开）',
    () => tapKey('home-record-activity'),
    visible: () => find.byType(ActivityRecordingEntry).evaluate().isNotEmpty,
  );
  await p.measure(
    '记录一笔→返回首页',
    popRoute,
    visible: () => homeMenu.evaluate().isNotEmpty,
  );

  // —— 设置内全部页面与选择 ——
  await openPanel();
  await tapKey('menu-settings');
  await settleNative(tester);

  await ensureKey('settings-open-display');
  await p.measure(
    '设置→界面设置',
    () => tapKey('settings-open-display'),
    visible: () =>
        find.byKey(const ValueKey('settings-theme-mode')).evaluate().isNotEmpty,
  );
  await p.measure(
    '主题模式：打开选择面板',
    () => tapKey('settings-theme-mode'),
    visible: () => find
        .byKey(const ValueKey('settings-theme-mode-dark'))
        .evaluate()
        .isNotEmpty,
  );
  await p.measure(
    '主题模式：切到深色',
    () => tapKey('settings-theme-mode-dark'),
    visible: () => find
        .byKey(const ValueKey('settings-theme-mode-dark'))
        .evaluate()
        .isEmpty,
  );
  await openSheetRow('settings-theme-mode');
  await p.measure(
    '主题模式：切回跟随系统',
    () => tapKey('settings-theme-mode-system'),
    visible: () => find
        .byKey(const ValueKey('settings-theme-mode-system'))
        .evaluate()
        .isEmpty,
  );

  await p.measure(
    '自选主题色：打开选择面板',
    () => tapKey('settings-theme-picker'),
    visible: () => find
        .byKey(const ValueKey('settings-theme-warmPaper'))
        .evaluate()
        .isNotEmpty,
  );
  await p.measure(
    '自选主题色：切到暖纸',
    () => tapKey('settings-theme-warmPaper'),
    visible: () => find
        .byKey(const ValueKey('settings-theme-warmPaper'))
        .evaluate()
        .isEmpty,
  );
  await openSheetRow('settings-theme-picker');
  await p.measure(
    '自选主题色：切回默认 M3',
    () => tapKey('settings-theme-defaultM3'),
    visible: () => find
        .byKey(const ValueKey('settings-theme-defaultM3'))
        .evaluate()
        .isEmpty,
  );

  await p.measure(
    '字体：打开选择面板',
    () => tapKey('settings-font'),
    visible: () =>
        find.byKey(const ValueKey('settings-font-serif')).evaluate().isNotEmpty,
  );
  await p.measure(
    '字体：切到衬线',
    () => tapKey('settings-font-serif'),
    visible: () =>
        find.byKey(const ValueKey('settings-font-serif')).evaluate().isEmpty,
  );
  await openSheetRow('settings-font');
  await p.measure(
    '字体：切回系统',
    () => tapKey('settings-font-system'),
    visible: () =>
        find.byKey(const ValueKey('settings-font-system')).evaluate().isEmpty,
  );

  await ensureKey('settings-quick-panel-right');
  await p.measure(
    '界面设置：快捷区切到右侧',
    () => tapKey('settings-quick-panel-right'),
    visible: () => choiceChecked('settings-quick-panel-right'),
  );
  await ensureKey('settings-quick-panel-left');
  await p.measure(
    '界面设置：快捷区切回左侧',
    () => tapKey('settings-quick-panel-left'),
    visible: () => choiceChecked('settings-quick-panel-left'),
  );
  await ensureKey('settings-heat-month');
  await p.measure(
    '界面设置：热力图切到本月',
    () => tapKey('settings-heat-month'),
    visible: () => choiceChecked('settings-heat-month'),
  );
  await ensureKey('settings-heat-week');
  await p.measure(
    '界面设置：热力图切回本周',
    () => tapKey('settings-heat-week'),
    visible: () => choiceChecked('settings-heat-week'),
  );

  await p.measure(
    '界面设置→设置首页',
    () => tapKey('settings-back'),
    visible: () => find
        .byKey(const ValueKey('settings-open-display'))
        .evaluate()
        .isNotEmpty,
  );

  await ensureKey('settings-open-recording');
  await p.measure(
    '设置→记录与提醒',
    () => tapKey('settings-open-recording'),
    visible: () =>
        find.byKey(const ValueKey('settings-mode')).evaluate().isNotEmpty,
  );
  await p.measure(
    '记录与提醒→设置首页',
    () => tapKey('settings-back'),
    visible: () => find
        .byKey(const ValueKey('settings-open-recording'))
        .evaluate()
        .isNotEmpty,
  );

  await ensureKey('settings-open-advanced');
  await p.measure(
    '设置→高级设置',
    () => tapKey('settings-open-advanced'),
    visible: () =>
        find.byKey(const ValueKey('settings-seed')).evaluate().isNotEmpty,
  );
  await p.measure(
    '高级设置→设置首页',
    () => tapKey('settings-back'),
    visible: () => find
        .byKey(const ValueKey('settings-open-advanced'))
        .evaluate()
        .isNotEmpty,
  );

  await ensureKey('settings-open-about');
  await p.measure(
    '设置→关于',
    () => tapKey('settings-open-about'),
    visible: () => find.text('版本').evaluate().isNotEmpty,
  );
  await p.measure(
    '关于→设置首页',
    () => tapKey('settings-back'),
    visible: () =>
        find.byKey(const ValueKey('settings-open-about')).evaluate().isNotEmpty,
  );

  await p.measure(
    '设置→返回首页',
    () => tapKey('settings-back'),
    visible: () => homeMenu.evaluate().isNotEmpty,
  );

  return p.results;
}

class _Probe {
  _Probe(this.tester, {required this.enabled});

  final WidgetTester tester;
  final bool enabled;
  final List<_M> results = [];

  Future<void> measure(
    String name,
    Future<void> Function() action, {
    bool Function()? visible,
  }) async {
    if (!enabled) {
      await action();
      await settleNative(tester);
      return;
    }
    final watch = Stopwatch()..start();
    await action();
    var frames = 0;
    int? visibleAt;
    if (visible != null) {
      while (frames < _maxVisible && !visible()) {
        await tester.pump(const Duration(milliseconds: _frameMs));
        frames += 1;
      }
      visibleAt = frames;
    }
    while (frames < _maxSettle) {
      if (!tester.binding.hasScheduledFrame) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
        if (!tester.binding.hasScheduledFrame) break;
      }
      await tester.pump(const Duration(milliseconds: _frameMs));
      frames += 1;
    }
    watch.stop();
    results.add(
      _M(
        name: name,
        visibleFrames: visibleAt ?? frames,
        settleFrames: frames,
        capped: frames >= _maxSettle || (visibleAt ?? 0) >= _maxVisible,
        wall: watch.elapsed,
      ),
    );
  }
}

class _M {
  _M({
    required this.name,
    required this.visibleFrames,
    required this.settleFrames,
    required this.capped,
    required this.wall,
  });

  final String name;
  final int visibleFrames;
  final int settleFrames;
  final bool capped;
  final Duration wall;

  String line(String pass) =>
      'LATENCY[$pass] $name | 出现 ${visibleFrames}f≈${visibleFrames * _frameMs}ms'
      ' | 静止 ${settleFrames}f≈${settleFrames * _frameMs}ms'
      ' | 墙钟 ${wall.inMilliseconds}ms${capped ? ' | 达到上限' : ''}';
}
