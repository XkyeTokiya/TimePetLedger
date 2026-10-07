import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/app/bootstrap/day_ledger.dart';
import 'package:time_pet_ledger/app/theme/time_ledger_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_coverage.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_date_selection.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_controller.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_shell.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_summary_tab.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_timeline_tab.dart';

import '../features/ledger/presentation/day_ledger_overview_layout_test.dart'
    show mixedFacts;

const captureKey = ValueKey('r1-home-capture');
final sampleDate = CivilDate(year: 2026, month: 10, day: 2);

/// R1 evidence: the rebuilt home shell rendered with the bundled serif and the
/// real projection, so screenshots can be compared against home-reference.png.
void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('NotoSerifSC')
          ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-Regular.otf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-SemiBold.otf')))
        .load();
  });

  Future<void> capture(WidgetTester t, String name) async {
    final dir = Platform.environment['R1_CAPTURE_DIR'];
    if (dir == null) return;
    await t.runAsync(() async {
      final image = await t
          .renderObject<RenderRepaintBoundary>(find.byKey(captureKey))
          .toImage(pixelRatio: 2);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await Directory(dir).create(recursive: true);
      await File('$dir/$name.png').writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget timeline(DayLedgerController controller, bool active) =>
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) => HomeTimelineTab(
          view: controller.view,
          active: active,
          placeholder: const Center(child: CircularProgressIndicator()),
        ),
      );

  Future<void> mount(
    WidgetTester t,
    Size size,
    DayLedgerLoader loader, {
    Widget Function(DayLedgerController)? floatingCard,
    VoidCallback? onGoals,
    VoidCallback? onSettings,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = size;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final selection = DayDateSelection()..select(sampleDate);
    addTearDown(selection.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: timeLedgerTheme,
        builder: (context, child) =>
            RepaintBoundary(key: captureKey, child: child!),
        home: HomeShell(
          selection: selection,
          ledgerLoader: loader,
          now: () => DateTime(2026, 10, 3, 9).millisecondsSinceEpoch,
          dateOfInstant: deviceDateOfInstant,
          busy: false,
          onGoals: onGoals ?? () {},
          onSettings: onSettings ?? () {},
          onRecordActivity: () {},
          onRecordSleep: () {},
          review: (_) =>
              const Scaffold(body: Center(child: Text('复盘（沿用现有页面）'))),
          timeline: timeline,
          summary: (DayLedgerController controller, bool _) =>
              HomeSummaryTab(controller: controller),
          floatingCard: floatingCard,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('home shell reference capture at 360 and 320', (t) async {
    final loader = DayLedgerLoader(
      resolveDate: resolveDeviceRecordingDate,
      readFacts: (_) async => mixedFacts(),
    );
    for (final width in [360.0, 320.0]) {
      await mount(t, Size(width, 800), loader);
      expect(t.takeException(), isNull);
      await capture(t, 'home-r1-$width');
      await t.tap(find.byKey(const ValueKey('home-tab-summary')));
      await t.pumpAndSettle();
      await capture(t, 'home-r1-summary-$width');
      final gap = find.byKey(const ValueKey('summary-part-gap'));
      await t.ensureVisible(gap);
      await t.pumpAndSettle();
      await t.tap(gap);
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('summary-part-percent-gap')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      await capture(t, 'home-r1-summary-selected-$width');
      // 每个视口用独立页面，避免上一轮选择被下一次点击取消。
      await t.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('real DB round-trip: a saved record reaches the timeline', (
    t,
  ) async {
    final db = (await t.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final repo = DriftLedgerRepository(db);
    await t.runAsync(
      () => repo.createTimeBlock(
        id: '00000000-0000-4000-8000-0000000000a1',
        startedAt: DateTime(2026, 10, 2, 8).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 10, 2, 9).millisecondsSinceEpoch,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '真实记录一',
        now: 1,
      ),
    );
    await mount(t, const Size(360, 800), createDayLedgerLoader(db));
    expect(find.text('真实记录一'), findsOneWidget);

    await t.runAsync(
      () => repo.createTimeBlock(
        id: '00000000-0000-4000-8000-0000000000a2',
        startedAt: DateTime(2026, 10, 2, 10).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 10, 2, 11).millisecondsSinceEpoch,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '真实记录二',
        now: 2,
      ),
    );
    t.state<HomeShellState>(find.byType(HomeShell)).controller.refresh();
    await t.pumpAndSettle();
    expect(find.text('真实记录二'), findsOneWidget);
    expect(find.text('真实记录一'), findsOneWidget);

    await t.runAsync(
      () => repo.deleteTimeBlock('00000000-0000-4000-8000-0000000000a1'),
    );
    t.state<HomeShellState>(find.byType(HomeShell)).controller.refresh();
    await t.pumpAndSettle();
    expect(find.text('真实记录一'), findsNothing);
    expect(find.text('真实记录二'), findsOneWidget);

    await t.pumpWidget(const SizedBox.shrink());
    await t.runAsync(() => db.close());
  });

  testWidgets('the review card floats above the action bar, not in the list', (
    t,
  ) async {
    final loader = DayLedgerLoader(
      resolveDate: resolveDeviceRecordingDate,
      readFacts: (_) async => mixedFacts(),
    );
    await mount(
      t,
      const Size(390, 800),
      loader,
      floatingCard: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Material(child: SizedBox(height: 60, child: Text('复盘已保存'))),
      ),
    );

    final card = find.text('复盘已保存');
    expect(card, findsOneWidget);
    final barTop = t
        .getTopLeft(find.byKey(const ValueKey('home-record-activity')))
        .dy;
    // Above the 记录一笔 bar, and inside the tab body rather than the scroll
    // content (the timeline never contains it).
    expect(t.getBottomLeft(card).dy, lessThanOrEqualTo(barTop));
    expect(
      find.descendant(of: find.byType(HomeTimelineTab), matching: card),
      findsNothing,
    );
  });

  testWidgets(
    'top bar opens the sidebar; old right and ledger entries stay hidden',
    (t) async {
      final loader = DayLedgerLoader(
        resolveDate: resolveDeviceRecordingDate,
        readFacts: (_) async => mixedFacts(),
      );
      var goals = 0;
      var settings = 0;
      await mount(
        t,
        const Size(390, 800),
        loader,
        onGoals: () => goals++,
        onSettings: () => settings++,
      );

      // 右上角入口与时间分布说明 / 刷新账本入口均已隐藏（2026-10-07 用户要求）。
      expect(find.byKey(const ValueKey('home-date')), findsNothing);
      expect(find.byKey(const ValueKey('home-distribution')), findsNothing);
      expect(find.byKey(const ValueKey('home-refresh')), findsNothing);

      // 左上角打开 MD3 侧边栏，沿用「我的目标 / 设置」两个入口。
      await t.tap(find.byKey(const ValueKey('home-menu')));
      await t.pumpAndSettle();
      expect(find.byType(NavigationDrawer), findsOneWidget);
      expect(find.text('我的目标'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('menu-goals')));
      await t.pumpAndSettle();
      expect(goals, 1);
      expect(settings, 0);

      await t.tap(find.byKey(const ValueKey('home-menu')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('menu-settings')));
      await t.pumpAndSettle();
      expect(settings, 1);
    },
  );

  testWidgets('unknown reads as a state and a gap stays one row tall', (
    t,
  ) async {
    final loader = DayLedgerLoader(
      resolveDate: resolveDeviceRecordingDate,
      readFacts: (_) async => mixedFacts(),
    );
    final view = await loader.load(
      date: sampleDate,
      now: DateTime(2026, 10, 3, 9).millisecondsSinceEpoch,
    );
    UnresolvedSpan? filled;
    await t.pumpWidget(
      MaterialApp(
        theme: timeLedgerTheme,
        home: Scaffold(
          body: HomeTimelineTab(
            view: view,
            placeholder: const SizedBox.shrink(),
            active: true,
            onFillGap: (_, gap) => filled = gap,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    // "想不起来" is the fact; the half-remembered text is residue that belongs
    // in the detail sheet, never in the row heading.
    expect(find.text('想不起来'), findsOneWidget);
    expect(find.text('已交代'), findsWidgets);
    expect(find.text('只记得出门办事'), findsNothing);

    // A gap's 补记 is an inline affordance, not a button: a 48px tap target is
    // what made gap rows twice as tall as the records around them. The whole
    // row is already the tap target.
    expect(find.widgetWithText(TextButton, '补记'), findsNothing);
    expect(view.unresolvedSpans, isNotEmpty);
    double rowHeight(String label) => t
        .getSize(
          find
              .ancestor(of: find.text(label), matching: find.byType(InkWell))
              .first,
        )
        .height;
    expect(rowHeight('尚未记录') - rowHeight('早餐'), lessThan(24));
    await t.tap(find.text('尚未记录').first);
    expect(filled, isNotNull);
  });

  testWidgets('an unknown fact stays fully editable from the timeline', (
    t,
  ) async {
    final db = (await t.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final drafts = (await t.runAsync(
      () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
    ))!;
    final openings = (await t.runAsync(
      () => DriftSleepOpeningStore.open(NativeDatabase.memory()),
    ))!;
    await t.runAsync(
      () => DriftLedgerRepository(db).createTimeBlock(
        id: '00000000-0000-4000-8000-0000000000f1',
        startedAt: DateTime(2026, 10, 1, 10).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 10, 1, 10, 30).millisecondsSinceEpoch,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.unknown,
        title: '只记得出门办事',
        now: 1,
      ),
    );
    await t.pumpWidget(
      AppBootstrap(
        openDatabase: () async => db,
        openDrafts: () async => drafts,
        openSleepOpenings: () async => openings,
        now: () => DateTime(2026, 10, 1, 12),
      ),
    );
    await t.pumpAndSettle();

    // The row states the fact; the residue text is not a heading.
    expect(find.text('想不起来'), findsOneWidget);
    expect(find.text('只记得出门办事'), findsNothing);
    await t.tap(find.text('想不起来'));
    await t.pumpAndSettle();
    // Unknown is a legal fact, not a dead end: it opens the same edit path.
    expect(find.text('编辑完整记录'), findsOneWidget);
    expect(find.text('原文字'), findsOneWidget);
    expect(find.text('只记得出门办事'), findsOneWidget);
    await t.tap(find.text('编辑完整记录'));
    await t.pumpAndSettle();
    expect(find.text('更正记录'), findsOneWidget);

    // The recorder is stepped now: 节奏 → 事项 → 时间.
    await t.tap(find.byKey(const ValueKey('activity-primary')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('activity-known')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('activity')), '设计首页');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('activity-primary')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('activity-primary')));
    await t.pumpAndSettle();

    final saved = (await t.runAsync(
      () =>
          DriftLedgerRepository(db)
              .readTimeBlock('00000000-0000-4000-8000-0000000000f1'),
    ))!;
    expect(saved.timeBlock.knowledgeState, BlockKnowledgeState.known);
    expect(saved.timeBlock.title, '设计首页');
    expect(find.text('设计首页'), findsOneWidget);
    expect(find.text('想不起来'), findsNothing);

    await t.pumpWidget(const SizedBox.shrink());
    await t.runAsync(() => db.close());
  });

  testWidgets('home shell survives large text and long content', (t) async {
    final loader = DayLedgerLoader(
      resolveDate: resolveDeviceRecordingDate,
      readFacts: (_) async => mixedFacts(),
    );
    for (final scale in [1.5, 2.0]) {
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(t, const Size(320, 800), loader);
      expect(t.takeException(), isNull);
      await capture(t, 'home-r1-scale-$scale');
    }
  });
}
