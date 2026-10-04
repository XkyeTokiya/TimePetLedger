import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';

import '../support/app_sleep_navigation.dart' show enter, tapText;
import 'sleep_recording_flow_test.dart'
    show setup, stop, fill, editSleep, date, newContext;

String noteInput(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey('sleep-note')))
    .controller!
    .text;

void main() {
  testWidgets('optional note can be omitted or blank for both sleep types', (
    tester,
  ) async {
    final app = await setup(tester);
    await tapText(tester, '确认睡眠起止');
    await fill(tester, '2026-09-28 23:50', '2026-09-29 07:40');
    expect(noteInput(tester), isEmpty);
    await tapText(tester, '确认并保存到账本');
    expect((await tester.runAsync(app.sleeps))!.single['note'], isNull);
    await tapText(tester, '记录睡眠');
    await fill(tester, '2026-09-29 10:00', '2026-09-29 10:20', nap: true);
    await enter(tester, 'sleep-note', ' \n\t ');
    await tapText(tester, '确认并保存到账本');
    final rows = (await tester.runAsync(app.sleeps))!;
    expect(rows, hasLength(2));
    expect(rows.every((r) => r['note'] == null), isTrue);
    await tester.runAsync(() => app.noOtherFacts());
    await stop(tester);
  });

  testWidgets(
    'raw multiline note restores, failed note-only edit retains input and explicit clearing saves null',
    (tester) async {
      final app = await setup(tester);
      const raw = '  第一行\n  第二行😀  ';
      const edited = '  更正说明\n第二段  ';
      await tapText(tester, '确认睡眠起止');
      await fill(tester, '2026-09-28 23:50', '2026-09-29 07:40');
      await enter(tester, 'sleep-note', raw);
      await tapText(tester, '保留草稿并返回');
      expect(await tester.runAsync(app.sleeps), isEmpty);
      final saved = (await tester.runAsync(() => app.readDraft(newContext)))!;
      expect(saved.note, raw);
      expect(saved.noteProvided, isTrue);
      await tapText(tester, '记录睡眠');
      expect(noteInput(tester), raw);
      await tapText(tester, '确认并保存到账本');
      final original = (await tester.runAsync(app.sleeps))!.single;
      expect(original['note'], '第一行\n  第二行😀');
      final id = original['id'] as String;
      final context = SleepDraftContext.edit(date: date, sleepSessionId: id);
      await editSleep(tester, id);
      expect(noteInput(tester), original['note']);
      await enter(tester, 'sleep-note', edited);
      await tapText(tester, '保留草稿并返回');
      expect((await tester.runAsync(app.sleeps))!.single, original);
      await editSleep(tester, id);
      expect(noteInput(tester), edited);
      // Equal time/type/precision must not classify a note-only draft as committed.
      await tester.scrollUntilVisible(
        find.text('保存更正'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('保存更正'), findsOneWidget);
      await tester.runAsync(
        () => app.db.customStatement(
          "CREATE TRIGGER fail_note AFTER UPDATE ON sleep_sessions BEGIN SELECT RAISE(ABORT, 'test note rollback'); END",
        ),
      );
      await tapText(tester, '保存更正');
      expect(find.text('正式保存失败，睡眠输入和草稿已保留，请重试。'), findsOneWidget);
      expect((await tester.runAsync(app.sleeps))!.single, original);
      expect(
        (await tester.runAsync(() => app.readDraft(context, whileOpen: true)))!
            .note,
        edited,
      );
      await tapText(tester, '保留草稿并返回');
      await editSleep(tester, id);
      expect(noteInput(tester), edited);
      await tester.runAsync(
        () => app.db.customStatement('DROP TRIGGER fail_note'),
      );
      await tapText(tester, '保存更正');
      final updated = (await tester.runAsync(app.sleeps))!.single;
      expect(updated['note'], '更正说明\n第二段');
      expect(updated['id'], id);
      expect(updated['created_at'], original['created_at']);
      expect(updated['started_at'], original['started_at']);
      expect(updated['ended_at'], original['ended_at']);
      expect(await tester.runAsync(() => app.readDraft(context)), isNull);
      await editSleep(tester, id);
      await enter(tester, 'sleep-note', ' \n ');
      await tapText(tester, '保留草稿并返回');
      await editSleep(tester, id);
      expect(noteInput(tester), ' \n ');
      expect((await tester.runAsync(app.sleeps))!.single, updated);
      await tapText(tester, '保存更正');
      expect((await tester.runAsync(app.sleeps))!.single['note'], isNull);
      expect(await tester.runAsync(() => app.readDraft(context)), isNull);
      await tester.runAsync(() => app.noOtherFacts());
      await stop(tester);
    },
  );

  testWidgets(
    '2001 code points remain in draft; trimmed 2000 emoji save without UTF16 clipping',
    (tester) async {
      final app = await setup(tester);
      final overlong = '😀' * 2001;
      await tapText(tester, '确认睡眠起止');
      await fill(tester, '2026-09-28 23:50', '2026-09-29 07:40');
      await enter(tester, 'sleep-note', overlong);
      expect(find.text('备注最多 2000 个字符。'), findsOneWidget);
      await tapText(tester, '确认并保存到账本');
      expect(await tester.runAsync(app.sleeps), isEmpty);
      await tapText(tester, '保留草稿并返回');
      expect(
        (await tester.runAsync(() => app.readDraft(newContext)))!.note,
        overlong,
      );
      await tapText(tester, '记录睡眠');
      expect(noteInput(tester), overlong);
      final boundary = '😀' * 2000;
      await enter(tester, 'sleep-note', '  $boundary\n ');
      expect(find.text('备注最多 2000 个字符。'), findsNothing);
      await tapText(tester, '确认并保存到账本');
      expect((await tester.runAsync(app.sleeps))!.single['note'], boundary);
      expect(await tester.runAsync(() => app.readDraft(newContext)), isNull);
      await stop(tester);
    },
  );
}
