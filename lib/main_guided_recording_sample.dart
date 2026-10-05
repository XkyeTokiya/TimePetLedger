import 'package:flutter/material.dart';

import 'dev/guided_recording_sample.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '问答记录样板',
    theme: guidedSampleTheme,
    home: const GuidedRecordingSample(),
  ),
);
