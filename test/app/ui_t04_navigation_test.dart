import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form.dart';

import '../support/ledger_date_selection.dart';
import '../support/root_navigation.dart';
import '../support/rendered_text_contrast.dart';
import 'review_route_flow_test.dart' show RouteApp;
import 'review_form_entry_test.dart' show settleNative;
import '../features/ledger/presentation/day_ledger_page_test.dart'
    show dateLabel, today;

const captureKey = ValueKey('shell-capture');
String id(int i) => '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}';
final day = CivilDate(year: 2026, month: 10, day: 2);

Future<RouteApp> mount(WidgetTester t, {bool longText = false}) async {
  final app = await RouteApp.open(t);
  await t.runAsync(() async {
    final repo = DriftLedgerRepository(app.db);
    for (var i = 0; i < 12; i++) {
      await repo.createTimeBlock(
        id: id(100 + i),
        startedAt: DateTime(2026, 10, 2, i).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 10, 2, i, 40).millisecondsSinceEpoch,
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: longText ? '第$i笔：完整长中文内容🐾\n继续阅读和记录\n不截断原始内容' : '活动$i',
        now: 1,
      );
    }
    await app.reviews.create(
      id: id(500),
      date: day,
      tomorrowFirstStepText: '完整第一步🐾\n打开笔记，继续昨天的阅读。',
      summary: longText ? List.filled(25, '长中文概述🐾\n保持全部内容。').join() : '当天概述',
      reflection: '用户填写的反思',
      now: 1,
    );
  });
  await t.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: AppBootstrap(
        openDatabase: () async => app.db,
        openDrafts: () async => app.recording,
        openReviewDrafts: () async => app.drafts,
        openSleepOpenings: () async => app.openings,
        now: () => app.clock,
      ),
    ),
  );
  await settleNative(t);
  return app;
}

Future<void> capture(WidgetTester t, String name) async {
  final dir = Platform.environment['UI_T04_CAPTURE_DIR'];
  if (dir == null) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}

ScrollableState readingScroll(WidgetTester t) =>
    t.state<ScrollableState>(find.byType(Scrollable).first);

void main() {
  setUpAll(() async {
    final path = Platform.environment['UI_T04_FONT_PATH'];
    if (path != null) {
      final font = FontLoader('Roboto')
        ..addFont(
          Future.value(ByteData.sublistView(await File(path).readAsBytes())),
        );
      await font.load();
      final emoji = FontLoader('Noto Color Emoji')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File('/usr/share/fonts/noto/NotoColorEmoji.ttf')
                  .readAsBytes(),
            ),
          ),
        );
      await emoji.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  testWidgets(
    'shared fixed/follow date, modal cancel, native root back, formal saved date and drafts',
    (t) async {
      final app = await mount(t);
      await selectLedgerDate(t, '2026-10-02');
      await settleNative(t);
      final ledger = t.state(find.byType(DayLedgerPage));
      await t.tap(find.byKey(const ValueKey('root-create')));
      await settleNative(t);
      expect(find.text('记录活动'), findsOneWidget);
      expect(find.text('记录睡眠'), findsOneWidget);
      expect(find.byType(RecordingForm), findsNothing);
      await t.binding.handlePopRoute();
      await settleNative(t);
      expect(find.text('记录活动'), findsNothing);
      expect(t.state(find.byType(DayLedgerPage)), same(ledger));
      await tapRootAction(t, '打开按日复盘');
      await settleNative(t);
      expect(find.text('日期：2026-10-02'), findsOneWidget);
      await t.binding.handlePopRoute();
      await settleNative(t);
      expect(find.byType(DayLedgerPage), findsOneWidget);
      expect(dateLabel('2026-10-02'), findsOneWidget);
      await tapRootAction(t, '打开基础摘要');
      await settleNative(t);
      await t.enterText(
        find.widgetWithText(TextField, '摘要日期 YYYY-MM-DD'),
        '2026-10-01',
      );
      await settleNative(t);
      await backFromPage(t);
      await settleNative(t);
      expect(dateLabel('2026-10-01'), findsOneWidget);
      await tapRootAction(t, '打开按日复盘');
      await settleNative(t);
      await t.ensureVisible(find.text('填写复盘'));
      await t.tap(find.text('填写复盘'));
      await settleNative(t);
      await t.enterText(
        find.byKey(const ValueKey('review-date')),
        '2026-10-03',
      );
      await t.enterText(find.byKey(const ValueKey('review-step')), '尚在草稿🐾');
      await backFromPage(t);
      await settleNative(t);
      expect(find.text('日期：2026-10-01'), findsOneWidget);
      await t.tap(find.text('填写复盘'));
      await settleNative(t);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('review-date')))
            .controller!
            .text,
        '2026-10-03',
      );
      await t.ensureVisible(find.text('保存复盘'));
      await t.tap(find.text('保存复盘'));
      await settleNative(t);
      expect(find.byType(ReviewForm), findsNothing);
      expect(find.text('日期：2026-10-03'), findsOneWidget);
      expect(
        (await t.runAsync(
          () =>
              app.reviews.findByDate(CivilDate(year: 2026, month: 10, day: 3)),
        ))!.tomorrowFirstStep.text,
        '尚在草稿🐾',
      );
      await backFromPage(t);
      await settleNative(t);
      expect(dateLabel('2026-10-03'), findsOneWidget);
      app.clock = DateTime(2026, 10, 4, 0, 1);
      await tapRootAction(t, '查看记录');
      await settleNative(t);
      expect(dateLabel('2026-10-03'), findsOneWidget);
      if (find.text('继续账本').evaluate().isNotEmpty) {
        await t.tap(find.text('继续账本'));
        await settleNative(t);
      }
      await today(t);
      await settleNative(t);
      expect(dateLabel('2026-10-04'), findsOneWidget);
      expect(
        await t.runAsync(
          () => app.recording.read(RecordingDraftContext.newEntry(date: day)),
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'source anchor survives reread, modal, destination, size change and deleted source; seven date limit',
    (t) async {
      final app = await mount(t);
      await t.binding.setSurfaceSize(const Size(360, 800));
      await settleNative(t);
      final tile = recordingFact(id(108));
      await t.ensureVisible(tile);
      await settleNative(t);
      final before = t.getTopLeft(tile).dy;
      await t.tap(find.byKey(const ValueKey('root-回看')));
      await settleNative(t);
      expect(t.getTopLeft(tile).dy, closeTo(before, 1));
      await tapRootAction(t, '记录活动');
      await settleNative(t);
      await backFromPage(t);
      await settleNative(t);
      expect(t.getTopLeft(tile).dy, closeTo(before, 1));
      await tapRootAction(t, '打开按日复盘');
      await settleNative(t);
      await t.ensureVisible(find.text('完整第一步🐾\n打开笔记，继续昨天的阅读。'));
      await settleNative(t);
      final reviewPixels = readingScroll(t).position.pixels;
      await tapRootAction(t, '打开日账本');
      await settleNative(t);
      expect(t.getTopLeft(tile).dy, closeTo(before, 1));
      await tapRootAction(t, '打开按日复盘');
      await settleNative(t);
      expect(readingScroll(t).position.pixels, closeTo(reviewPixels, 1));
      await backFromPage(t);
      await settleNative(t);
      await t.binding.setSurfaceSize(const Size(800, 360));
      await settleNative(t);
      expect(
        t.getRect(tile).overlaps(t.getRect(find.byType(DayLedgerPage))),
        isTrue,
      );
      await t.runAsync(
        () => DriftLedgerRepository(app.db).deleteTimeBlock(id(108)),
      );
      await tapRootAction(t, '记录活动');
      await settleNative(t);
      await backFromPage(t);
      await settleNative(t);
      expect(tile, findsNothing);
      expect(readingScroll(t).position.pixels, greaterThan(0));
      await t.binding.setSurfaceSize(const Size(360, 800));
      await settleNative(t);
      await selectLedgerDate(t, '2026-10-01');
      await settleNative(t);
      expect(readingScroll(t).position.pixels, 0);
      await selectLedgerDate(t, '2026-10-02');
      await settleNative(t);
      // Opening the date picker explicitly scrolls to the compact header;
      // that is now the last reading position of the previous date.
      expect(readingScroll(t).position.pixels, 0);
      for (var date = 4; date <= 10; date++) {
        await selectLedgerDate(t, '2026-10-${date.toString().padLeft(2, '0')}');
        await settleNative(t);
      }
      await selectLedgerDate(t, '2026-10-02');
      await settleNative(t);
      expect(readingScroll(t).position.pixels, 0);
    },
  );

  testWidgets(
    'root mobile matrix, large text, safe bottom and create/more contrast',
    (t) async {
      await mount(t, longText: true);
      final semantics = t.ensureSemantics();

      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      t.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(t.view.resetPadding);

      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          t.platformDispatcher.textScaleFactorTestValue = scale;
          await t.binding.setSurfaceSize(Size(width, 800));
          await settleNative(t);
          await tapRootAction(t, '打开日账本');
          await settleNative(t);
          readingScroll(t).position.jumpTo(0);
          await settleNative(t);
          await capture(t, 'ledger-$width-$scale');
          final sdkContrast = await textContrastGuideline.evaluate(t);
          if (!sdkContrast.passed) {
            debugPrint(
              'SDK root contrast $width / $scale: ${sdkContrast.reason}',
            );
          }
          if (Platform.environment['UI_T04_FONT_PATH'] == null) {
            expect(sdkContrast.passed, isTrue);
          }

          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(
            t,
            meetsGuideline(RenderedTextContrast(captureKey: captureKey)),
          );
          final barTop = t
              .getTopLeft(find.byKey(const ValueKey('root-create')))
              .dy;
          final bodyBottom = t.getBottomLeft(find.byType(DayLedgerPage)).dy;
          expect(bodyBottom, lessThan(barTop));
          expect(
            t.getSize(find.byKey(const ValueKey('root-create'))).height,
            greaterThanOrEqualTo(48),
          );
          await tapRootAction(t, '打开按日复盘');
          await settleNative(t);
          await capture(t, 'review-$width-$scale');
          await t.tap(find.byKey(const ValueKey('root-create')));
          await settleNative(t);
          await capture(t, 'create-$width-$scale');
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(
            t,
            meetsGuideline(RenderedTextContrast(captureKey: captureKey)),
          );
          await backFromPage(t);
          await settleNative(t);
          await t.tap(find.byTooltip('更多'));
          await settleNative(t);
          await capture(t, 'more-$width-$scale');
          await backFromPage(t);
          await settleNative(t);
          expect(t.takeException(), isNull);
        }
      }
      semantics.dispose();
    },
  );
}
