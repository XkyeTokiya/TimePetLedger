import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/persistence/app_database.dart';
import '../../core/persistence/database_connection.dart';
import '../main_app.dart';

Future<AppDatabase> openAppDatabase() async {
  return AppDatabase.open(await connectDatabase('time_pet_ledger'));
}

/// Owns the single app connection. No raw database is exposed to presentation.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key, this.openDatabase = openAppDatabase});

  final Future<AppDatabase> Function() openDatabase;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<void> _ready;
  AppDatabase? _database;

  @override
  void initState() {
    super.initState();
    _ready = _open();
  }

  Future<void> _open() async {
    final database = await widget.openDatabase();
    if (!mounted) {
      await database.close();
    } else {
      _database = database;
    }
  }

  @override
  void dispose() {
    final database = _database;
    if (database != null) {
      unawaited(
        database.close().catchError((Object error, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'app bootstrap',
              context: ErrorDescription('while closing local storage'),
            ),
          );
        }),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: Text('无法打开本地存储，请重新启动应用。'))),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return const MainApp();
      },
    );
  }
}
