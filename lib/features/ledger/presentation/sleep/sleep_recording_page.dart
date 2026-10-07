import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../domain/projection/derived_duration.dart';
import '../../domain/sleep_type.dart';
import '../../domain/time_precision.dart';
import '../recording_time_picker.dart';
import '../sleep_form_controller.dart';
import '../sleep_time_input.dart';
import '../summary_formatting.dart';

/// 睡眠记录页：单页问答式编辑，复用既有 [SleepFormController] 的草稿、校验、
/// 提交、更正、删除与失败重试合同；不承载日账本或详情等其它事实视图。
///
/// 版式按第一轮睡眠原型（assets/sleep-recording-round-one）：主问题、类型分段、
/// 两端「日期在左 / 时间在右」、时长、红色备注链接与单个主动作。
///
/// 按 Q-030，回顾式输入两端统一 approximate，不提供精度选择；仅当草稿带着旧
/// 精度时才原样保留，不在本页改写历史事实。
class SleepRecordingPage extends StatefulWidget {
  const SleepRecordingPage({super.key, required this.controller});

  final SleepFormController controller;

  @override
  State<SleepRecordingPage> createState() => _SleepRecordingPageState();
}

class _SleepRecordingPageState extends State<SleepRecordingPage> {
  SleepFormController get model => widget.controller;

  final note = TextEditingController();
  final scroll = ScrollController();
  bool showErrors = false;
  bool allowPop = false;
  bool exiting = false;
  bool noteOpen = false;

  bool get _editing => model.context.isEditing;

  @override
  void initState() {
    super.initState();
    model.addListener(_changed);
    _initialize();
  }

  Future<void> _initialize() async {
    await model.initialize();
    if (!mounted) return;
    note.text = model.note;
    setState(() {});
  }

  void _changed() {
    if (note.text != model.note) note.text = model.note;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(_changed);
    note.dispose();
    scroll.dispose();
    super.dispose();
  }

  /// 两端精度缺省时统一按 approximate 补齐；已存精度保持原样（Q-030 / Q-031）。
  void _defaultPrecision() {
    if (model.startPrecision == null || model.endPrecision == null) {
      model.setPrecision(
        start: model.startPrecision ?? TimePrecision.approximate,
        end: model.endPrecision ?? TimePrecision.approximate,
      );
    }
  }

  Future<void> _times({bool isStart = true, bool isDate = false}) async {
    final picker = isDate ? showRecordingDatePicker : showRecordingTimePicker;
    final result = await picker(
      context,
      value: isStart ? model.startedAt : model.endedAt,
      date: model.context.date,
    );
    if (!mounted || result == null) return;
    model.setTime(
      start: isStart ? result : model.startedAt,
      end: isStart ? model.endedAt : result,
    );
    _defaultPrecision();
    setState(() => showErrors = false);
  }

  Future<void> _adjustDuration() async {
    final result = await showRecordingDurationPicker(
      context,
      startedAt: model.startedAt,
      endedAt: model.endedAt,
    );
    if (!mounted || result == null) return;
    model.setTime(start: result.start, end: result.end);
    _defaultPrecision();
  }

  Future<void> _save() async {
    if (!model.editable || exiting) return;
    FocusScope.of(context).unfocus();
    setState(() => showErrors = true);
    if (model.type == null ||
        model.timeError != null ||
        model.noteError != null) {
      return;
    }
    _defaultPrecision();
    final result = await model.submit();
    if (!mounted) return;
    if (model.committed != null) {
      if (model.committed!.complete) await _close(result);
    } else if (scroll.hasClients) {
      scroll.jumpTo(0);
    }
  }

  Future<void> _finish() async {
    final refreshed = await model.retryFinish();
    if (mounted && refreshed != null) await _close(refreshed);
  }

  Future<void> _delete() async {
    final start = model.startedAt;
    final end = model.endedAt;
    final crossDay =
        start != null &&
        end != null &&
        DateTime.fromMillisecondsSinceEpoch(start).day !=
            DateTime.fromMillisecondsSinceEpoch(end).day;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这段睡眠？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (start != null && end != null)
              Text('${formatSleepTime(start)} → ${formatSleepTime(end)}'),
            const SizedBox(height: 10),
            Text(
              crossDay
                  ? '会删除整段跨夜睡眠，包括其他日期里显示的部分。相关日期的时间线会随之更新。'
                  : '删除这次完整睡眠后，相关日期的覆盖和睡眠摘要会重新计算。',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('保留记录'),
          ),
          FilledButton(
            key: const ValueKey('sleep-confirm-delete'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await model.delete();
    if (!mounted || result == null) return;
    await _close(result);
  }

  Future<void> _close(Object? result) async {
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _leave({bool discard = false}) async {
    if (exiting || model.discarding || model.submitting) return;
    if (model.committed != null) {
      await _close(model.committed!.refreshed);
      return;
    }
    if (model.deleted != null) {
      await _close(model.deleted!.refreshed);
      return;
    }
    setState(() => exiting = true);
    final success = discard ? await model.discard() : await model.flush();
    if (!mounted) return;
    if (!success) {
      setState(() => exiting = false);
      return;
    }
    await _close(null);
  }

  Future<void> _discard() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃这次睡眠？'),
        content: const Text('未保存的内容将被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续填写'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放弃草稿'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await _leave(discard: true);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: homeTheme,
    child: PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            key: const ValueKey('sleep-exit'),
            onPressed: model.submitting ? null : _leave,
          ),
          title: Text(_editing ? '编辑睡眠' : '记录睡眠'),
        ),
        body: model.loading
            ? const Center(child: CircularProgressIndicator())
            : model.loadError != null
            ? _loadFailure()
            : AbsorbPointer(
                absorbing: exiting || model.submitting || model.discarding,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          if (model.restored) ...[
                            const Text('上次没写完，接着记吧。', style: _restored),
                            const SizedBox(height: 12),
                          ],
                          if (model.storageError != null) ...[
                            _notice(model.storageError!, error: true),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: model.editable
                                    ? model.retrySave
                                    : null,
                                child: const Text('重试保存草稿'),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (model.committedMessage case final message?) ...[
                            _notice(message, success: true),
                            const SizedBox(height: 12),
                          ],
                          if (model.submitError != null &&
                              model.conflicts.isEmpty) ...[
                            _notice(model.submitError!, error: true),
                            const SizedBox(height: 12),
                          ],
                          for (final conflict in model.conflicts) ...[
                            _notice(
                              '已有记录：${formatSleepTime(conflict.startedAt)} — '
                              '${formatSleepTime(conflict.endedAt)}',
                              error: true,
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text('几点睡，\n几点醒？', style: _question),
                          const SizedBox(height: 20),
                          _typeSegment(),
                          const SizedBox(height: 24),
                          _endpoint('入睡', model.startedAt, 'sleep-start'),
                          _endpoint('醒来', model.endedAt, 'sleep-end'),
                          const SizedBox(height: 16),
                          _duration(),
                          const SizedBox(height: 16),
                          _note(),
                          if (showErrors && model.type == null) ...[
                            const SizedBox(height: 12),
                            Text('先选择主睡眠或小睡。', style: _error),
                          ],
                          if (showErrors && model.timeError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              model.timeError!,
                              key: const ValueKey('sleep-time-error'),
                              style: _error,
                            ),
                          ],
                          if (_editing && model.committed == null) ...[
                            const SizedBox(height: 12),
                            const Text('保存后才会更新这条睡眠。', style: _muted),
                          ],
                        ],
                      ),
                    ),
                    _footer(),
                  ],
                ),
              ),
      ),
    ),
  );

  Widget _loadFailure() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(model.loadError!, style: const TextStyle(color: HomePalette.error)),
      if (model.missingOriginal)
        TextButton(
          onPressed: () => _leave(discard: true),
          child: const Text('放弃草稿'),
        )
      else
        FilledButton(onPressed: _initialize, child: const Text('重试读取')),
      if (model.storageError != null) ...[
        const SizedBox(height: 12),
        Text(model.storageError!),
      ],
    ],
  );

  /// 新建睡眠默认主睡眠；切换类型时选中底纸在两段之间滑动。
  Widget _typeSegment() {
    final mainSelected = model.type != SleepType.nap;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _segmentSlide;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HomePalette.tint,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              key: const ValueKey('sleep-type-indicator'),
              alignment: mainSelected
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              duration: duration,
              curve: Curves.easeInOutCubic,
              child: FractionallySizedBox(
                key: const ValueKey('sleep-type-pill'),
                widthFactor: 0.5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: HomePalette.paper,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final type in SleepType.values)
                Expanded(
                  child: Semantics(
                    selected: model.type == type,
                    button: true,
                    child: Material(
                      key: ValueKey(
                        type == SleepType.mainSleep
                            ? 'sleep-type-main'
                            : 'sleep-type-nap',
                      ),
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        // 分段切换不叠加按压高亮 / 水波，选择态由滑动底纸表达。
                        splashFactory: NoSplash.splashFactory,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        onTap: model.editable
                            ? () => model.setType(type)
                            : null,
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: homeTapTarget,
                          ),
                          alignment: Alignment.center,
                          child: _segmentContent(type, duration),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 文字与图标颜色随底纸同步过渡，避免滑动途中瞬时跳色。
  Widget _segmentContent(SleepType type, Duration duration) {
    final selected = model.type == type;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: selected ? 1 : 0),
      duration: duration,
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) {
        final color = Color.lerp(
          HomePalette.ink,
          HomePalette.accentDeep,
          value,
        )!;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == SleepType.mainSleep
                  ? Icons.bedtime_outlined
                  : Icons.nights_stay_outlined,
              size: 19,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              type == SleepType.mainSleep ? '主睡眠' : '小睡',
              style: TextStyle(
                fontFamily: homeSerifFamily,
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.lerp(
                  FontWeight.w400,
                  FontWeight.w600,
                  value,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _endpoint(String name, int? value, String key) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: HomePalette.hairline)),
    ),
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: _label),
        const SizedBox(height: 3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              key: ValueKey('$key-date'),
              onTap: model.editable
                  ? () => _times(isStart: key == 'sleep-start', isDate: true)
                  : null,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_dateLabel(value), style: _dateStyle),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 15,
                      color: HomePalette.muted,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            InkWell(
              key: ValueKey('$key-time'),
              onTap: model.editable
                  ? () => _times(isStart: key == 'sleep-start')
                  : null,
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                alignment: Alignment.centerRight,
                child: Text(
                  value == null
                      ? '选时间'
                      : formatSleepTime(value).split(' ').last,
                  style: value == null ? _emptyTimeStyle : _timeStyle,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  String _dateLabel(int? value) {
    if (value == null) return '选日期';
    final date = DateTime.fromMillisecondsSinceEpoch(value);
    final referenceYear = model.context.date.year;
    return date.year == referenceYear
        ? '${date.month}月${date.day}日'
        : '${date.year}年${date.month}月${date.day}日';
  }

  Widget _duration() {
    final start = model.startedAt;
    final end = model.endedAt;
    final text = start != null && end != null && end > start
        ? formatDerivedDuration(
            DerivedDuration(
              milliseconds: end - start,
              hasApproximation:
                  model.startPrecision != TimePrecision.exact ||
                  model.endPrecision != TimePrecision.exact,
            ),
          )
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          const Text('这次睡眠', style: _durationLabel),
          const SizedBox(height: 4),
          TextButton(
            onPressed: model.editable && (start != null || end != null)
                ? _adjustDuration
                : null,
            child: Text(
              text ??
                  (start != null && end != null
                      ? '请确认入睡和醒来的日期'
                      : '选好时间，就能看到睡了多久。'),
              key: const ValueKey('sleep-duration'),
              style: text == null ? _durationLabel : _durationValue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _note() {
    final open = noteOpen || (showErrors && model.noteError != null);
    final label = open
        ? '收起备注'
        : model.note.isNotEmpty
        ? '查看备注'
        : '补充备注';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('sleep-note-toggle'),
            onPressed: model.editable
                ? () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() => noteOpen = !open);
                  }
                : null,
            icon: Icon(open ? Icons.remove : Icons.add, size: 16),
            label: Text(label),
            style: TextButton.styleFrom(
              foregroundColor: HomePalette.accentDeep,
              padding: const EdgeInsets.symmetric(vertical: 7),
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontFamily: homeSerifFamily,
                fontSize: 15,
              ),
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 9),
          const Text('还有什么想记下的？', style: _fieldLabel),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('sleep-note'),
            controller: note,
            enabled: model.editable,
            onChanged: model.setNote,
            maxLines: 4,
            minLines: 3,
            decoration: InputDecoration(
              hintText: '可以留空',
              errorText: model.noteError,
            ),
          ),
        ],
      ],
    );
  }

  Widget _footer() {
    final committed = model.postCommit;
    final conflict = model.conflicts.isNotEmpty;
    final VoidCallback? action = model.finishPending
        ? _finish
        : committed
        ? (model.committed != null && !model.committed!.complete
              ? _finish
              : _leave)
        : conflict
        ? (model.editable ? _times : null)
        : !model.editable
        ? null
        : _save;
    final String label = model.submitting
        ? '正在保存…'
        : model.finishPending
        ? '重试收尾'
        : committed
        ? '回到账本'
        : conflict
        ? '调整时间'
        : _editing
        ? '保存修改'
        : '保存睡眠';
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: HomePalette.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (model.editable &&
                !committed &&
                !model.postCommit &&
                (model.type != null ||
                    model.startedAt != null ||
                    model.endedAt != null ||
                    model.note.isNotEmpty ||
                    _editing)) ...[
              Row(
                children: [
                  TextButton(
                    key: const ValueKey('sleep-discard'),
                    onPressed: exiting ? null : _discard,
                    child: const Text('放弃草稿'),
                  ),
                  const Spacer(),
                  if (_editing && model.entryEditor != null)
                    TextButton(
                      key: const ValueKey('sleep-delete'),
                      onPressed: exiting ? null : _delete,
                      style: TextButton.styleFrom(
                        foregroundColor: HomePalette.accentDeep,
                      ),
                      child: const Text('删除睡眠'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            FilledButton.icon(
              key: const ValueKey('sleep-primary'),
              onPressed: action,
              icon: const Icon(Icons.check, size: 19),
              label: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.error = false, this.success = false});
  final String text;
  final bool error;
  final bool success;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: error
          ? HomePalette.errorSurface
          : success
          ? HomePalette.tint
          : HomePalette.paper,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: homeSerifFamily,
        fontSize: 14,
        height: 1.5,
        color: error
            ? HomePalette.error
            : success
            ? HomePalette.recovery
            : HomePalette.muted,
      ),
    ),
  );
}

Widget _notice(String text, {bool error = false, bool success = false}) =>
    _Notice(text, error: error, success: success);

const _question = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 32,
  height: 1.35,
  letterSpacing: -0.5,
  color: HomePalette.ink,
);
const _muted = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 14,
  height: 1.5,
  color: HomePalette.muted,
);
const _label = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 14,
  color: HomePalette.muted,
);
const _fieldLabel = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 15,
  color: HomePalette.ink,
);
const _dateStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 16,
  color: HomePalette.ink,
);
const _timeStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 36,
  height: 1.25,
  letterSpacing: -1,
  color: HomePalette.ink,
);
const _emptyTimeStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 23,
  height: 1.4,
  color: HomePalette.muted,
);
const _durationLabel = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 16,
  color: HomePalette.muted,
);
const _durationValue = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 25,
  color: HomePalette.ink,
);
const _error = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 14,
  color: HomePalette.error,
);
const _restored = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 13,
  color: HomePalette.muted,
);
const _segmentSlide = Duration(milliseconds: 200);
