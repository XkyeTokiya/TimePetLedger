import '../../core/persistence/app_database.dart';
import '../../features/ledger/application/recording_ledger_loader.dart';
import '../../features/ledger/data/drift_ledger_repository.dart';
import '../time/device_recording_date.dart';

/// 借用 app 已管理的连接；供普通记录入口及保存后刷新注入，不另开数据库。
RecordingLedgerLoader createRecordingLedgerLoader(AppDatabase database) =>
    RecordingLedgerLoader(
      repository: DriftLedgerRepository(database),
      resolveDate: resolveDeviceRecordingDate,
    );
