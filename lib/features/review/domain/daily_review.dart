import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';

import 'review_text.dart';
import 'tomorrow_first_step.dart';

/// 每日解释与一个下一步（MODEL-001、DR-001–004）。
///
/// 身份、自然日期和元数据由调用方显式提供，不读取时钟。构造既可
/// 表达新记录也可还原历史记录，不代表保存成功；按日唯一留给存储。
final class DailyReview {
  DailyReview({
    required EntityId id,
    required this.date,
    required this.tomorrowFirstStep,
    required this.createdAt,
    required this.updatedAt,
    String? summary,
    String? reflection,
  }) : id = requireUuidV4(id),
       summary = normalizeReviewText(summary, 'summary'),
       reflection = normalizeReviewText(reflection, 'reflection') {
    if (!tomorrowFirstStep.isForReviewDate(date)) {
      throw ArgumentError.value(
        tomorrowFirstStep.intendedDate,
        'tomorrowFirstStep',
        'Q-001: intendedDate must be the next civil day after review.date',
      );
    }
  }

  final EntityId id;
  final CivilDate date;
  final String? summary;
  final String? reflection;
  final TomorrowFirstStep tomorrowFirstStep;
  final InstantMilliseconds createdAt;
  final InstantMilliseconds updatedAt;
}
