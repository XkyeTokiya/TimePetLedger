import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';

import 'review_text.dart';

/// 单一行动意向，不是任务，也不是 RhythmAnnotation.continuationHint。
final class TomorrowFirstStep {
  TomorrowFirstStep({
    required CivilDate reviewDate,
    required String text,
    EntityId? goalId,
  }) : text = _requireText(text),
       goalId = goalId == null ? null : requireUuidV4(goalId),
       intendedDate = _nextDate(reviewDate);

  /// 必填长文本，清理后 1–2,000 个 Unicode 码点。
  final String text;
  final EntityId? goalId;

  /// 仅由复盘日期推导，不接受独立输入，也不单独持久化（Q-001）。
  final CivilDate intendedDate;

  bool isForReviewDate(CivilDate date) => intendedDate == _nextDate(date);
}

String _requireText(String text) {
  final normalized = normalizeReviewText(text, 'text');
  if (normalized == null) {
    throw ArgumentError.value(text, 'text', 'MODEL-002: Must not be blank');
  }
  return normalized;
}

CivilDate _nextDate(CivilDate date) {
  final leap =
      date.year % 4 == 0 && (date.year % 100 != 0 || date.year % 400 == 0);
  final lastDay = switch (date.month) {
    2 => leap ? 29 : 28,
    4 || 6 || 9 || 11 => 30,
    _ => 31,
  };
  if (date.day < lastDay) {
    return CivilDate(year: date.year, month: date.month, day: date.day + 1);
  }
  if (date.month < 12) {
    return CivilDate(year: date.year, month: date.month + 1, day: 1);
  }
  final nextYear = date.year + 1;
  if (nextYear <= date.year) {
    throw ArgumentError.value(
      date,
      'reviewDate',
      'Next year is not representable',
    );
  }
  return CivilDate(year: nextYear, month: 1, day: 1);
}
