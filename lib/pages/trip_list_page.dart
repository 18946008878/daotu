import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../models/trip.dart';
import 'trip_detail_page.dart';
import '../db/db_helper.dart';
import '../utils/csv_exporter_all.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/csv_importer.dart';
import '../models/record.dart';
import '../providers/record_provider.dart';

class TripListPage extends StatefulWidget {
  const TripListPage({super.key});

  @override
  State<TripListPage> createState() => _TripListPageState();
}

class _TripListPageState extends State<TripListPage> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TripProvider>(context, listen: false).loadTrips();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final provider = Provider.of<TripProvider>(context, listen: false);
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 && provider.hasMore && !provider.isLoading) {
      provider.loadMoreTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = Provider.of<TripProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('行程列表'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: '导入',
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
              if (result != null && result.files.single.path != null) {
                final path = result.files.single.path!;
                try {
                  final count = await CsvImporter.importAllTrips(path);
                  if (context.mounted) {
                    await Provider.of<TripProvider>(context, listen: false).loadTrips();
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('导入完成'),
                        content: Text('成功导入$count条收支记录'),
                        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('确定'))],
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
                }
              }
            },
          ),
          TextButton(
            child: const Text('全部导出', style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
            onPressed: () async {
              final tripProvider = Provider.of<TripProvider>(context, listen: false);
              final trips = tripProvider.trips;
              if (trips.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无行程可导出')));
                return;
              }
              final Map<int, List<Record>> tripRecords = {};
              for (final trip in trips) {
                tripRecords[trip.id!] = await DBHelper().getRecordsByTrip(trip.id!);
              }
              try {
                final path = await CsvExporterAll.exportAllTrips(trips, tripRecords);
                await Clipboard.setData(ClipboardData(text: path));
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('导出成功'),
                      content: Text('全部行程收支已导出：\n$path\n(路径已复制，可用文件管理器打开)'),
                      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('确定'))],
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFe0f7fa), Color(0xFFffffff)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async => await tripProvider.loadTrips(),
          child: tripProvider.trips.isEmpty && !tripProvider.isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.airplanemode_active, size: 64, color: Colors.teal[200]),
                      const SizedBox(height: 16),
                      Text('暂无行程，点击右下角添加', style: TextStyle(color: Colors.teal[400], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: tripProvider.trips.length + 1,
                  itemBuilder: (context, index) {
                    if (index == tripProvider.trips.length) {
                      if (tripProvider.isLoading) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      } else if (!tripProvider.hasMore) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('没有更多行程了', style: TextStyle(color: Colors.grey))),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }
                    final trip = tripProvider.trips[index];
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal[50],
                          child: Icon(Icons.event_note, color: Colors.teal[400]),
                        ),
                        title: Text(trip.groupCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text(
                          trip.startDate != null && trip.endDate != null
                              ? '${trip.startDate!.year}-${trip.startDate!.month.toString().padLeft(2, '0')}-${trip.startDate!.day.toString().padLeft(2, '0')} ~ ${trip.endDate!.year}-${trip.endDate!.month.toString().padLeft(2, '0')}-${trip.endDate!.day.toString().padLeft(2, '0')}  人数: ${trip.peopleCount ?? '-'}'
                              : '${trip.date.year}-${trip.date.month.toString().padLeft(2, '0')}-${trip.date.day.toString().padLeft(2, '0')}  人数: ${trip.peopleCount ?? '-'}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () async {
                            await tripProvider.deleteTrip(trip.id!);
                          },
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider<RecordProvider>(
                                create: (_) => RecordProvider()..loadRecords(trip.id!),
                                child: TripDetailPage(trip: trip),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTripDialog(context),
        icon: const Icon(Icons.add, size: 28),
        label: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text('新建行程', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
        elevation: 4,
      ),
    );
  }

  void _showAddTripDialog(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final groupCodeController = TextEditingController();
    final peopleCountController = TextEditingController();
    final remarkController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('新建行程'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: groupCodeController,
                        decoration: const InputDecoration(labelText: '团号/名称*'),
                        validator: (v) => v == null || v.trim().isEmpty ? '必填' : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('开始日期*：'),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => startDate = picked);
                                if (endDate.isBefore(startDate)) {
                                  setState(() => endDate = startDate);
                                }
                              }
                            },
                            child: Text('${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}'),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('结束日期*：'),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => endDate = picked);
                              }
                            },
                            child: Text('${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}'),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: peopleCountController,
                        decoration: const InputDecoration(labelText: '人数'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: remarkController,
                        decoration: const InputDecoration(labelText: '备注'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  // TODO: Trip模型和数据库需支持startDate/endDate
                  final trip = Trip(
                    groupCode: groupCodeController.text.trim(),
                    startDate: startDate,
                    endDate: endDate,
                    date: startDate, // 兼容旧字段
                    peopleCount: int.tryParse(peopleCountController.text),
                    remark: remarkController.text.trim().isEmpty ? null : remarkController.text.trim(),
                  );
                  await Provider.of<TripProvider>(context, listen: false).addTrip(trip);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }
}
