import 'dart:io';
import 'package:csv/csv.dart';
import '../models/record.dart';
import '../models/trip.dart';
import '../db/db_helper.dart';

class CsvImporter {
  /// 支持导入全部行程收支（与导出格式兼容）
  static Future<int> importAllTrips(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final rows = const CsvToListConverter().convert(content, eol: '\n');
    if (rows.length <= 1) return 0;
    final header = rows[0];
    final data = rows.sublist(1);
    int importCount = 0;
    for (final row in data) {
      // 兼容表头：团号,日期,类型,分类,金额,备注,支付方式,分成比例,分成金额,明细
      final groupCode = row[0]?.toString() ?? '';
      final dateStr = row[1]?.toString() ?? '';
      final typeStr = row[2]?.toString() ?? '';
      final category = row[3]?.toString() ?? '';
      final amount = double.tryParse(row[4]?.toString() ?? '') ?? 0;
      final remark = row[5]?.toString();
      final payMethod = row[6]?.toString();
      final shareRatio = double.tryParse(row[7]?.toString() ?? '');
      final shareAmount = double.tryParse(row[8]?.toString() ?? '');
      final detail = row[9]?.toString();
      // 查找或新建行程
      final trips = await DBHelper().getAllTrips();
      Trip? trip = trips.firstWhere(
        (t) => t.groupCode == groupCode && t.date.toIso8601String().startsWith(dateStr),
        orElse: () => Trip(groupCode: groupCode, date: DateTime.parse(dateStr)),
      );
      if (trip.id == null) {
        final id = await DBHelper().insertTrip(trip);
        trip = Trip(id: id, groupCode: groupCode, date: DateTime.parse(dateStr));
      }
      final type = typeStr == '支出' ? RecordType.expense : RecordType.income;
      final record = Record(
        tripId: trip.id!,
        type: type,
        category: category,
        amount: amount,
        time: DateTime.parse(dateStr),
        remark: remark,
        payMethod: payMethod,
        shareRatio: shareRatio,
        shareAmount: shareAmount,
        detail: detail,
      );
      await DBHelper().insertRecord(record);
      importCount++;
    }
    return importCount;
  }
}
