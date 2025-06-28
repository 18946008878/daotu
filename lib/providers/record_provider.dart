import 'package:flutter/material.dart';
import '../models/record.dart';
import '../db/db_helper.dart';

class RecordProvider with ChangeNotifier {
  List<Record> _records = [];
  List<Record> get records => _records;

  int _page = 1;
  final int _pageSize = 20;
  bool hasMore = true;
  bool isLoading = false;
  int? _currentTripId;

  // 分页加载（重置）
  Future<void> loadRecords(int tripId, {bool reset = true}) async {
    if (reset || _currentTripId != tripId) {
      _page = 1;
      _records = [];
      hasMore = true;
      _currentTripId = tripId;
    }
    isLoading = true;
    notifyListeners();
    final newRecords = await DBHelper().getRecordsByTripPaged(tripId, _page, _pageSize);
    if (reset) {
      _records = newRecords;
    } else {
      _records.addAll(newRecords);
    }
    hasMore = newRecords.length == _pageSize;
    isLoading = false;
    notifyListeners();
  }

  // 加载更多
  Future<void> loadMoreRecords(int tripId) async {
    if (!hasMore || isLoading) return;
    _page++;
    await loadRecords(tripId, reset: false);
  }

  Future<void> addRecord(Record record) async {
    await DBHelper().insertRecord(record);
    await loadRecords(record.tripId);
  }

  Future<void> deleteRecord(int id, int tripId) async {
    await DBHelper().deleteRecord(id);
    await loadRecords(tripId);
  }

  Future<void> updateRecord(Record record) async {
    await DBHelper().updateRecord(record);
    await loadRecords(record.tripId);
  }
}
