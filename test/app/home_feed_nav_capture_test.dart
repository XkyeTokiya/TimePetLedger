import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_shell.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';

import '../support/home_feed.dart';

const captureKey = ValueKey('nav-capture');

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
int at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute).millisecondsSinceEpoch;

/// 本轮改版的渲染证据：首页连续时间轴 + 独立摘要 / 复盘页。
/// 仅当 R1_CAPTURE_DIR 存在时输出 PNG，不写任何正式数据。
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

  Future<void> capture(WidgetTester tester, String name) async {
    final dir = Platform.environment['R1_CAPTURE_DIR'];
    if (dir == null) return;
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(captureKey))
          .toImage(pixelRatio: 2);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await Directory(dir).create(recursive: true);
      await File('$dir/$name.png').writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> openApp(WidgetTester tester, DateTime clock) async {
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
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.runAsync(() async {
      final repo = DriftLedgerRepository(db);
      await repo.createSleepSession(
        id: id(1),
        startedAt: DateTime(2026, 10, 1, 23, 40).millisecondsSinceEpoch,
        endedAt: at(2, 7, 20),
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.exact,
        type: SleepType.mainSleep,
        now: 1,
      );
      for (final (n, day, start, end, title) in [
        (2, 1, 8 * 60, 8 * 60 + 40, '早餐、出门'),
        (3, 1, 9 * 60, 9 * 60 + 70, '整理毕业设计思路'),
        (4, 1, 11 * 60, 11 * 60 + 30, '散步'),
        (5, 2, 7 * 60 + 40, 8 * 60 + 20, '早餐、收拾房间'),
        (6, 2, 9 * 60, 9 * 60 + 70, '整理毕业设计资料'),
      ]) {
        await repo.createTimeBlock(
          id: id(n),
          startedAt: at(day, start ~/ 60, start % 60),
          endedAt: at(day, end ~/ 60, end % 60),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: title,
          now: 1,
        );
      }
      await repo.createTimeBlock(
        id: id(7),
        startedAt: at(2, 10, 10),
        endedAt: at(2, 10, 46),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.unknown,
        title: '只记得出门办事',
        now: 1,
      );
      await DriftReviewRepository(db).create(
        id: id(20),
        date: CivilDate(year: 2026, month: 10, day: 2),
        summary: '把毕业设计的资料理了一遍。',
        reflection: '上午效率不错，下午有点散。\n明天先定一个小时内能完成的小任务。',
        tomorrowFirstStepText: '打开文档，先写五分钟。',
        now: 2,
      );
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: AppBootstrap(
          openDatabase: () async => db,
          openDrafts: () async => recording,
          openSleepDrafts: () async => sleepDrafts,
          openSleepOpenings: () async => openings,
          openReviewDrafts: () async => drafts,
          now: () => clock,
        ),
      ),
    );
    await settleNative(tester);
  }

  Future<void> resize(WidgetTester tester, Size size, double scale) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
  }

  testWidgets('capture home feed at 360 and 320 with large text', (
    tester,
  ) async {
    await openApp(tester, DateTime(2026, 10, 2, 15));
    await resize(tester, const Size(360, 800), 1);
    await capture(tester, 'home-360');
    await resize(tester, const Size(320, 800), 1);
    await capture(tester, 'home-320');
    await resize(tester, const Size(320, 800), 1.5);
    await capture(tester, 'home-320-large-text');
    // 验证实际排版：短标题和数字单位分别占完整一行，不能挤成逐字换行。
    for (final text in ['主睡眠', '7 小时', '40 分钟']) {
      final paragraphs = find.text(text);
      expect(paragraphs, findsWidgets);
      for (var i = 0; i < paragraphs.evaluate().length; i++) {
        final paragraph = tester.renderObject<RenderParagraph>(
          paragraphs.at(i),
        );
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        );
        expect(boxes.map((box) => box.top).toSet(), hasLength(1), reason: text);
      }
    }
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('完整时长 7 小时 40 分钟')), findsWidgets);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture reading a previous day and back-to-today', (
    tester,
  ) async {
    await openApp(tester, DateTime(2026, 10, 2, 15));
    await resize(tester, const Size(360, 800), 1);
    await tester.tap(find.byKey(const ValueKey('home-previous-day')));
    await settleNative(tester);
    await capture(tester, 'home-previous-day-360');
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture every frame of directional home date motion', (
    tester,
  ) async {
    await openApp(tester, DateTime(2026, 10, 2, 15));
    await resize(tester, const Size(360, 800), 1);
    final shell = tester.state<HomeShellState>(find.byType(HomeShell));
    await capture(tester, 'motion-00');
    await shell.openDate(CivilDate(year: 2026, month: 10, day: 1));
    for (var i = 1; i <= 18; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await capture(tester, 'motion-${i.toString().padLeft(2, '0')}');
      expect(shell.feed.focusDate, CivilDate(year: 2026, month: 10, day: 1));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(homeDateTitle(tester), '10月1日');
    await shell.openDate(CivilDate(year: 2026, month: 10, day: 2));
    for (var i = 19; i <= 36; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await capture(tester, 'motion-${i.toString().padLeft(2, '0')}');
      expect(shell.feed.focusDate, CivilDate(year: 2026, month: 10, day: 2));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(homeDateTitle(tester), '10月2日');
  });

  testWidgets('capture standalone summary and review pages', (tester) async {
    await openApp(tester, DateTime(2026, 10, 2, 15));
    await resize(tester, const Size(360, 800), 1);

    await tester.tap(find.byKey(const ValueKey('home-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-summary')));
    await settleNative(tester);
    await capture(tester, 'summary-360');
    await tester.pageBack();
    await settleNative(tester);

    await tester.tap(find.byKey(const ValueKey('home-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-review')));
    await settleNative(tester);
    await capture(tester, 'review-360');

    await tester.tap(find.byKey(const ValueKey('review-open-form')));
    await settleNative(tester);
    await capture(tester, 'review-form-360');
    expect(tester.takeException(), isNull);
  });
}
