import 'package:flutter/material.dart';

import '../features/ledger/presentation/activity_editor.dart';
import 'activity_sample.dart';

class ActivityPreview extends StatefulWidget {
  const ActivityPreview({super.key});
  @override
  State<ActivityPreview> createState() => _ActivityPreviewState();
}

class _ActivityPreviewState extends State<ActivityPreview> {
  final session = ActivitySampleSession(ActivitySample.simple);
  late SampleActivityController model = session.controller();
  bool? saved;
  int revision = 0;

  void reopen() {
    model.dispose();
    if (saved == true) {
      session.drafts.value = session.simulatedSaved;
      session.pendingCommit = null;
    }
    setState(() {
      model = session.controller();
      saved = null;
      revision++;
    });
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: saved == null
            ? ActivityEditor(
                key: ValueKey(revision),
                controller: model,
                createGoal: session.goals.createNamed,
                initialPanel: ActivityPanel.rhythm,
                onExit: () => setState(() => saved = false),
                onSaved: () => setState(() => saved = true),
              )
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        saved! ? '活动已保存到当前预览' : '本次填写已保留',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Text(model.title),
                      const SizedBox(height: 8),
                      Text(activityInterval(model.time)),
                      if (saved!) ...[
                        const SizedBox(height: 16),
                        const Text('内容仅保存在本次预览会话，未写入正式账本。'),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: reopen,
                        child: Text(saved! ? '继续编辑这条活动' : '继续编辑'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    ),
  );
}
