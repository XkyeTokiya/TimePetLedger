import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';

void main() {
  testWidgets('bootstrap owns one connection across rebuilds and closes it', (
    tester,
  ) async {
    final database = (await tester.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    var opens = 0;
    Future<AppDatabase> open() async {
      opens++;
      return database;
    }

    await tester.pumpWidget(AppBootstrap(openDatabase: open));
    await tester.pumpAndSettle();
    expect(find.text('Hello World!'), findsOneWidget);
    await tester.pumpWidget(AppBootstrap(openDatabase: open));
    expect(opens, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await expectLater(
        database.customSelect('SELECT 1').get(),
        throwsStateError,
      );
    });
  });

  testWidgets('connection finishing after disposal is still closed', (
    tester,
  ) async {
    final database = (await tester.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final pending = Completer<AppDatabase>();
    await tester.pumpWidget(AppBootstrap(openDatabase: () => pending.future));
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(database);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await expectLater(
        database.customSelect('SELECT 1').get(),
        throwsStateError,
      );
    });
  });

  testWidgets('opening failure cannot show a ready app or raw diagnostics', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppBootstrap(
        openDatabase: () async {
          throw const DatabaseOpenException('private SQL path');
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hello World!'), findsNothing);
    expect(find.text('无法打开本地存储，请重新启动应用。'), findsOneWidget);
    expect(find.textContaining('private SQL path'), findsNothing);
  });
}
