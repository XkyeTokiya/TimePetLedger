import 'package:flutter/material.dart';

import '../../../goals/domain/goal_repository.dart';
import '../../application/recording_entry_editor.dart';
import '../../application/recording_entry_saver.dart';
import '../../application/recording_time_suggestion.dart';
import '../../domain/recording_draft_store.dart';
import '../recording_form_controller.dart';
import 'activity_recording_page.dart';

/// 活动记录入口：拥有 [RecordingFormController] 的生命周期，再把纯展示的
/// [ActivityRecordingPage] 挂上去。
///
/// 构造参数与旧 `RecordingForm` 一致，宿主可以整体替换入口；草稿、校验、
/// 提交、更正与失败重试仍由既有 controller / saver / editor 负责。
class ActivityRecordingEntry extends StatefulWidget {
  const ActivityRecordingEntry({
    super.key,
    required this.context,
    required this.store,
    required this.loadSuggestion,
    this.entrySaver,
    this.entryEditor,
    this.goals,
  });

  final RecordingDraftContext context;
  final RecordingDraftStore store;
  final Future<RecordingTimeSuggestion> Function() loadSuggestion;
  final RecordingEntrySaver? entrySaver;
  final RecordingEntryEditor? entryEditor;
  final GoalRepository? goals;

  @override
  State<ActivityRecordingEntry> createState() => _ActivityRecordingEntryState();
}

class _ActivityRecordingEntryState extends State<ActivityRecordingEntry> {
  late final RecordingFormController model;

  @override
  void initState() {
    super.initState();
    model = RecordingFormController(
      context: widget.context,
      store: widget.store,
      loadSuggestion: widget.loadSuggestion,
      entrySaver: widget.entrySaver,
      entryEditor: widget.entryEditor,
      goals: widget.goals,
    );
    model.initialize();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ActivityRecordingPage(model: model);
}
