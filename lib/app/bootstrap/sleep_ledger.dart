import '../../core/persistence/app_database.dart';
import '../../features/ledger/application/sleep_ledger_loader.dart';
import '../../features/ledger/data/drift_ledger_repository.dart';
import '../time/device_recording_date.dart';

/// 复用 app 管理的数据库与当前设备日期适配，独立于普通记录编辑器。
SleepLedgerLoader createSleepLedgerLoader(AppDatabase database) =>
    SleepLedgerLoader(
      repository: DriftLedgerRepository(database),
      resolveDate: resolveDeviceRecordingDate,
    );
