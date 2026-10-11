import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/review_context.dart';
import 'package:time_pet_ledger/app/bootstrap/review_submission.dart';
import 'package:time_pet_ledger/app/theme/app_theme.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/application/activity_understanding.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/application/review_session_service.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/session_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_flow_page.dart';
import 'package:time_pet_ledger/features/settings/domain/app_preferences.dart';

import '../support/native_flow.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final date = CivilDate(year: 2026, month: 10, day: 11);
int at(int h, int m) => DateTime(2026, 10, 11, h, m).millisecondsSinceEpoch;
int prevAt(int h, int m) => DateTime(2026, 10, 10, h, m).millisecondsSinceEpoch;
final nowMs = DateTime(2026, 10, 11, 22, 10).millisecondsSinceEpoch;

/// 复盘四步流程的视觉采样：手机尺寸 + 深色 M3。
///
/// `REVIEW_CAPTURE=<dir> HOME_FONT=<cjk-ttc> flutter test test/app/review_visual_sample_test.dart`
void main() {
  testWidgets('review flow four steps and detail, dark phone sample', (
    t,
  ) async {
    final fontPath = Platform.environment['HOME_FONT'];
    if (fontPath != null) {
      await t.runAsync(() async {
        await (FontLoader(
              'ReviewCapture',
            )..addFont(File(fontPath).readAsBytes().then(ByteData.sublistView)))
            .load();
      });
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    t.view.devicePixelRatio = 2;
    t.view.physicalSize = const Size(780, 1688);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);

    final db = (await t.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final reviewDrafts = (await t.runAsync(
      () => DriftReviewDraftStore.open(NativeDatabase.memory()),
    ))!;
    // 采样测试：内存库随测试进程回收；不在这里关库，避免收尾等待真实异步。
    addTearDown(() {});

    final repo = DriftLedgerRepository(db);
    final goals = DriftGoalRepository(db);
    final loader = createReviewContextLoader(db);
    final saver = createReviewEntrySaver(
      database: db,
      drafts: reviewDrafts,
      loader: loader,
      clock: () => DateTime(2026, 10, 11, 22, 10),
    );
    var nextId = 100;
    final understanding = ActivityUnderstandingService(
      repository: repo,
      now: () => nowMs,
      newId: () => id(nextId++),
    );
    final session = ReviewSessionService(
      repository: repo,
      saver: saver,
      now: () => nowMs,
      newId: () => id(nextId++),
    );

    await t.runAsync(() async {
      final g1 = await goals.create(id: id(1), name: '毕业设计', now: 1);
      final g2 = await goals.create(id: id(2), name: '英语', now: 1);
      await repo.createSleepSession(
        id: id(5),
        startedAt: prevAt(23, 10),
        endedAt: at(6, 15),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        type: SleepType.mainSleep,
        now: 1,
      );
      Future<void> block(
        String blockId,
        int sh,
        int sm,
        int eh,
        int em, {
        String? title,
        String? goalId,
        AddAnnotation? annotation,
      }) => repo.createTimeBlock(
        id: blockId,
        startedAt: at(sh, sm),
        endedAt: at(eh, em),
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.approximate,
        knowledgeState: BlockKnowledgeState.known,
        title: title,
        goalId: goalId,
        annotation: annotation,
        now: 1,
      );
      await block(id(11), 6, 30, 7, 0, title: '晨跑');
      await block(
        id(12),
        8,
        0,
        9,
        0,
        title: '写数据库',
        goalId: g1.id,
        annotation: AddAnnotation(id: id(21), state: RhythmState.progress),
      );
      await block(
        id(13),
        10,
        0,
        11,
        10,
        title: '查 Drift 文档',
        goalId: g1.id,
        annotation: AddAnnotation(
          id: id(22),
          state: RhythmState.stuck,
          stuckReasonCode: StuckReasonCode.unclearNextStep,
          stuckReasonText: '不确定 migration 到底应该怎么测试',
        ),
      );
      await block(id(14), 12, 0, 12, 40, title: '午饭');
      await block(
        id(15),
        14,
        0,
        15,
        0,
        title: '散步',
        annotation: AddAnnotation(id: id(23), state: RhythmState.recovery),
      );
      await block(
        id(16),
        20,
        10,
        21,
        0,
        title: '调整数据库结构',
        annotation: AddAnnotation(
          id: id(24),
          state: RhythmState.stuck,
          stuckReasonText: '字段关系还没想清楚',
        ),
      );
      await block(id(17), 21, 0, 21, 40, title: '看英文视频', goalId: g2.id);
    });

    var theme = buildAppTheme(
      scheme: ThemeScheme.defaultM3,
      brightness: Brightness.dark,
    );
    if (fontPath != null) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'ReviewCapture'),
      );
    }

    const captureKey = ValueKey('review-capture');
    Future<void> capture(String name) async {
      final directory = Platform.environment['REVIEW_CAPTURE'];
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

    Future<void> tapKey(String value) async {
      FocusManager.instance.primaryFocus?.unfocus();
      t.testTextInput.hide();
      await settleNative(t);
      final target = find.byKey(ValueKey(value));
      await t.ensureVisible(target.first);
      await settleNative(t);
      await t.tap(target.first);
      await settleNative(t);
    }

    await t.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: (context, child) => RepaintBoundary(
          key: captureKey,
          child: ColoredBox(color: theme.colorScheme.surface, child: child!),
        ),
        home: ReviewFlowPage(
          loader: loader,
          session: session,
          understanding: understanding,
          drafts: SessionReviewDraftStore(),
          goals: goals,
          initialDate: date,
        ),
      ),
    );
    await settleNative(t);

    // 第 1 步：整理今天（时间轴 + Gap 三操作）。

    await capture('01-step1');

    await tapKey('review-next');

    // 第 2 步：目标优先 + 无目标记录轴。

    await capture('02-step2-goals');

    // 无目标记录点“推进”→ 目标询问（取消不改变）。
    final progressTarget = find.descendant(
      of: find.byKey(ValueKey('review-rhythm-${id(16)}')),
      matching: find.text('推进'),
    );
    await t.ensureVisible(progressTarget);
    await settleNative(t);
    await t.tap(progressTarget);
    await settleNative(t);

    await capture('03-progress-goal-picker');

    await t.tap(find.byKey(const ValueKey('progress-goal-cancel')));
    await settleNative(t);

    await tapKey('review-next');

    // 第 3 步：卡住 + 下一步（必填）。

    await capture('04-step3');

    await t.ensureVisible(find.byKey(const ValueKey('review-next-step')));
    await t.enterText(
      find.byKey(const ValueKey('review-next-step')),
      '先写一个最小 migration test',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await settleNative(t);

    await capture('04b-step3-filled');

    await tapKey('review-next');

    // 第 4 步：总结（完成今天的回顾）。

    await capture('05-step4');

    await tapKey('review-finish');

    // 已完成 Detail。

    await capture('06-detail');

    // 让页面里未完成的真实异步读写结束，避免测试收尾关库时挂起。
    for (var i = 0; i < 30; i++) {
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
