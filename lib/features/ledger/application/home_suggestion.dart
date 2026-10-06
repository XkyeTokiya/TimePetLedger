import '../domain/projection/ledger_coverage.dart';
import '../domain/projection/reconciliation_window.dart';

/// 首页建议区域当前要显示的动作（Q-028 / Q-029）。
enum HomeSuggestionKind { sleep, record, review, greeting }

/// 建议区域的一句话与可选入口；文案简短自然，可由用户继续打磨。
final class HomeSuggestion {
  const HomeSuggestion({required this.kind, required this.title, this.action});

  final HomeSuggestionKind kind;
  final String title;

  /// 问候没有入口；其余动作对应记录睡眠 / 补记一笔 / 开始复盘。
  final String? action;
}

/// 睡眠建议窗口长度：从睡眠时点起 4 小时（Q-029）。
const int sleepSuggestionWindowMinutes = 4 * 60;

/// 记录建议阈值：尾部连续 Gap 达到 2 小时（Q-028）。
const int recordSuggestionGapMinutes = 2 * 60;

/// 默认时点：睡眠 08:00、复盘 22:00（Q-028）；守卫仅为本机偏好缺省。
const int defaultSleepReminderMinutes = 8 * 60;
const int defaultReviewReminderMinutes = 22 * 60;

/// 延伸至对账窗口末端的尾部 Gap 分钟数；没有尾部 Gap 时返回 null。
///
/// 只认最后一段结束恰好落在窗口末端的缺口，不把不连续缺口相加（Q-029）。
int? trailingGapEndingAt(Iterable<UnresolvedSpan> spans, int windowEndedAt) {
  int? minutes;
  for (final span in spans) {
    if (span.endedAt == windowEndedAt) {
      minutes = span.duration.milliseconds ~/ 60000;
    }
  }
  return minutes;
}

/// 按 Q-028 优先级与 Q-029 边界推导当前建议；不读取时钟、时区或存储。
///
/// 历史 / 未来日期只返回问候；今天才判断睡眠、记录与复盘。
HomeSuggestion resolveHomeSuggestion({
  required LedgerDateRelation relation,
  required int nowMinutes,
  required int sleepReminderMinutes,
  required int reviewReminderMinutes,
  required bool hasRecordedMainSleepToday,
  required int? trailingGapMinutes,
}) {
  if (relation != LedgerDateRelation.today) {
    return greetingSuggestion(nowMinutes);
  }
  if (nowMinutes >= sleepReminderMinutes &&
      nowMinutes < sleepReminderMinutes + sleepSuggestionWindowMinutes &&
      !hasRecordedMainSleepToday) {
    return const HomeSuggestion(
      kind: HomeSuggestionKind.sleep,
      title: '昨晚睡得怎么样？',
      action: '记录睡眠',
    );
  }
  if ((trailingGapMinutes ?? 0) >= recordSuggestionGapMinutes) {
    return const HomeSuggestion(
      kind: HomeSuggestionKind.record,
      title: '刚才在做什么？',
      action: '补记一笔',
    );
  }
  if (nowMinutes >= reviewReminderMinutes) {
    return const HomeSuggestion(
      kind: HomeSuggestionKind.review,
      title: '今天过得怎么样？',
      action: '开始复盘',
    );
  }
  return greetingSuggestion(nowMinutes);
}

/// 三类建议都不满足时的普通问候；按当地时刻分段，不引用可编辑时点。
HomeSuggestion greetingSuggestion(int nowMinutes) => HomeSuggestion(
  kind: HomeSuggestionKind.greeting,
  title: nowMinutes < 12 * 60
      ? '早上好。'
      : nowMinutes < 18 * 60
      ? '下午好。'
      : '晚上好。',
);
