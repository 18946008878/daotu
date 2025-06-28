import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip.dart';
import '../models/record.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _db;
  static Box? _hiveBox;

  Future<bool> get isWeb async => kIsWeb;

  Future<void> init() async {
    if (kIsWeb) {
      await Hive.initFlutter();
      _hiveBox = await Hive.openBox('daotu');
    } else {
      _db = await _initDb();
    }
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'daotu.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE trips (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            groupCode TEXT NOT NULL,
            startDate TEXT,
            endDate TEXT,
            date TEXT NOT NULL,
            peopleCount INTEGER,
            remark TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tripId INTEGER NOT NULL,
            type INTEGER NOT NULL,
            category TEXT NOT NULL,
            amount REAL NOT NULL,
            time TEXT NOT NULL,
            remark TEXT,
            payMethod TEXT,
            shareRatio REAL,
            shareAmount REAL,
            detail TEXT,
            FOREIGN KEY(tripId) REFERENCES trips(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // Web端Hive存储辅助方法
  Future<List<Map<String, dynamic>>> _getAllFromHive(String prefix) async {
    final box = _hiveBox!;
    return box.keys
        .where((k) => k.toString().startsWith(prefix))
        .map((k) => Map<String, dynamic>.from(box.get(k)))
        .toList();
  }

  Future<void> _deleteFromHive(String prefix, int id) async {
    final box = _hiveBox!;
    box.delete('$prefix\u0000$id');
  }

  // 行程CRUD
  @override
  Future<int> insertTrip(Trip trip) async {
    final supabase = Supabase.instance.client;
    // 直接插入云端并获取返回id
    final response = await supabase.from('trips').insert({
      'group_code': trip.groupCode,
      'start_date': trip.startDate?.toIso8601String(),
      'end_date': trip.endDate?.toIso8601String(),
      'date': trip.date.toIso8601String(),
      'people_count': trip.peopleCount,
      'remark': trip.remark,
    }).select().single();
    final tripId = response['id'] as int;
    // 可选：本地同步一份
    if (await isWeb) {
      final box = _hiveBox!;
      box.put('trip_\u0000$tripId', trip.toMap()..['id'] = tripId);
    } else {
      final database = await db;
      await database.insert('trips', trip.toMap()..['id'] = tripId);
    }
    return tripId;
  }

  @override
  Future<List<Trip>> getAllTrips() async {
    if (await isWeb) {
      final list = await _getAllFromHive('trip_');
      return list.map((e) => Trip.fromMap(e)).toList();
    } else {
      final database = await db;
      final List<Map<String, dynamic>> maps = await database.query('trips', orderBy: 'date DESC');
      return maps.map((e) => Trip.fromMap(e)).toList();
    }
  }

  // 分页获取行程列表
  Future<List<Trip>> getTripsPaged(int page, int pageSize) async {
    if (await isWeb) {
      final list = await _getAllFromHive('trip_');
      list.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
      final paged = list.skip((page - 1) * pageSize).take(pageSize).toList();
      return paged.map((e) => Trip.fromMap(e)).toList();
    } else {
      final database = await db;
      final List<Map<String, dynamic>> maps = await database.query(
        'trips',
        orderBy: 'date DESC',
        limit: pageSize,
        offset: (page - 1) * pageSize,
      );
      return maps.map((e) => Trip.fromMap(e)).toList();
    }
  }

  // 拉取所有行程（优先云端，失败时本地）
  Future<List<Trip>> fetchAllTripsFromCloud() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('trips').select().order('date', ascending: false);
      if (response != null && response is List) {
        return response.map((e) => Trip.fromMap({
          'id': e['id'],
          'groupCode': e['group_code'],
          'startDate': e['start_date'],
          'endDate': e['end_date'],
          'date': e['date'],
          'peopleCount': e['people_count'],
          'remark': e['remark'],
        })).toList();
      }
    } catch (e) {
      // 网络异常等，降级为本地
    }
    return await getAllTrips();
  }

  // Supabase云端分页（如需优先云端，可扩展fetchAllTripsFromCloudPaged等）
  Future<List<Trip>> fetchTripsFromCloudPaged(int page, int pageSize) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('trips')
          .select()
          .order('date', ascending: false)
          .range((page - 1) * pageSize, page * pageSize - 1);
      if (response != null && response is List) {
        return response.map((e) => Trip.fromMap({
          'id': e['id'],
          'groupCode': e['group_code'],
          'startDate': e['start_date'],
          'endDate': e['end_date'],
          'date': e['date'],
          'peopleCount': e['people_count'],
          'remark': e['remark'],
        })).toList();
      }
    } catch (e) {
      // 网络异常等，降级为本地
    }
    return await getTripsPaged(page, pageSize);
  }

  @override
  Future<int> deleteTrip(int id) async {
    // 先删除云端
    final supabase = Supabase.instance.client;
    await supabase.from('trips').delete().eq('id', id);
    // 再删除本地
    if (await isWeb) {
      await _deleteFromHive('trip_', id);
      return 1;
    } else {
      final database = await db;
      return await database.delete('trips', where: 'id = ?', whereArgs: [id]);
    }
  }

  @override
  Future<int> updateTrip(Trip trip) async {
    if (await isWeb) {
      final box = _hiveBox!;
      box.put('trip_\u0000${trip.id}', trip.toMap());
      // Supabase同步
      final supabase = Supabase.instance.client;
      await supabase.from('trips').update({
        'group_code': trip.groupCode,
        'start_date': trip.startDate?.toIso8601String(),
        'end_date': trip.endDate?.toIso8601String(),
        'date': trip.date.toIso8601String(),
        'people_count': trip.peopleCount,
        'remark': trip.remark,
      }).eq('id', trip.id!);
      return 1;
    } else {
      final database = await db;
      final result = await database.update('trips', trip.toMap(), where: 'id = ?', whereArgs: [trip.id]);
      // Supabase同步
      final supabase = Supabase.instance.client;
      await supabase.from('trips').update({
        'group_code': trip.groupCode,
        'start_date': trip.startDate?.toIso8601String(),
        'end_date': trip.endDate?.toIso8601String(),
        'date': trip.date.toIso8601String(),
        'people_count': trip.peopleCount,
        'remark': trip.remark,
      }).eq('id', trip.id!);
      return result;
    }
  }

  // 收支记录CRUD
  @override
  Future<int> insertRecord(Record record) async {
    final supabase = Supabase.instance.client;
    // 直接插入云端，tripId必须为云端真实id
    final response = await supabase.from('records').insert({
      'trip_id': record.tripId,
      'type': record.type.index,
      'category': record.category,
      'amount': record.amount,
      'time': record.time.toIso8601String(),
      'remark': record.remark,
      'pay_method': record.payMethod,
      'share_ratio': record.shareRatio,
      'share_amount': record.shareAmount,
      'detail': record.detail,
    }).select().single();
    final recordId = response['id'] as int;
    // 可选：本地同步一份
    if (await isWeb) {
      final box = _hiveBox!;
      box.put('record_\u0000$recordId', record.toMap()..['id'] = recordId);
    } else {
      final database = await db;
      await database.insert('records', record.toMap()..['id'] = recordId);
    }
    return recordId;
  }

  @override
  Future<List<Record>> getRecordsByTrip(int tripId) async {
    if (await isWeb) {
      final list = await _getAllFromHive('record_');
      return list.where((e) => e['tripId'] == tripId).map((e) => Record.fromMap(e)).toList();
    } else {
      final database = await db;
      final List<Map<String, dynamic>> maps = await database.query(
        'records',
        where: 'tripId = ?',
        whereArgs: [tripId],
        orderBy: 'time DESC',
      );
      return maps.map((e) => Record.fromMap(e)).toList();
    }
  }

  // 分页获取指定行程的收支记录
  Future<List<Record>> getRecordsByTripPaged(int tripId, int page, int pageSize) async {
    if (await isWeb) {
      final list = await _getAllFromHive('record_');
      final filtered = list.where((e) => e['tripId'] == tripId).toList();
      filtered.sort((a, b) => (b['time'] ?? '').compareTo(a['time'] ?? ''));
      final paged = filtered.skip((page - 1) * pageSize).take(pageSize).toList();
      return paged.map((e) => Record.fromMap(e)).toList();
    } else {
      final database = await db;
      final List<Map<String, dynamic>> maps = await database.query(
        'records',
        where: 'tripId = ?',
        whereArgs: [tripId],
        orderBy: 'time DESC',
        limit: pageSize,
        offset: (page - 1) * pageSize,
      );
      return maps.map((e) => Record.fromMap(e)).toList();
    }
  }

  // 拉取指定行程的所有收支记录（优先云端，失败时本地）
  Future<List<Record>> fetchRecordsByTripFromCloud(int tripId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('records').select().eq('trip_id', tripId).order('time', ascending: false);
      if (response != null && response is List) {
        return response.map((e) => Record.fromMap({
          'id': e['id'],
          'tripId': e['trip_id'],
          'type': e['type'],
          'category': e['category'],
          'amount': e['amount'],
          'time': e['time'],
          'remark': e['remark'],
          'payMethod': e['pay_method'],
          'shareRatio': e['share_ratio'],
          'shareAmount': e['share_amount'],
          'detail': e['detail'],
        })).toList();
      }
    } catch (e) {
      // 网络异常等，降级为本地
    }
    return await getRecordsByTrip(tripId);
  }

  // Supabase云端分页（如需优先云端，可扩展fetchAllTripsFromCloudPaged等）
  Future<List<Record>> fetchRecordsByTripFromCloudPaged(int tripId, int page, int pageSize) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('records')
          .select()
          .eq('trip_id', tripId)
          .order('time', ascending: false)
          .range((page - 1) * pageSize, page * pageSize - 1);
      if (response != null && response is List) {
        return response.map((e) => Record.fromMap({
          'id': e['id'],
          'tripId': e['trip_id'],
          'type': e['type'],
          'category': e['category'],
          'amount': e['amount'],
          'time': e['time'],
          'remark': e['remark'],
          'payMethod': e['pay_method'],
          'shareRatio': e['share_ratio'],
          'shareAmount': e['share_amount'],
          'detail': e['detail'],
        })).toList();
      }
    } catch (e) {
      // 网络异常等，降级为本地
    }
    return await getRecordsByTripPaged(tripId, page, pageSize);
  }

  @override
  Future<int> deleteRecord(int id) async {
    // 先删除云端
    final supabase = Supabase.instance.client;
    await supabase.from('records').delete().eq('id', id);
    // 再删除本地
    if (await isWeb) {
      await _deleteFromHive('record_', id);
      return 1;
    } else {
      final database = await db;
      return await database.delete('records', where: 'id = ?', whereArgs: [id]);
    }
  }

  @override
  Future<int> updateRecord(Record record) async {
    if (await isWeb) {
      final box = _hiveBox!;
      box.put('record_\u0000${record.id}', record.toMap());
      // Supabase同步
      final supabase = Supabase.instance.client;
      await supabase.from('records').update({
        'trip_id': record.tripId,
        'type': record.type.index,
        'category': record.category,
        'amount': record.amount,
        'time': record.time.toIso8601String(),
        'remark': record.remark,
        'pay_method': record.payMethod,
        'share_ratio': record.shareRatio,
        'share_amount': record.shareAmount,
        'detail': record.detail,
      }).eq('id', record.id!);
      return 1;
    } else {
      final database = await db;
      final result = await database.update('records', record.toMap(), where: 'id = ?', whereArgs: [record.id]);
      // Supabase同步
      final supabase = Supabase.instance.client;
      await supabase.from('records').update({
        'trip_id': record.tripId,
        'type': record.type.index,
        'category': record.category,
        'amount': record.amount,
        'time': record.time.toIso8601String(),
        'remark': record.remark,
        'pay_method': record.payMethod,
        'share_ratio': record.shareRatio,
        'share_amount': record.shareAmount,
        'detail': record.detail,
      }).eq('id', record.id!);
      return result;
    }
  }

  /// 自动同步本地与云端 trips 数据
  Future<void> syncTrips() async {
    final supabase = Supabase.instance.client;
    // 1. 拉取云端所有 trips
    final cloudTripsRaw = await supabase.from('trips').select();
    final cloudTrips = <int, Map<String, dynamic>>{};
    for (final e in cloudTripsRaw) {
      cloudTrips[e['id'] as int] = e;
    }
    // 2. 拉取本地所有 trips
    final localTrips = await getAllTrips();
    // 3. 检查本地有但云端没有的，自动上传
    for (final trip in localTrips) {
      if (trip.id == null || !cloudTrips.containsKey(trip.id)) {
        // 本地新增，上传到云端
        final response = await supabase.from('trips').insert({
          'group_code': trip.groupCode,
          'start_date': trip.startDate?.toIso8601String(),
          'end_date': trip.endDate?.toIso8601String(),
          'date': trip.date.toIso8601String(),
          'people_count': trip.peopleCount,
          'remark': trip.remark,
        }).select().single();
        // 更新本地id
        final newId = response['id'] as int;
        final updatedTrip = trip.copyWith(id: newId);
        // 可选：同步本地存储id
        if (await isWeb) {
          final box = _hiveBox!;
          box.put('trip_\u0000$newId', updatedTrip.toMap());
        } else {
          final database = await db;
          await database.insert('trips', updatedTrip.toMap());
        }
      }
    }
    // 4. 检查云端有但本地没有的，自动下载
    for (final e in cloudTrips.values) {
      if (!localTrips.any((t) => t.id == e['id'])) {
        // 云端新增，下载到本地
        final trip = Trip(
          id: e['id'],
          groupCode: e['group_code'],
          startDate: e['start_date'] != null ? DateTime.parse(e['start_date']) : null,
          endDate: e['end_date'] != null ? DateTime.parse(e['end_date']) : null,
          date: e['date'] != null ? DateTime.parse(e['date']) : DateTime.now(),
          peopleCount: e['people_count'],
          remark: e['remark'],
        );
        if (await isWeb) {
          final box = _hiveBox!;
          box.put('trip_\u0000${trip.id}', trip.toMap());
        } else {
          final database = await db;
          await database.insert('trips', trip.toMap());
        }
      }
    }
    // 5. 冲突检测（如本地和云端同id但内容不同）
    for (final trip in localTrips) {
      final cloud = cloudTrips[trip.id];
      if (cloud != null) {
        // 简单内容比对
        if (trip.groupCode != cloud['group_code'] ||
            trip.date.toIso8601String() != cloud['date']) {
          // 冲突，提示或自动合并
          // TODO: 可弹窗提示用户选择以本地/云端为准，或自动合并
        }
      }
    }
  }

  /// 自动同步本地与云端 records 数据
  Future<void> syncRecords() async {
    final supabase = Supabase.instance.client;
    // 1. 拉取云端所有 records
    final cloudRecordsRaw = await supabase.from('records').select();
    final cloudRecords = <int, Map<String, dynamic>>{};
    for (final e in cloudRecordsRaw) {
      cloudRecords[e['id'] as int] = e;
    }
    // 2. 拉取本地所有 records
    // 这里假设有 getAllRecords 方法（可遍历所有 tripId 调用 getRecordsByTrip）
    final localTrips = await getAllTrips();
    final localRecords = <Record>[];
    for (final trip in localTrips) {
      localRecords.addAll(await getRecordsByTrip(trip.id!));
    }
    // 3. 本地有云端没有的，上传
    for (final record in localRecords) {
      if (record.id == null || !cloudRecords.containsKey(record.id)) {
        final response = await supabase.from('records').insert({
          'trip_id': record.tripId,
          'type': record.type.index,
          'category': record.category,
          'amount': record.amount,
          'time': record.time.toIso8601String(),
          'remark': record.remark,
          'pay_method': record.payMethod,
          'share_ratio': record.shareRatio,
          'share_amount': record.shareAmount,
          'detail': record.detail,
        }).select().single();
        final newId = response['id'] as int;
        final updatedRecord = record.copyWith(id: newId);
        // 可选：同步本地存储id
        if (await isWeb) {
          final box = _hiveBox!;
          box.put('record_\u0000$newId', updatedRecord.toMap());
        } else {
          final database = await db;
          await database.insert('records', updatedRecord.toMap());
        }
      }
    }
    // 4. 云端有本地没有的，下载
    for (final e in cloudRecords.values) {
      if (!localRecords.any((r) => r.id == e['id'])) {
        final record = Record(
          id: e['id'],
          tripId: e['trip_id'],
          type: RecordType.values[e['type']],
          category: e['category'],
          amount: (e['amount'] as num).toDouble(),
          time: DateTime.parse(e['time']),
          remark: e['remark'],
          payMethod: e['pay_method'],
          shareRatio: e['share_ratio'] != null ? (e['share_ratio'] as num).toDouble() : null,
          shareAmount: e['share_amount'] != null ? (e['share_amount'] as num).toDouble() : null,
          detail: e['detail'],
        );
        if (await isWeb) {
          final box = _hiveBox!;
          box.put('record_\u0000${record.id}', record.toMap());
        } else {
          final database = await db;
          await database.insert('records', record.toMap());
        }
      }
    }
    // 5. 冲突检测
    for (final record in localRecords) {
      final cloud = cloudRecords[record.id];
      if (cloud != null) {
        if (record.amount != (cloud['amount'] as num).toDouble() ||
            record.category != cloud['category']) {
          // 冲突，提示或自动合并
          // TODO: 可弹窗提示用户选择以本地/云端为准，或自动合并
        }
      }
    }
  }

  /// 对比本地与云端 trips 并提示用户是否合并
  Future<void> compareAndPromptMergeTrips(BuildContext context) async {
    final supabase = Supabase.instance.client;
    // 拉取云端 trips
    final cloudTripsRaw = await supabase.from('trips').select();
    final cloudTrips = <int, Map<String, dynamic>>{};
    for (final e in cloudTripsRaw) {
      cloudTrips[e['id'] as int] = e;
    }
    // 拉取本地 trips
    final localTrips = await getAllTrips();
    // 检查不一致
    final List<String> diffList = [];
    for (final trip in localTrips) {
      final cloud = cloudTrips[trip.id];
      if (cloud == null) {
        diffList.add('本地新增行程：${trip.groupCode}');
      } else {
        if (trip.groupCode != cloud['group_code'] ||
            trip.date.toIso8601String() != cloud['date'] ||
            trip.peopleCount != cloud['people_count']) {
          diffList.add('行程ID:${trip.id} 本地与云端内容不同');
        }
      }
    }
    for (final e in cloudTrips.values) {
      if (!localTrips.any((t) => t.id == e['id'])) {
        diffList.add('云端新增行程：${e['group_code']}');
      }
    }
    if (diffList.isNotEmpty) {
      // 弹窗提示用户
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('本地与云端行程数据不一致'),
          content: SizedBox(
            width: 300,
            child: ListView(
              shrinkWrap: true,
              children: diffList.map((e) => Text(e)).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                // 用户同意合并，自动调用同步
                await syncTrips();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已自动合并数据')));
              },
              child: const Text('合并数据'),
            ),
          ],
        ),
      );
    }
  }

  /// 对比本地与云端 records 并提示用户是否合并
  Future<void> compareAndPromptMergeRecords(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final cloudRecordsRaw = await supabase.from('records').select();
    final cloudRecords = <int, Map<String, dynamic>>{};
    for (final e in cloudRecordsRaw) {
      cloudRecords[e['id'] as int] = e;
    }
    final localTrips = await getAllTrips();
    final localRecords = <Record>[];
    for (final trip in localTrips) {
      localRecords.addAll(await getRecordsByTrip(trip.id!));
    }
    final List<String> diffList = [];
    for (final record in localRecords) {
      final cloud = cloudRecords[record.id];
      if (cloud == null) {
        diffList.add('本地新增收支：${record.category} 金额${record.amount}');
      } else {
        if (record.amount != (cloud['amount'] as num).toDouble() ||
            record.category != cloud['category']) {
          diffList.add('收支ID:${record.id} 本地与云端内容不同');
        }
      }
    }
    for (final e in cloudRecords.values) {
      if (!localRecords.any((r) => r.id == e['id'])) {
        diffList.add('云端新增收支：${e['category']} 金额${e['amount']}');
      }
    }
    if (diffList.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('本地与云端收支数据不一致'),
          content: SizedBox(
            width: 300,
            child: ListView(
              shrinkWrap: true,
              children: diffList.map((e) => Text(e)).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await syncRecords();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已自动合并数据')));
              },
              child: const Text('合并数据'),
            ),
          ],
        ),
      );
    }
  }

  /// 批量删除 trips，删除前弹窗确认，删除后自动同步
  Future<void> batchDeleteTrips(BuildContext context, List<int> tripIds) async {
    if (tripIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除行程'),
        content: Text('确定要删除选中的 ${tripIds.length} 个行程及其所有收支记录吗？此操作不可恢复！'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('确定删除')),
        ],
      ),
    );
    if (confirm != true) return;
    final supabase = Supabase.instance.client;
    // 先批量删除云端
    await supabase.from('records').delete().inFilter('trip_id', tripIds);
    await supabase.from('trips').delete().inFilter('id', tripIds);
    // 再批量删除本地
    if (await isWeb) {
      final box = _hiveBox!;
      for (final id in tripIds) {
        box.delete('trip_\u0000$id');
        // 同时删除所有相关record
        final recordKeys = box.keys.where((k) => k.toString().startsWith('record_'));
        for (final k in recordKeys) {
          final v = box.get(k);
          if (v is Map && v['tripId'] == id) box.delete(k);
        }
      }
    } else {
      final database = await db;
      for (final id in tripIds) {
        await database.delete('records', where: 'tripId = ?', whereArgs: [id]);
        await database.delete('trips', where: 'id = ?', whereArgs: [id]);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('批量删除完成，已同步云端')));
  }

  /// 批量删除 records，删除前弹窗确认，删除后自动同步
  Future<void> batchDeleteRecords(BuildContext context, List<int> recordIds) async {
    if (recordIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除收支'),
        content: Text('确定要删除选中的 ${recordIds.length} 条收支记录吗？此操作不可恢复！'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('确定删除')),
        ],
      ),
    );
    if (confirm != true) return;
    final supabase = Supabase.instance.client;
    await supabase.from('records').delete().inFilter('id', recordIds);
    if (await isWeb) {
      final box = _hiveBox!;
      for (final id in recordIds) {
        box.delete('record_\u0000$id');
      }
    } else {
      final database = await db;
      for (final id in recordIds) {
        await database.delete('records', where: 'id = ?', whereArgs: [id]);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('批量删除完成，已同步云端')));
  }

  Future<Database> get db async {
    if (kIsWeb) throw UnimplementedError('sqflite不支持Web端');
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }
}
