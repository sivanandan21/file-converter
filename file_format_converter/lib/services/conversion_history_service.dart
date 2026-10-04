import 'package:hive/hive.dart';
import '../models/conversion_record.dart';
import '../core/constants/app_constants.dart';

/// Persists and retrieves conversion history using Hive.
class ConversionHistoryService {
  Box<ConversionRecord> get _box =>
      Hive.box<ConversionRecord>(AppConstants.conversionHistoryBox);

  List<ConversionRecord> get all => _box.values.toList().reversed.toList();

  List<ConversionRecord> getByType(String type) =>
      all.where((r) => r.conversionType == type).toList();

  Future<void> add(ConversionRecord record) async {
    await _box.put(record.id, record);
  }

  Future<void> toggleStar(String id) async {
    final record = _box.get(id);
    if (record != null) {
      record.isStarred = !record.isStarred;
      await record.save();
    }
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  List<ConversionRecord> search(String query) {
    final q = query.toLowerCase();
    return all.where((r) {
      return r.outputFileName.toLowerCase().contains(q) ||
          r.sourceFileName.toLowerCase().contains(q) ||
          r.conversionType.toLowerCase().contains(q);
    }).toList();
  }
}
