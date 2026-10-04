import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/time_ledger_theme.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form_controller.dart';

import '../../../support/recording_fields.dart';
import '../../../support/rendered_text_contrast.dart';
import '../../../app/review_form_entry_test.dart' show settleNative;
import 'recording_rhythm_test.dart' as support;
import 'recording_form_controller_test.dart' show FormDraftStore;

import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';

const captureKey = ValueKey('recording-capture');

RecordingFormController model(WidgetTester t) =>
    (t.state(find.byType(RecordingForm, skipOffstage: false)) as dynamic).model
        as RecordingFormController;

Future<void> mount(
  WidgetTester t,
  support.Fixture f, {
  RecordingDraftContext? context,
  RecordingTimeSuggestion? suggestion,
  RecordingDraftStore? store,
}) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pumpAndSettle();
  await t.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: MaterialApp(
        theme: timeLedgerTheme,
        home: Builder(
          builder: (outer) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                outer,
                MaterialPageRoute<void>(
                  builder: (_) => RecordingForm(
                    context: context ?? support.newContext,
                    store: store ?? f.drafts,
                    goals: f.goals,
                    entrySaver: f.saver,
                    entryEditor: f.editor,
                    loadSuggestion: () async =>
                        suggestion ??
                        DirectTimeSuggestion(
                          RecordingTimeInput(
                            startedAt: support.start,
                            endedAt: support.end,
                          ),
                        ),
                  ),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
  await support.textTap(t, '打开');
  await settleNative(t);
}

Future<void> capture(WidgetTester t, String name) async {
  final dir = Platform.environment['UI_T05_CAPTURE_DIR'];
  if (dir == null) return;
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    final picture = await boundary.toImage(pixelRatio: 2);
    final png = await picture.toByteData(format: ui.ImageByteFormat.png);
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(png!.buffer.asUint8List());
    picture.dispose();
  });
}

class FailedFormalInsert extends support.Queries {
  bool armed = false;
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (armed && sql.contains('time_blocks')) throw StateError('formal insert');
    return super.runInsert(executor, sql, args);
  }
}

void main() {
  setUpAll(() async {
    final path = Platform.environment['UI_T05_FONT_PATH'];
    if (path == null) return;
    await (FontLoader('Roboto')..addFont(
          Future.value(ByteData.sublistView(await File(path).readAsBytes())),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('Noto Color Emoji')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('/usr/share/fonts/noto/NotoColorEmoji.ttf')
                  .readAsBytes(),
            ),
          ),
        ))
        .load();
  });

  testWidgets(
    'folds retain raw fields, no formal writes, restore and state switches',
    (t) async {
      final f = await support.openWidget(t);
      final before = await t.runAsync(f.snapshot);
      await mount(t, f);
      final instance = model(t);
      expect(find.text('开始时间'), findsNothing);
      expect(find.text('修改时间'), findsOneWidget);
      expect(find.byKey(const ValueKey('note')), findsNothing);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('activity')))
            .focusNode!
            .hasFocus,
        isFalse,
      );
      await support.textTap(t, '记得做了什么');
      await support.enter(t, 'activity', '  活动🐾\n第二行  ');
      await support.enter(t, 'note', '  备注🐾\n保持原文  ');
      await support.tap(t, find.byKey(const ValueKey('recording-note-toggle')));
      expect(find.byKey(const ValueKey('note')), findsNothing);
      expect(find.text('备注🐾 · 保持原文'), findsOneWidget);
      await support.stateTap(t, RhythmState.progress);
      expect(find.byKey(const ValueKey('continuation-hint')), findsNothing);
      await support.enter(t, 'continuation-hint', '  接续🐾\n第二行  ');
      await support.stateTap(t, RhythmState.stuck);
      expect(find.byKey(const ValueKey('stuck-reason-text')), findsOneWidget);
      await support.enter(t, 'stuck-reason-text', '  原因\n不丢失  ');
      await support.stateTap(t, RhythmState.recovery);
      expect(
        find.byKey(const ValueKey('recovery-method-walk')),
        findsOneWidget,
      );
      await support.tap(t, find.byKey(const ValueKey('recovery-method-walk')));
      await support.tap(
        t,
        find.byKey(const ValueKey('recovery-quality-readyToContinue')),
      );
      await support.stateTap(t, RhythmState.stuck);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('stuck-reason-text')))
            .controller!
            .text,
        '  原因\n不丢失  ',
      );
      await support.textTap(t, '想不起来');
      expect(model(t), same(instance));
      expect(instance.title, '  活动🐾\n第二行  ');
      await support.textTap(t, '保留草稿并返回');
      expect(await t.runAsync(f.snapshot), before);
      await support.textTap(t, '打开');
      await settleNative(t);
      expect(model(t).restored, isTrue);
      expect(find.byKey(const ValueKey('note')), findsNothing);
      expect(model(t).note, '  备注🐾\n保持原文  ');
      expect(model(t).continuationHint, '  接续🐾\n第二行  ');
      expect(model(t).stuckReasonText, '  原因\n不丢失  ');
      expect(model(t).recoveryMethod?.name, 'walk');
      expect(model(t).recoveryQuality?.name, 'readyToContinue');
    },
  );

  testWidgets(
    'neutral validation, submit reveals collapsed error; independent time and picker cancellation',
    (t) async {
      final f = await support.openWidget(t);
      await mount(t, f);
      await support.textTap(t, '记得做了什么');
      expect(find.text('请填写活动内容。'), findsNothing);
      await support.textTap(t, '保存到账本');
      expect(find.text('请填写活动内容。'), findsOneWidget);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('activity')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await support.enter(t, 'activity', '活动');
      await support.enter(t, 'note', '🐾' * 2001);
      await support.tap(t, find.byKey(const ValueKey('recording-note-toggle')));
      expect(find.byKey(const ValueKey('note')), findsOneWidget);
      expect(find.text('备注最多 2000 个字符。'), findsOneWidget);
      await support.textTap(t, '保存到账本');
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('note')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await support.enter(t, 'note', '合法备注');
      await revealRecordingField(t, '开始时间');
      await support.tap(t, find.widgetWithText(ChoiceChip, '准确').first);
      await support.textTap(t, '开始时间');
      await support.textTap(t, '选择日期');
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await support.textTap(t, '选择时间');
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('time-dialog-input')),
        '2040-01-02 03:04',
      );
      await support.textTap(t, '取消');
      expect(model(t).time.startedAt, support.start);
      await support.textTap(t, '开始时间');
      await t.enterText(
        find.byKey(const ValueKey('time-dialog-input')),
        '2026-10-01 09:45',
      );
      await support.textTap(t, '确认');
      await support.textTap(t, '应用时间');
      expect(
        model(t).time.startedAt,
        DateTime(2026, 10, 1, 9, 45).millisecondsSinceEpoch,
      );
      expect(model(t).time.startPrecision, TimePrecision.exact);
      expect(model(t).time.endPrecision, TimePrecision.approximate);
    },
  );

  testWidgets(
    'goal sheet cancels, keeps same-name identities, clear association and focus',
    (t) async {
      final f = await support.openWidget(t);
      await t.runAsync(() async {
        for (final i in [1, 2]) {
          await f.goals.create(id: support.id(i), name: '同名目标🐾', now: 1);
        }
      });
      await mount(t, f);
      await support.textTap(t, '选择目标');
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('不关联'), findsOneWidget);
      expect(find.text('标识：${support.id(1)}'), findsOneWidget);
      await support.tap(
        t,
        find.byKey(ValueKey('goal-option-${support.id(2)}')),
      );
      expect(model(t).goalId, support.id(2));
      await support.textTap(t, '选择目标');
      await support.textTap(t, '取消');
      expect(model(t).goalId, support.id(2));
      await support.textTap(t, '选择目标');
      await support.textTap(t, '不关联');
      expect(model(t).goalId, isNull);
      expect(model(t).goalProvided, isTrue);
      expect(
        t
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '选择目标'))
            .focusNode!
            .hasFocus,
        isTrue,
      );
    },
  );

  testWidgets(
    'restored invalid fields stay readable without opening keyboard; Escape and modal focus',
    (t) async {
      final f = await support.openWidget(t);
      final store = FormDraftStore()
        ..value = RecordingDraft(
          context: support.newContext,
          startedAt: null,
          endedAt: null,
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.approximate,
          knowledgeState: BlockKnowledgeState.known,
          title: '',
          note: '🐾' * 2001,
          noteProvided: true,
        );
      await mount(t, f, store: store);
      expect(find.byKey(const ValueKey('note')), findsOneWidget);
      expect(model(t).restored, isTrue);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('activity')))
            .focusNode!
            .hasFocus,
        isFalse,
      );
      await support.enter(t, 'activity', '活动');
      await support.textTap(t, '开始时间');
      await t.enterText(
        find.byKey(const ValueKey('time-dialog-input')),
        '2040-01-02 03:04',
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(model(t).time.startedAt, isNull);
      expect(
        t
            .widget<ListTile>(find.widgetWithText(ListTile, '开始时间'))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(RecordingForm), findsNothing);
      expect(store.value!.title, '活动');
      expect(store.value!.note, '🐾' * 2001);
    },
  );

  testWidgets(
    'wide goal selector is the same choices in a centered 480 dialog',
    (t) async {
      t.view.physicalSize = Size(900, 800) * t.view.devicePixelRatio;
      await t.binding.setSurfaceSize(const Size(900, 800));
      try {
        final f = await support.openWidget(t);
        await t.runAsync(
          () => f.goals.create(id: support.id(2), name: '目标🐾', now: 1),
        );
        await mount(t, f);
        await support.textTap(t, '选择目标');
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(Dialog), findsOneWidget);
        await capture(t, 'goal-dialog-wide');
        expect(
          t
              .getSize(
                find.byWidgetPredicate(
                  (w) => w is ConstrainedBox && w.constraints.maxWidth == 480,
                ),
              )
              .width,
          lessThanOrEqualTo(480),
        );
        expect(
          find.byKey(ValueKey('goal-option-${support.id(2)}')),
          findsOneWidget,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(model(t).goalId, isNull);
        expect(
          t
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, '选择目标'),
              )
              .focusNode!
              .hasFocus,
          isTrue,
        );
      } finally {
        t.view.resetPhysicalSize();
        await t.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets(
    'distinct read, draft, formal, conflict, missing-source and committed states',
    (t) async {
      await t.binding.setSurfaceSize(const Size(360, 800));
      try {
        final f = await support.openWidget(t);
        final store = FormDraftStore()..failRead = true;
        await mount(t, f, store: store);
        expect(find.text(model(t).loadError!), findsOneWidget);
        await capture(t, 'failure-read');
        store.failRead = false;
        await support.textTap(t, '重试读取');
        await support.textTap(t, '想不起来');
        store.failSave = true;
        await support.enter(t, 'note', '原输入🐾');
        expect(find.text(model(t).storageError!), findsOneWidget);
        await capture(t, 'failure-draft-write');
        store.failClear = true;
        await support.textTap(t, '放弃草稿');
        expect(find.text('无法放弃草稿，输入已保留，请重试。'), findsOneWidget);
        expect(model(t).note, '原输入🐾');
        await capture(t, 'failure-discard');

        final trace = FailedFormalInsert();
        final formal = (await t.runAsync(
          () => support.Fixture.open(formal: trace),
        ))!;
        addTearDown(formal.close);
        await mount(t, formal);
        await support.textTap(t, '想不起来');
        trace.armed = true;
        await support.textTap(t, '保存到账本');
        expect(model(t).committed, isNull);
        expect(model(t).submitError, contains('正式保存失败'));
        await capture(t, 'failure-formal-write');
        expect(
          (await t.runAsync(
            () => formal.repo.readWindow(
              startedAt: support.start,
              endedAt: support.end,
            ),
          ))!.timeBlocks,
          isEmpty,
        );

        final conflict = await support.openWidget(t);
        await t.runAsync(
          () => conflict.repo.createSleepSession(
            id: support.id(20),
            startedAt: support.start,
            endedAt: support.end,
            startPrecision: TimePrecision.exact,
            endPrecision: TimePrecision.exact,
            type: SleepType.nap,
            now: 1,
          ),
        );
        await mount(t, conflict);
        await support.textTap(t, '想不起来');
        await support.textTap(t, '保存到账本');
        expect(find.textContaining('冲突记录：睡眠'), findsOneWidget);
        expect(find.text('标识：${support.id(20)}'), findsNothing);
        await support.textTap(t, '查看冲突记录编号');
        expect(find.text('标识：${support.id(20)}'), findsOneWidget);
        await support.textTap(t, '关闭');
        await capture(t, 'failure-conflict');
        await support.textTap(t, '调整当前记录时间');
        expect(find.text('开始时间'), findsOneWidget);
        expect(model(t).time.startPrecision, TimePrecision.approximate);

        final missing = await support.openWidget(t);
        await t.runAsync(missing.source);
        await mount(t, missing, context: support.editContext);
        await t.runAsync(() => missing.repo.deleteTimeBlock(support.id(8)));
        await support.textTap(t, '保存更正');
        expect(model(t).committed, isNull);
        expect(model(t).submitError, contains('记录已不存在'));
        await capture(t, 'failure-missing-source');

        final cleanup = support.Queries()..failClear = true;
        final committed = (await t.runAsync(
          () => support.Fixture.open(draft: cleanup),
        ))!;
        addTearDown(committed.close);
        committed.failRefresh = true;
        await mount(t, committed);
        await support.textTap(t, '想不起来');
        await support.textTap(t, '保存到账本');
        expect(model(t).committed, isNotNull);
        expect(find.text('保存到账本'), findsNothing);
        expect(find.text('继续清理并刷新'), findsOneWidget);
        expect(find.text('继续清理并刷新').hitTestable(), findsOneWidget);
        await capture(t, 'failure-committed-finish');
        final before = await t.runAsync(committed.snapshot);
        cleanup.failClear = false;
        committed.failRefresh = false;
        await support.textTap(t, '继续清理并刷新');
        expect(await t.runAsync(committed.snapshot), before);
      } finally {
        await t.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets(
    'mobile date/time and goal modals at all font sizes, cancel and selected civil minute',
    (t) async {
      final semantics = t.ensureSemantics();
      try {
        for (final width in [320.0, 360.0, 412.0]) {
          for (final scale in [1.0, 1.5, 2.0]) {
            t.view.physicalSize = Size(width, 800) * t.view.devicePixelRatio;
            t.platformDispatcher.textScaleFactorTestValue = scale;
            await t.binding.setSurfaceSize(Size(width, 800));
            final f = (await t.runAsync(support.Fixture.open))!;
            try {
              await t.runAsync(() async {
                for (final i in [1, 2]) {
                  await f.goals.create(
                    id: support.id(i),
                    name: '同名很长中文目标🐾需要完整换行显示',
                    now: 1,
                  );
                }
              });
              await mount(t, f);
              await support.textTap(t, '选择目标');
              expect(find.text('不关联'), findsOneWidget);
              await capture(t, 'goal-sheet-$width-$scale');
              await expectLater(t, meetsGuideline(androidTapTargetGuideline));
              await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
              await t.sendKeyEvent(LogicalKeyboardKey.escape);
              await t.pumpAndSettle();
              await support.textTap(t, '开始时间');
              await capture(t, 'time-dialog-$width-$scale');
              await support.textTap(t, '选择日期');
              expect(find.byType(DatePickerDialog), findsOneWidget);
              if (scale > 1.25) {
                expect(find.byType(InputDatePickerFormField), findsOneWidget);
                expect(find.byType(CalendarDatePicker), findsNothing);
              } else {
                expect(find.byType(CalendarDatePicker), findsOneWidget);
                expect(
                  t
                      .renderObject<RenderParagraph>(find.text('10'))
                      .didExceedMaxLines,
                  isFalse,
                );
              }
              await capture(t, 'date-picker-$width-$scale');
              expect(t.takeException(), isNull);
              await t.sendKeyEvent(LogicalKeyboardKey.escape);
              await t.pumpAndSettle();
              expect(
                t
                    .widget<TextButton>(find.widgetWithText(TextButton, '选择日期'))
                    .focusNode!
                    .hasFocus,
                isTrue,
              );
              await support.textTap(t, '选择时间');
              expect(find.byType(TimePickerDialog), findsOneWidget);
              await capture(t, 'time-picker-$width-$scale');
              expect(t.takeException(), isNull);
              // Confirm the current picker value; it stays in the outer dialog.
              await t.tap(find.text('OK'));
              await t.pumpAndSettle();
              expect(find.byType(TimePickerDialog), findsNothing);
              expect(model(t).time.startedAt, support.start);
              expect(
                t
                    .widget<TextField>(
                      find.byKey(const ValueKey('time-dialog-input')),
                    )
                    .controller!
                    .text,
                formatRecordingTime(support.start),
              );
              await t.sendKeyEvent(LogicalKeyboardKey.escape);
              await t.pumpAndSettle();
              expect(model(t).time.startPrecision, TimePrecision.approximate);
              expect(model(t).time.endPrecision, TimePrecision.approximate);
              expect(t.takeException(), isNull);
            } finally {
              await t.pumpWidget(const SizedBox.shrink());
              await t.pumpAndSettle();
              await t.runAsync(f.close);
            }
          }
        }
      } finally {
        semantics.dispose();
        t.view.resetPhysicalSize();
        t.platformDispatcher.clearTextScaleFactorTestValue();
        await t.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets(
    'mobile matrix all entry shapes, long text, keyboard-safe actions and guidelines',
    (t) async {
      addTearDown(t.view.resetViewInsets);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = t.ensureSemantics();
      try {
        for (final width in [320.0, 360.0, 412.0]) {
          for (final scale in [1.0, 1.5, 2.0]) {
            t.platformDispatcher.textScaleFactorTestValue = scale;
            t.view.physicalSize = Size(width, 800) * t.view.devicePixelRatio;
            await t.binding.setSurfaceSize(Size(width, 800));
            for (final shape in ['manual', 'direct', 'restored', 'edit']) {
              final f = (await t.runAsync(support.Fixture.open))!;
              try {
                var context = support.newContext;
                if (shape == 'edit') {
                  await t.runAsync(() => f.source(state: RhythmState.stuck));
                  context = support.editContext;
                }
                if (shape == 'restored') {
                  await t.runAsync(
                    () => f.drafts.save(
                      RecordingDraft(
                        context: context,
                        title: '长中文活动🐾\n保留多行',
                        note: '备注🐾\n' * 12,
                        noteProvided: true,
                        startedAt: support.start,
                        endedAt: support.end,
                        startPrecision: TimePrecision.approximate,
                        endPrecision: TimePrecision.exact,
                        knowledgeState: BlockKnowledgeState.unknown,
                        annotationIntent: RecordingAnnotationIntent.add,
                        annotationId: support.id(90),
                        rhythmState: RhythmState.recovery,
                        continuationHint: '接续🐾\n' * 12,
                        hintProvided: true,
                      ),
                    ),
                  );
                }
                t.view.viewInsets = const FakeViewPadding();
                await mount(
                  t,
                  f,
                  context: context,
                  suggestion: shape == 'manual'
                      ? const ManualTimeEntry()
                      : null,
                );
                expect(t.takeException(), isNull);
                await capture(t, '$shape-$width-$scale');
                await expectLater(t, meetsGuideline(androidTapTargetGuideline));
                await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
                final sdk = await textContrastGuideline.evaluate(t);
                if (!sdk.passed) {
                  debugPrint(
                    'SDK activity contrast $shape / $width / $scale: ${sdk.reason}',
                  );
                }
                await expectLater(
                  t,
                  meetsGuideline(RenderedTextContrast(captureKey: captureKey)),
                );
                final instance = model(t);
                t.view.viewInsets = FakeViewPadding(
                  bottom: 240 * t.view.devicePixelRatio,
                );
                await t.pumpAndSettle();
                final save = find.byKey(const ValueKey('recording-submit'));
                await Scrollable.ensureVisible(t.element(save), alignment: .5);
                await t.pumpAndSettle();
                expect(t.getRect(save).bottom, lessThanOrEqualTo(560));
                expect(save.hitTestable(), findsOneWidget);
                expect(t.getSize(save).height, greaterThanOrEqualTo(48));
                expect(model(t), same(instance));
                await capture(t, '$shape-keyboard-$width-$scale');
                expect(t.takeException(), isNull);
              } finally {
                await t.pumpWidget(const SizedBox.shrink());
                await t.pumpAndSettle();
                await t.runAsync(f.close);
              }
            }
          }
        }
      } finally {
        semantics.dispose();
        t.view.resetPhysicalSize();
        await t.binding.setSurfaceSize(null);
      }
    },
  );
}
