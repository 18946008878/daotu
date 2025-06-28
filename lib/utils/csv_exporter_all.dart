import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import '../models/record.dart';
import '../models/trip.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;

class CsvExporterAll {
  static Future<String> exportAllTrips(List<Trip> trips, Map<int, List<Record>> tripRecords) async {
    List<List<dynamic>> rows = [
      [
        '团号', '日期', '类型', '分类', '金额', '备注', '支付方式', '分成比例', '分成金额', '明细'
      ]
    ];
    for (final trip in trips) {
      final records = tripRecords[trip.id] ?? [];
      for (final r in records) {
        rows.add([
          trip.groupCode,
          '${trip.date.year}-${trip.date.month.toString().padLeft(2, '0')}-${trip.date.day.toString().padLeft(2, '0')}',
          r.type == RecordType.expense ? '支出' : '收入',
          r.category,
          r.amount.toStringAsFixed(2),
          r.remark ?? '',
          r.payMethod ?? '',
          r.shareRatio?.toStringAsFixed(2) ?? '',
          r.shareAmount?.toStringAsFixed(2) ?? '',
          r.detail ?? '',
        ]);
      }
    }
    String csv = const ListToCsvConverter().convert(rows);
    if (kIsWeb) {
      // Web端：直接返回csv字符串，由UI层处理下载
      return csv;
    } else {
      // 非Web端（如Android/iOS/桌面）
      final downloadsDir = Directory(p.join((await getExternalStorageDirectory())!.parent.parent.parent.parent.path, 'Download', '极简导游收支'));
      if (!await downloadsDir.exists()) await downloadsDir.create(recursive: true);
      final file = File(p.join(downloadsDir.path, '全部行程收支_${DateTime.now().millisecondsSinceEpoch}.csv'));
      await file.writeAsString(csv, encoding: utf8);
      return file.path;
    }
  }
}
