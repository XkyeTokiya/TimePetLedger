import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/ledger/application/sleep_entry_saver.dart';
import '../../features/ledger/application/sleep_entry_editor.dart';
import '../../features/ledger/application/recording_time_suggestion.dart';
import '../../features/ledger/application/sleep_time_prediction_loader.dart';
import '../../features/ledger/domain/sleep_draft_store.dart';
import '../../features/ledger/presentation/sleep/sleep_recording_page.dart';
import '../../features/ledger/presentation/sleep_form_controller.dart';

/// 使用 app 生命周期持有的会话输入存储；页面退出后仍可在同一会话恢复。
class SleepEntry extends StatefulWidget {
  const SleepEntry({
    super.key,
    required this.context,
    required this.store,
    this.createSaver,
    this.createEditor,
    this.loadSuggestion,
    this.loadPredictions,
  });
  final SleepDraftContext context;
  final Future<RecordingTimeSuggestion> Function()? loadSuggestion;
  final Future<SleepTimePredictions> Function()? loadPredictions;
  final SleepDraftStore store;
  final SleepEntrySaver Function(SleepDraftStore)? createSaver;
  final SleepEntryEditor Function(SleepEntrySaver)? createEditor;
  @override
  State<SleepEntry> createState() => _SleepEntryState();
}

class _SleepEntryState extends State<SleepEntry> {
  SleepFormController? _controller;
  String? _error;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final store = widget.store;
      if (!mounted) {
        return;
      }
      final saver = widget.createSaver?.call(store);
      _controller = SleepFormController(
        context: widget.context,
        store: store,
        loadSuggestion: widget.loadSuggestion,
        loadPredictions: widget.loadPredictions,
        entrySaver: saver,
        entryEditor: saver == null ? null : widget.createEditor?.call(saver),
      );
    } catch (_) {
      if (mounted) _error = '无法打开睡眠填写，请重试。';
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    controller?.dispose();
    if (controller != null) {
      unawaited(() async {
        try {
          await controller.flush();
        } catch (error, stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'sleep entry',
              context: ErrorDescription('while retaining sleep input'),
            ),
          );
        }
      }());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller case final controller?) {
      return SleepRecordingPage(controller: controller);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('记录睡眠')),
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(onPressed: _open, child: const Text('重试打开')),
                ],
              ),
      ),
    );
  }
}
