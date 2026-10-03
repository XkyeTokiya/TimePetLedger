import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/ledger/application/sleep_entry_saver.dart';
import '../../features/ledger/application/sleep_entry_editor.dart';
import '../../features/ledger/data/drift_sleep_draft_store.dart';
import '../../features/ledger/domain/sleep_draft_store.dart';
import '../../features/ledger/presentation/sleep_form.dart';
import '../../features/ledger/presentation/sleep_form_controller.dart';

/// App-owned route lifetime: open a dedicated store, drain writes, then close.
/// The presentation form receives only its controller, never a database opener.
class SleepEntry extends StatefulWidget {
  const SleepEntry({
    super.key,
    required this.context,
    required this.openStore,
    this.createSaver,
    this.createEditor,
  });
  final SleepDraftContext context;
  final Future<DriftSleepDraftStore> Function() openStore;
  final SleepEntrySaver Function(SleepDraftStore)? createSaver;
  final SleepEntryEditor Function(SleepEntrySaver)? createEditor;
  @override
  State<SleepEntry> createState() => _SleepEntryState();
}

class _SleepEntryState extends State<SleepEntry> {
  DriftSleepDraftStore? _store;
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
      final store = await widget.openStore();
      if (!mounted) {
        await store.close();
        return;
      }
      try {
        final saver = widget.createSaver?.call(store);
        _controller = SleepFormController(
          context: widget.context,
          store: store,
          entrySaver: saver,
          entryEditor: saver == null ? null : widget.createEditor?.call(saver),
        );
        _store = store;
      } catch (_) {
        await store.close();
        rethrow;
      }
    } catch (_) {
      if (mounted) _error = '无法打开睡眠草稿，请重试。';
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    final store = _store;
    controller?.dispose();
    if (store != null) {
      unawaited(() async {
        try {
          await controller?.flush();
          await store.close();
        } catch (error, stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'sleep entry',
              context: ErrorDescription('while closing sleep drafts'),
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
      return SleepForm(controller: controller);
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
