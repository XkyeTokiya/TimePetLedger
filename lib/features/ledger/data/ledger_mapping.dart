import 'package:drift/drift.dart';

import '../../../core/persistence/app_database.dart';
import '../domain/block_knowledge_state.dart';
import '../domain/ledger_repository.dart';
import '../domain/rhythm_annotation.dart';
import '../domain/rhythm_details.dart';
import '../domain/rhythm_state.dart';
import '../domain/sleep_session.dart';
import '../domain/sleep_type.dart';
import '../domain/time_block.dart';
import '../domain/time_precision.dart';

// Fixed storage codes, independent of enum ordinal or localized labels.
const _precision = {
  'exact': TimePrecision.exact,
  'approximate': TimePrecision.approximate,
};
const _knowledge = {
  'known': BlockKnowledgeState.known,
  'unknown': BlockKnowledgeState.unknown,
};
const _sleepType = {'mainSleep': SleepType.mainSleep, 'nap': SleepType.nap};
const _rhythm = {
  'progress': RhythmState.progress,
  'stuck': RhythmState.stuck,
  'recovery': RhythmState.recovery,
};
const _reason = {
  'taskTooLarge': StuckReasonCode.taskTooLarge,
  'unclearNextStep': StuckReasonCode.unclearNextStep,
  'sleepy': StuckReasonCode.sleepy,
  'brainFog': StuckReasonCode.brainFog,
  'anxious': StuckReasonCode.anxious,
  'interrupted': StuckReasonCode.interrupted,
  'unsure': StuckReasonCode.unsure,
  'other': StuckReasonCode.other,
};
const _method = {
  'walk': RecoveryMethod.walk,
  'meal': RecoveryMethod.meal,
  'shower': RecoveryMethod.shower,
  'empty': RecoveryMethod.empty,
  'entertainment': RecoveryMethod.entertainment,
  'switchTask': RecoveryMethod.switchTask,
  'breakDownTask': RecoveryMethod.breakDownTask,
  'askForHelp': RecoveryMethod.askForHelp,
  'other': RecoveryMethod.other,
};
const _quality = {
  'notRecovered': RecoveryQuality.notRecovered,
  'partlyRecovered': RecoveryQuality.partlyRecovered,
  'readyToContinue': RecoveryQuality.readyToContinue,
};

TimeBlock timeBlockFromDatabase(Map<String, Object?> values) {
  final row = _LedgerRow('time_blocks', values);
  return row.decode(() {
    final block = TimeBlock(
      id: row.text('id'),
      startedAt: row.integer('started_at'),
      endedAt: row.integer('ended_at'),
      startPrecision: row.code('start_precision', _precision),
      endPrecision: row.code('end_precision', _precision),
      knowledgeState: row.code('knowledge_state', _knowledge),
      title: row.optionalText('title'),
      goalId: row.optionalText('goal_id'),
      categoryId: row.optionalText('category_id'),
      note: row.optionalText('note'),
      createdAt: row.integer('created_at'),
      updatedAt: row.integer('updated_at'),
    );
    row.unchangedText('title', block.title);
    row.unchangedText('note', block.note);
    return block;
  });
}

SleepSession sleepSessionFromDatabase(Map<String, Object?> values) {
  final row = _LedgerRow('sleep_sessions', values);
  return row.decode(() {
    final sleep = SleepSession(
      id: row.text('id'),
      startedAt: row.integer('started_at'),
      endedAt: row.integer('ended_at'),
      startPrecision: row.code('start_precision', _precision),
      endPrecision: row.code('end_precision', _precision),
      type: row.code('sleep_type', _sleepType),
      note: row.optionalText('note'),
      createdAt: row.integer('created_at'),
      updatedAt: row.integer('updated_at'),
    );
    row.unchangedText('note', sleep.note);
    return sleep;
  });
}

RhythmAnnotation rhythmAnnotationFromDatabase(Map<String, Object?> values) {
  final row = _LedgerRow('rhythm_annotations', values);
  return row.decode(() {
    final annotation = RhythmAnnotation(
      id: row.text('id'),
      timeBlockId: row.text('time_block_id'),
      state: row.code('state', _rhythm),
      stuckReasonCode: row.optionalCode('stuck_reason_code', _reason),
      stuckReasonText: row.optionalText('stuck_reason_text'),
      recoveryMethod: row.optionalCode('recovery_method', _method),
      recoveryQuality: row.optionalCode('recovery_quality', _quality),
      continuationHint: row.optionalText('continuation_hint'),
      createdAt: row.integer('created_at'),
      updatedAt: row.integer('updated_at'),
    );
    row.unchangedText('stuck_reason_text', annotation.stuckReasonText);
    row.unchangedText('continuation_hint', annotation.continuationHint);
    return annotation;
  });
}

/// Local parsing only; not an entity base class or reusable repository layer.
class _LedgerRow {
  _LedgerRow(this.table, this.values);
  final String table;
  final Map<String, Object?> values;

  Object? value(String field) {
    if (!values.containsKey(field)) throw LedgerDataException(table, field);
    return values[field];
  }

  String text(String field) => switch (value(field)) {
    String text => text,
    _ => throw LedgerDataException(table, field),
  };
  String? optionalText(String field) => switch (value(field)) {
    null => null,
    String text => text,
    _ => throw LedgerDataException(table, field),
  };
  int integer(String field) => switch (value(field)) {
    int number => number,
    _ => throw LedgerDataException(table, field),
  };
  T code<T>(String field, Map<String, T> codes) =>
      codes[text(field)] ?? (throw LedgerDataException(table, field));
  T? optionalCode<T>(String field, Map<String, T> codes) =>
      value(field) == null ? null : code(field, codes);

  void unchangedText(String field, String? normalized) {
    if (value(field) != normalized) throw LedgerDataException(table, field);
  }

  T decode<T>(T Function() construct) {
    try {
      return construct();
    } on ArgumentError catch (error) {
      throw LedgerDataException(table, error.name?.toString() ?? 'domain');
    }
  }
}

// Write codes use the same explicit mapping as reads, not enum ordinals.
String _encode<T>(T value, Map<String, T> codes) =>
    codes.entries.singleWhere((entry) => entry.value == value).key;
String? _encodeOptional<T>(T? value, Map<String, T> codes) =>
    value == null ? null : _encode(value, codes);

TimeBlocksCompanion timeBlockToDatabase(TimeBlock block) => TimeBlocksCompanion(
  id: Value(block.id),
  startedAt: Value(block.startedAt),
  endedAt: Value(block.endedAt),
  startPrecision: Value(_encode(block.startPrecision, _precision)),
  endPrecision: Value(_encode(block.endPrecision, _precision)),
  knowledgeState: Value(_encode(block.knowledgeState, _knowledge)),
  title: Value(block.title),
  goalId: Value(block.goalId),
  categoryId: Value(block.categoryId),
  note: Value(block.note),
  createdAt: Value(block.createdAt),
  updatedAt: Value(block.updatedAt),
);

SleepSessionsCompanion sleepSessionToDatabase(SleepSession sleep) =>
    SleepSessionsCompanion(
      id: Value(sleep.id),
      startedAt: Value(sleep.startedAt),
      endedAt: Value(sleep.endedAt),
      startPrecision: Value(_encode(sleep.startPrecision, _precision)),
      endPrecision: Value(_encode(sleep.endPrecision, _precision)),
      sleepType: Value(_encode(sleep.type, _sleepType)),
      note: Value(sleep.note),
      createdAt: Value(sleep.createdAt),
      updatedAt: Value(sleep.updatedAt),
    );

RhythmAnnotationsCompanion rhythmAnnotationToDatabase(RhythmAnnotation a) =>
    RhythmAnnotationsCompanion(
      id: Value(a.id),
      timeBlockId: Value(a.timeBlockId),
      state: Value(_encode(a.state, _rhythm)),
      stuckReasonCode: Value(_encodeOptional(a.stuckReasonCode, _reason)),
      stuckReasonText: Value(a.stuckReasonText),
      recoveryMethod: Value(_encodeOptional(a.recoveryMethod, _method)),
      recoveryQuality: Value(_encodeOptional(a.recoveryQuality, _quality)),
      continuationHint: Value(a.continuationHint),
      createdAt: Value(a.createdAt),
      updatedAt: Value(a.updatedAt),
    );
