import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../models/record.dart';
import '../providers/record_provider.dart';
import '../utils/csv_exporter.dart';
import 'package:flutter/services.dart';
import 'expense_tab_page.dart';
import 'income_tab_page.dart';

class TripDetailPage extends StatefulWidget {
  final Trip trip;
  const TripDetailPage({super.key, required this.trip});

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RecordProvider>(context, listen: false).loadRecords(widget.trip.id!);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final provider = Provider.of<RecordProvider>(context, listen: false);
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 && provider.hasMore && !provider.isLoading) {
      provider.loadMoreRecords(widget.trip.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip.groupCode),
        actions: [
          TextButton(
            child: const Text('导出CSV', style: TextStyle(color: Color(0xFFD84315), fontWeight: FontWeight.bold)),
            onPressed: () async {
              final recordProvider = Provider.of<RecordProvider>(context, listen: false);
              if (recordProvider.records.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无收支数据可导出')));
                return;
              }
              try {
                final path = await CsvExporter.exportTripRecords(widget.trip, recordProvider.records);
                await Clipboard.setData(ClipboardData(text: path));
                // 复制路径到剪贴板，便于用户查找
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('导出成功'),
                      content: Text('文件已保存到：\n$path\n(路径已复制，可用文件管理器打开)'),
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
      body: Consumer<RecordProvider>(
        builder: (context, recordProvider, _) {
          final records = recordProvider.records;
          double totalIncome = records.where((r) => r.type == RecordType.income).fold(0, (sum, r) => sum + r.amount);
          double totalExpense = records.where((r) => r.type == RecordType.expense).fold(0, (sum, r) => sum + r.amount);
          double net = totalIncome - totalExpense;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('总收入：¥${totalIncome.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 18, color: Colors.green[700], fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('总支出：¥${totalExpense.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 18, color: Colors.red[700], fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('净利润：¥${net.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 18, color: net >= 0 ? Colors.amber[800] : Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => await Provider.of<RecordProvider>(context, listen: false).loadRecords(widget.trip.id!),
                  child: records.isEmpty && !recordProvider.isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 60, color: Colors.teal[200]),
                              const SizedBox(height: 12),
                              Text('暂无收支记录', style: TextStyle(color: Colors.teal[400], fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: records.length + 1,
                          itemBuilder: (context, index) {
                            if (index == records.length) {
                              if (recordProvider.isLoading) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              } else if (!recordProvider.hasMore) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(child: Text('没有更多收支记录了', style: TextStyle(color: Colors.grey))),
                                );
                              } else {
                                return const SizedBox.shrink();
                              }
                            }
                            final r = records[index];
                            return Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                leading: CircleAvatar(
                                  backgroundColor: r.type == RecordType.expense ? Colors.red[50] : Colors.green[50],
                                  child: Icon(r.type == RecordType.expense ? Icons.remove_circle : Icons.add_circle, color: r.type == RecordType.expense ? Colors.red : Colors.green),
                                ),
                                title: Text('${r.category}  ¥${r.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                subtitle: Text('${r.time.year}-${r.time.month.toString().padLeft(2, '0')}-${r.time.day.toString().padLeft(2, '0')}  ${r.remark ?? ''}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      tooltip: '编辑',
                                      onPressed: () async {
                                        await showDialog(
                                          context: context,
                                          builder: (_) => _EditRecordDialog(record: r, trip: widget.trip),
                                        );
                                        // 编辑后刷新
                                        await recordProvider.loadRecords(widget.trip.id!);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      onPressed: () async {
                                        await recordProvider.deleteRecord(r.id!, r.tripId);
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: Text(r.type == RecordType.expense ? '支出明细' : '收入明细'),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _detailRow('分类', r.category),
                                            _detailRow('金额', '¥${r.amount.toStringAsFixed(2)}'),
                                            _detailRow('类型', r.type == RecordType.expense ? '支出' : '收入'),
                                            _detailRow('时间', '${r.time.year}-${r.time.month.toString().padLeft(2, '0')}-${r.time.day.toString().padLeft(2, '0')}'),
                                            if (r.remark != null && r.remark!.isNotEmpty) _detailRow('备注', r.remark!),
                                            if (r.payMethod != null && r.payMethod!.isNotEmpty) _detailRow('支付方式', r.payMethod!),
                                            if (r.shareRatio != null) _detailRow('分成比例', '${r.shareRatio!.toStringAsFixed(2)}%'),
                                            if (r.shareAmount != null) _detailRow('分成金额', '¥${r.shareAmount!.toStringAsFixed(2)}'),
                                            if (r.detail != null && r.detail!.isNotEmpty) _detailRow('明细', r.detail!),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: const Text('关闭'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ),
              // 移除底部门票明细统计
              // Padding(
              //   padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4),
              //   child: _ticketStats(records),
              // ),
            ],
          );
        },
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _statCard(String label, double value, Color color) {
    return Card(
      color: color.withOpacity(0.12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text('¥${value.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: 'addExpense',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider<RecordProvider>.value(
                  value: Provider.of<RecordProvider>(context, listen: false),
                  child: ExpenseTabPage(trip: widget.trip),
                ),
              ),
            );
          },
          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 28),
          label: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('支出', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor: Colors.white,
          foregroundColor: Colors.red,
          elevation: 4,
        ),
        const SizedBox(width: 14),
        FloatingActionButton.extended(
          heroTag: 'addIncome',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider<RecordProvider>.value(
                  value: Provider.of<RecordProvider>(context, listen: false),
                  child: IncomeTabPage(trip: widget.trip),
                ),
              ),
            );
          },
          icon: const Icon(Icons.add_circle, color: Colors.green, size: 28),
          label: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('收入', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor: Colors.white,
          foregroundColor: Colors.green,
          elevation: 4,
        ),
      ],
    );
  }

  void _showAddRecordDialog(BuildContext context, RecordType type) {
    if (type == RecordType.income) {
      showDialog(
        context: context,
        builder: (ctx) {
          final _formKey = GlobalKey<FormState>();
          final amountController = TextEditingController();
          final remarkController = TextEditingController();
          final payMethodController = TextEditingController();
          DateTime selectedTime = DateTime.now();
          return AlertDialog(
            title: const Text('添加收入'),
            content: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: amountController,
                          decoration: const InputDecoration(labelText: '收入金额*'),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => v == null || double.tryParse(v) == null ? '请输入有效金额' : null,
                        ),
                        Row(
                          children: [
                            const Text('时间：'),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedTime,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) setState(() => selectedTime = picked);
                              },
                              child: Text('${selectedTime.year}-${selectedTime.month.toString().padLeft(2, '0')}-${selectedTime.day.toString().padLeft(2, '0')}'),
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: remarkController,
                          decoration: const InputDecoration(labelText: '备注'),
                        ),
                        TextFormField(
                          controller: payMethodController,
                          decoration: const InputDecoration(labelText: '支付方式'),
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
                    final record = Record(
                      tripId: widget.trip.id!,
                      type: RecordType.income,
                      category: '收入',
                      amount: double.parse(amountController.text),
                      time: selectedTime,
                      remark: remarkController.text.trim().isEmpty ? null : remarkController.text.trim(),
                      payMethod: payMethodController.text.trim().isEmpty ? null : payMethodController.text.trim(),
                    );
                    final provider = Provider.of<RecordProvider>(context, listen: false);
                    await provider.addRecord(record);
                    await provider.loadRecords(widget.trip.id!);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
      return;
    }
    // 支出改为页面跳转
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<RecordProvider>.value(
          value: Provider.of<RecordProvider>(context, listen: false),
          child: ExpenseTabPage(trip: widget.trip),
        ),
      ),
    );
  }

  IconData _iconFromName(String name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant;
      case 'confirmation_number':
        return Icons.confirmation_number;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'hotel':
        return Icons.hotel;
      case 'miscellaneous_services':
        return Icons.miscellaneous_services;
      case 'local_mall':
        return Icons.local_mall;
      case 'attach_money':
        return Icons.attach_money;
      case 'store':
        return Icons.store;
      case 'badge':
        return Icons.badge;
      case 'volunteer_activism':
        return Icons.volunteer_activism;
      default:
        return Icons.category;
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label：', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // 门票tab栏人数*金额统计
  Widget _ticketStats(List<Record> records) {
    final ticketRecords = records.where((r) => r.type == RecordType.expense && r.category == '门票').toList();
    int discountCount = 0, halfCount = 0, fullCount = 0;
    double discountPrice = 0, halfPrice = 0, fullPrice = 0;
    double discountTotal = 0, halfTotal = 0, fullTotal = 0;
    for (final r in ticketRecords) {
      // 明细格式: 景区:xxx 打折票X/XX 半价票X/XX 全价票X/XX
      final detail = r.detail ?? '';
      final reg = RegExp(r'打折票(\d+)[人|/]([\d.]+)');
      final regHalf = RegExp(r'半价票(\d+)[人|/]([\d.]+)');
      final regFull = RegExp(r'全价票(\d+)[人|/]([\d.]+)');
      final m = reg.firstMatch(detail);
      final m2 = regHalf.firstMatch(detail);
      final m3 = regFull.firstMatch(detail);
      if (m != null) {
        discountCount += int.tryParse(m.group(1) ?? '0') ?? 0;
        discountPrice = double.tryParse(m.group(2) ?? '0') ?? 0;
        discountTotal += (int.tryParse(m.group(1) ?? '0') ?? 0) * (double.tryParse(m.group(2) ?? '0') ?? 0);
      }
      if (m2 != null) {
        halfCount += int.tryParse(m2.group(1) ?? '0') ?? 0;
        halfPrice = double.tryParse(m2.group(2) ?? '0') ?? 0;
        halfTotal += (int.tryParse(m2.group(1) ?? '0') ?? 0) * (double.tryParse(m2.group(2) ?? '0') ?? 0);
      }
      if (m3 != null) {
        fullCount += int.tryParse(m3.group(1) ?? '0') ?? 0;
        fullPrice = double.tryParse(m3.group(2) ?? '0') ?? 0;
        fullTotal += (int.tryParse(m3.group(1) ?? '0') ?? 0) * (double.tryParse(m3.group(2) ?? '0') ?? 0);
      }
    }
    final total = discountTotal + halfTotal + fullTotal;
    if (discountCount + halfCount + fullCount == 0) return const SizedBox();
    return Card(
      color: Colors.orange[50],
      elevation: 0,
      margin: const EdgeInsets.only(top: 2, bottom: 2),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('门票明细（人数×单价=小计）', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            Row(
              children: [
                if (discountCount > 0) Text('打折票 $discountCount×${discountPrice.toStringAsFixed(2)}=${discountTotal.toStringAsFixed(2)}  '),
                if (halfCount > 0) Text('半价票 $halfCount×${halfPrice.toStringAsFixed(2)}=${halfTotal.toStringAsFixed(2)}  '),
                if (fullCount > 0) Text('全价票 $fullCount×${fullPrice.toStringAsFixed(2)}=${fullTotal.toStringAsFixed(2)}'),
              ],
            ),
            Text('门票合计：¥${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ========== 编辑弹窗 ========== //
class _EditRecordDialog extends StatefulWidget {
  final Record record;
  final Trip trip;
  const _EditRecordDialog({required this.record, required this.trip});
  @override
  State<_EditRecordDialog> createState() => _EditRecordDialogState();
}

class _EditRecordDialogState extends State<_EditRecordDialog> {
  late TextEditingController amountController;
  late TextEditingController remarkController;
  late TextEditingController payMethodController;
  late TextEditingController detailController;
  late DateTime selectedTime;
  late String category;
  late String type;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(text: widget.record.amount.toString());
    remarkController = TextEditingController(text: widget.record.remark ?? '');
    payMethodController = TextEditingController(text: widget.record.payMethod ?? '');
    detailController = TextEditingController(text: widget.record.detail ?? '');
    selectedTime = widget.record.time;
    category = widget.record.category;
    type = widget.record.type == RecordType.expense ? '支出' : '收入';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('编辑${type}记录'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: amountController,
              decoration: const InputDecoration(labelText: '金额*'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            Row(
              children: [
                const Text('时间：'),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedTime,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => selectedTime = picked);
                  },
                  child: Text('${selectedTime.year}-${selectedTime.month.toString().padLeft(2, '0')}-${selectedTime.day.toString().padLeft(2, '0')}'),
                ),
              ],
            ),
            TextFormField(
              controller: remarkController,
              decoration: const InputDecoration(labelText: '备注'),
            ),
            TextFormField(
              controller: payMethodController,
              decoration: const InputDecoration(labelText: '支付方式'),
            ),
            TextFormField(
              controller: detailController,
              decoration: const InputDecoration(labelText: '明细'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () async {
            final amount = double.tryParse(amountController.text) ?? 0;
            final updated = widget.record.copyWith(
              amount: amount,
              time: selectedTime,
              remark: remarkController.text.trim().isEmpty ? null : remarkController.text.trim(),
              payMethod: payMethodController.text.trim().isEmpty ? null : payMethodController.text.trim(),
              detail: detailController.text.trim().isEmpty ? null : detailController.text.trim(),
            );
            await Provider.of<RecordProvider>(context, listen: false).updateRecord(updated);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
