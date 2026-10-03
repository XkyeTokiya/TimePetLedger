import 'package:flutter/foundation.dart';

import '../../../core/time/civil_date.dart';
import '../application/review_context_loader.dart';

enum ReviewReadStatus { idle, loading, absent, ready, failed }

final class ReviewContextController extends ChangeNotifier {
  ReviewContextController({
    required this.loader,
    required this.now,
    required this.dateOfInstant,
    required this.selectedDate,
  });

  final ReviewContextLoader loader;
  final int Function() now;
  final CivilDate Function(int) dateOfInstant;
  CivilDate selectedDate;
  ReviewContext? context;
  ReviewReadStatus status = ReviewReadStatus.idle;
  int _request = 0;
  bool _disposed = false;

  Future<void> select(CivilDate date) {
    selectedDate = date;
    return refresh();
  }

  Future<void> selectToday() => select(dateOfInstant(now()));

  void invalidate() {
    ++_request;
    context = null;
    status = ReviewReadStatus.idle;
    notifyListeners();
  }

  Future<void> refresh() async {
    final request = ++_request;
    context = null;
    status = ReviewReadStatus.loading;
    notifyListeners();
    try {
      final result = await loader.load(date: selectedDate, now: now());
      if (_disposed || request != _request) return;
      context = result;
      status = result.review == null
          ? ReviewReadStatus.absent
          : ReviewReadStatus.ready;
    } catch (_) {
      if (_disposed || request != _request) return;
      status = ReviewReadStatus.failed;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_request;
    super.dispose();
  }
}
