import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/app_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/application/activity_understanding.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/presentation/activity/activity_quick_sheet.dart';
import 'package:time_pet_ledger/features/settings/domain/app_preferences.dart';

import 'review_form_entry_test.dart' show settleNative;

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final date = CivilDate(year: 2026, month: 10, day: 2);
final start = DateTime(2026, 10, 2, 10).millisecondsSinceEpoch;
final end = DateTime(2026, 10, 2, 11, 15).millisecondsSinceEpoch;
final newContext = RecordingDraftContext.newEntry(date: date);

/// 目标 / 节奏选择页的视觉采样：手机尺寸 + 深色 M3（贴近真机主题）。
///
/// 设置 `UNDERSTANDING_CAPTURE` 目录后运行即可输出 PNG：
/// `UNDERSTANDING_CAPTURE=/tmp/opencode/understanding flutter test test/app/understanding_visual_sample_test.dart`
void main() {
  testWidgets('understanding goal and status stages, dark phone sample', (
    t,
  ) async {
    final fontPath = Platform.environment['HOME_FONT'];
    if (fontPath != null) {
      await t.runAsync(() async {
        await (FontLoader(
              'UnderstandingCapture',
            )..addFont(File(fontPath).readAsBytes().then(ByteData.sublistView)))
            .load();
      });
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    t.view.devicePixelRatio = 2;
    t.view.physicalSize = const Size(780, 1688);
    t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetPadding);

    final db = (await t.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final drafts = (await t.runAsync(
      () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
    ))!;
    addTearDown(() async {
      await drafts.close();
      await db.close();
    });
    final repo = DriftLedgerRepository(db);
    final goals = DriftGoalRepository(db);
    final loader = RecordingLedgerLoader(
      repository: repo,
      resolveDate: resolveDeviceRecordingDate,
    );
    var nextId = 100;
    final saver = RecordingEntrySaver(
      repository: repo,
      drafts: drafts,
      refresh: ({required date, required now}) =>
          loader.load(date: date, now: now),
      newId: () => id(nextId++),
      now: () => end + 1,
    );
    final understanding = ActivityUnderstandingService(
      repository: repo,
      now: () => end + 1,
      newId: () => id(nextId++),
    );
    final createdGoals = <Goal>[];
    for (final name in ['毕业设计', '跑步训练', '读书笔记']) {
      createdGoals.add(
        (await t.runAsync(
          () => goals.create(id: id(nextId++), name: name, now: 1),
        ))!,
      );
    }

    const captureKey = ValueKey('understanding-capture');
    Future<void> capture(String name) async {
      final directory = Platform.environment['UNDERSTANDING_CAPTURE'];
      if (directory == null) return;
      await t.runAsync(() async {
        final image = await t
            .renderObject<RenderRepaintBoundary>(find.byKey(captureKey))
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(directory).create(recursive: true);
        await File('$directory/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    var theme = buildAppTheme(
      scheme: ThemeScheme.defaultM3,
      brightness: Brightness.dark,
    );
    if (fontPath != null) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'UnderstandingCapture'),
      );
    }
    await t.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: (context, child) => RepaintBoundary(
          key: captureKey,
          child: ColoredBox(color: theme.colorScheme.surface, child: child!),
        ),
        home: Builder(
          builder: (host) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open'),
                onPressed: () => showActivityQuickSheet(
                  host,
                  entryContext: newContext,
                  store: drafts,
                  entrySaver: saver,
                  understanding: understanding,
                  loadGoals: () => goals.listActive(),
                  loadSuggestion: () async => DirectTimeSuggestion(
                    RecordingTimeInput(startedAt: start, endedAt: end),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await settleNative(t);

    await t.tap(find.byKey(const ValueKey('open')));
    await settleNative(t);
    await t.enterText(find.byKey(const ValueKey('activity')), '写作');
    await t.tap(find.byKey(const ValueKey('activity-primary')));
    await settleNative(t);
    // 目标选择页。
    await capture('goal-stage-dark');

    await t.tap(
      find.byKey(ValueKey('understanding-goal-${createdGoals.first.id}')),
    );
    await settleNative(t);
    // 节奏（状态）选择页。
    await capture('status-stage-dark');

    await t.tap(find.byKey(const ValueKey('understanding-state-stuck')));
    await settleNative(t);
    // 补充页（卡住）。
    await capture('details-stage-dark');

    // 展开补充说明并填写（验证说明卡与输入框样式）。
    await t.tap(find.byKey(const ValueKey('understanding-fold-reason')));
    await settleNative(t);
    await t.enterText(
      find.byKey(const ValueKey('understanding-reason-text')),
      '一直改来改去',
    );
    await settleNative(t);
    await capture('details-note-open-dark');

    // 系统返回：补充 → 状态（已选显示选中态）。
    await t.binding.handlePopRoute();
    await settleNative(t);
    await capture('status-stage-selected-dark');

    // 恢复状态下的补充页（对照）。
    await t.tap(find.byKey(const ValueKey('understanding-state-recovery')));
    await settleNative(t);
    await capture('details-recovery-dark');
    await t.binding.handlePopRoute();
    await settleNative(t);

    // 系统返回：状态 → 目标（已选目标显示选中态）。
    await t.binding.handlePopRoute();
    await settleNative(t);
    await capture('goal-stage-selected-dark');
  });
}
