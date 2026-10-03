import 'package:drift/native.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';

/// Existing flow tests begin after today's confirmation; never open app storage.
Future<DriftSleepOpeningStore> openCheckedSleepOpening(DateTime now) async {
  final store = await DriftSleepOpeningStore.open(NativeDatabase.memory());
  await store.claim(deviceDateOfInstant(now.millisecondsSinceEpoch));
  return store;
}
