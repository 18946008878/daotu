import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../models/record.dart';
import 'package:provider/provider.dart';
import '../providers/record_provider.dart';

class IncomeTabPage extends StatefulWidget {
  final Trip trip;
  const IncomeTabPage({super.key, required this.trip});

  @override
  State<IncomeTabPage> createState() => _IncomeTabPageState();
}

class _IncomeTabPageState extends State<IncomeTabPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.attach_money, color: Colors.green, size: 26),
            SizedBox(width: 8),
            const Text('添加收入'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_cart, color: Colors.blue), text: '车购'),
            Tab(icon: Icon(Icons.assignment_turned_in, color: Colors.orange), text: '自费'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CarPurchaseForm(trip: widget.trip),
          _SelfExpenseForm(trip: widget.trip),
        ],
      ),
    );
  }
}

// 车购Tab表单
class _CarPurchaseForm extends StatefulWidget {
  final Trip trip;
  const _CarPurchaseForm({required this.trip});
  @override
  State<_CarPurchaseForm> createState() => _CarPurchaseFormState();
}

class _CarPurchaseFormState extends State<_CarPurchaseForm> {
  final _formKey = GlobalKey<FormState>();
  DateTime carDate = DateTime.now();
  final TextEditingController buyerController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController remarkController = TextEditingController();
  final TextEditingController tasteAmountController = TextEditingController(); // 新增试吃金额

  // 预定义产品
  final List<String> productList = [
    '蓝莓', '木耳', '松子/仁', '人参/林', '人参/白', '人参/红', '人参/西洋',
    '雪蛤油', '榛蘑', '孢子粉', '牛肉干', '酸奶糖', '巧克力', '俄罗斯糖', '高丽参', '奶制品', '自定义产品'
  ];
  List<_ProductInput> selectedProducts = [
    _ProductInput(name: '蓝莓')
  ];

  double profit = 0.0;
  double netProfit = 0.0;

  @override
  void initState() {
    super.initState();
    tasteAmountController.addListener(_calcProfit);
  }

  @override
  void dispose() {
    tasteAmountController.dispose();
    super.dispose();
  }

  void _addProduct([String? name]) {
    setState(() {
      selectedProducts.add(_ProductInput(name: name ?? '自定义产品'));
    });
  }
  void _removeProduct(int idx) {
    setState(() {
      if (selectedProducts.length > 1) selectedProducts.removeAt(idx);
    });
    _calcProfit();
  }

  void _calcProfit() {
    double totalProfit = 0.0;
    for (final p in selectedProducts) {
      final qty = int.tryParse(p.qtyController.text) ?? 0;
      final cost = double.tryParse(p.costController.text) ?? 0;
      final price = double.tryParse(p.priceController.text) ?? 0;
      totalProfit += qty * (price - cost);
    }
    final taste = double.tryParse(tasteAmountController.text) ?? 0;
    setState(() {
      profit = totalProfit;
      netProfit = totalProfit - taste;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 监听产品输入变化，实时计算利润
    for (final p in selectedProducts) {
      p.qtyController.removeListener(_calcProfit);
      p.costController.removeListener(_calcProfit);
      p.priceController.removeListener(_calcProfit);
      p.qtyController.addListener(_calcProfit);
      p.costController.addListener(_calcProfit);
      p.priceController.addListener(_calcProfit);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('日期：'),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: carDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => carDate = picked);
                  },
                  child: Text('${carDate.year}-${carDate.month.toString().padLeft(2, '0')}-${carDate.day.toString().padLeft(2, '0')}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 产品选择与输入
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedProducts.length,
              itemBuilder: (context, idx) {
                final p = selectedProducts[idx];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: productList.contains(p.name) ? p.name : '自定义产品',
                                items: productList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                onChanged: (v) {
                                  setState(() {
                                    if (v == '自定义产品') {
                                      p.name = '';
                                    } else {
                                      p.name = v ?? '';
                                    }
                                  });
                                },
                                decoration: const InputDecoration(labelText: '产品名称'),
                              ),
                            ),
                            if (selectedProducts.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeProduct(idx),
                              ),
                          ],
                        ),
                        if (p.name == '' || p.name == '自定义产品')
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: TextFormField(
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(labelText: '自定义产品名'),
                              initialValue: p.name == '' ? '' : p.name,
                              onSaved: (v) => p.name = v ?? '',
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: p.qtyController,
                                decoration: const InputDecoration(labelText: '数量'),
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || v.isEmpty ? '必填' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: p.costController,
                                decoration: const InputDecoration(labelText: '底价'),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => v == null || v.isEmpty ? '必填' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: p.priceController,
                                decoration: const InputDecoration(labelText: '销售价'),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => v == null || v.isEmpty ? '必填' : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _addProduct(),
                  icon: const Icon(Icons.add),
                  label: const Text('添加产品'),
                ),
                const SizedBox(width: 16),
                Text('利润：¥${profit.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('减试吃金额：¥${netProfit.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: buyerController,
              decoration: const InputDecoration(labelText: '购物人姓名'),
            ),
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: '电话'),
              keyboardType: TextInputType.phone,
            ),
            TextFormField(
              controller: addressController,
              decoration: const InputDecoration(labelText: '邮寄'),
            ),
            TextFormField(
              controller: remarkController,
              decoration: const InputDecoration(labelText: '备注'),
            ),
            TextFormField(
              controller: tasteAmountController,
              decoration: const InputDecoration(labelText: '试吃总金额'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      // 保存所有产品为一条记录，明细为json字符串
                      final detailList = selectedProducts.map((p) =>
                        '${p.name.isEmpty ? '自定义产品' : p.name} 数量:${p.qtyController.text} 底价:${p.costController.text} 销售价:${p.priceController.text}'
                      ).join('; ');
                      final record = Record(
                        tripId: widget.trip.id!,
                        type: RecordType.income,
                        category: '车购',
                        amount: selectedProducts.fold(0.0, (sum, p) => sum + (int.tryParse(p.qtyController.text) ?? 0) * (double.tryParse(p.priceController.text) ?? 0)),
                        time: carDate,
                        remark: remarkController.text.trim().isEmpty ? null : remarkController.text.trim(),
                        payMethod: null,
                        detail: '购物人:${buyerController.text} 电话:${phoneController.text} 邮寄:${addressController.text} 产品明细: $detailList 利润:${profit.toStringAsFixed(2)} 试吃:${tasteAmountController.text} 实际利润:${netProfit.toStringAsFixed(2)}',
                      );
                      final provider = Provider.of<RecordProvider>(context, listen: false);
                      await provider.addRecord(record);
                      await provider.loadRecords(widget.trip.id!);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductInput {
  String name;
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController costController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  _ProductInput({required this.name});
}

// 自费Tab表单（后续实现）
class _SelfExpenseForm extends StatefulWidget {
  final Trip trip;
  const _SelfExpenseForm({required this.trip});
  @override
  State<_SelfExpenseForm> createState() => _SelfExpenseFormState();
}

class _SelfExpenseFormState extends State<_SelfExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  DateTime expenseDate = DateTime.now();
  final TextEditingController projectController = TextEditingController();
  final TextEditingController incomeController = TextEditingController();
  final TextEditingController expenseController = TextEditingController();
  final TextEditingController remarkController = TextEditingController();
  double profit = 0.0;
  int? editingId;

  void _calcProfit() {
    final income = double.tryParse(incomeController.text) ?? 0;
    final expense = double.tryParse(expenseController.text) ?? 0;
    setState(() => profit = income - expense);
  }

  @override
  void initState() {
    super.initState();
    incomeController.addListener(_calcProfit);
    expenseController.addListener(_calcProfit);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RecordProvider>(context, listen: false).loadRecords(widget.trip.id!);
    });
  }

  @override
  void dispose() {
    incomeController.removeListener(_calcProfit);
    expenseController.removeListener(_calcProfit);
    incomeController.dispose();
    expenseController.dispose();
    projectController.dispose();
    remarkController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      editingId = null;
      expenseDate = DateTime.now();
      projectController.clear();
      incomeController.clear();
      expenseController.clear();
      remarkController.clear();
      profit = 0.0;
    });
  }

  void _fillForm(Record r) {
    setState(() {
      editingId = r.id;
      expenseDate = r.time;
      projectController.text = RegExp(r'd项目:(.*?) ').firstMatch(r.detail ?? '')?.group(1) ?? '';
      incomeController.text = RegExp(r'收入:(.*?) ').firstMatch(r.detail ?? '')?.group(1) ?? '';
      expenseController.text = RegExp(r'支出:(.*?) ').firstMatch(r.detail ?? '')?.group(1) ?? '';
      remarkController.text = r.remark ?? '';
      _calcProfit();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordProvider>(
      builder: (context, provider, _) {
        final selfList = provider.records.where((r) => r.type == RecordType.income && r.category == '自费').toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_turned_in, color: Colors.orange, size: 28),
                  const SizedBox(width: 8),
                  const Text('自费项目录入', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 10),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event, color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 4),
                        const Text('日期：'),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: expenseDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => expenseDate = picked);
                          },
                          child: Text('${expenseDate.year}-${expenseDate.month.toString().padLeft(2, '0')}-${expenseDate.day.toString().padLeft(2, '0')}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: projectController,
                      decoration: const InputDecoration(
                        labelText: '项目名称*',
                        prefixIcon: Icon(Icons.work_outline, color: Colors.deepPurple),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? '必填' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: incomeController,
                      decoration: const InputDecoration(
                        labelText: '收入金额*',
                        prefixIcon: Icon(Icons.trending_up, color: Colors.green),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v == null || double.tryParse(v) == null ? '请输入有效收入金额' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: expenseController,
                      decoration: const InputDecoration(
                        labelText: '支出金额*',
                        prefixIcon: Icon(Icons.trending_down, color: Colors.redAccent),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v == null || double.tryParse(v) == null ? '请输入有效支出金额' : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calculate, color: Colors.teal, size: 20),
                        const SizedBox(width: 4),
                        Text('利润：¥${profit.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: remarkController,
                      decoration: const InputDecoration(
                        labelText: '备注',
                        prefixIcon: Icon(Icons.comment, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (editingId != null)
                          TextButton(
                            onPressed: _resetForm,
                            child: const Text('取消编辑'),
                          ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: Icon(editingId != null ? Icons.save : Icons.add),
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final record = Record(
                                id: editingId,
                                tripId: widget.trip.id!,
                                type: RecordType.income,
                                category: '自费',
                                amount: double.tryParse(incomeController.text) ?? 0,
                                time: expenseDate,
                                remark: remarkController.text.trim().isEmpty ? null : remarkController.text.trim(),
                                payMethod: null,
                                detail: '项目:${projectController.text.trim()} 收入:${incomeController.text} 支出:${expenseController.text} 利润:${profit.toStringAsFixed(2)}',
                              );
                              final provider = Provider.of<RecordProvider>(context, listen: false);
                              if (editingId != null) {
                                await provider.updateRecord(record);
                              } else {
                                await provider.addRecord(record);
                              }
                              await provider.loadRecords(widget.trip.id!);
                              _resetForm();
                            }
                          },
                          label: Text(editingId != null ? '保存编辑' : '保存'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              Row(
                children: [
                  const Icon(Icons.list_alt, color: Colors.orange, size: 22),
                  const SizedBox(width: 6),
                  const Text('自费记录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              ...selfList.isEmpty
                  ? [const Padding(padding: EdgeInsets.all(12), child: Text('暂无自费记录'))]
                  : selfList.map((r) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.monetization_on, color: Colors.orange, size: 28),
                          title: Text(r.detail ?? ''),
                          subtitle: Text('${r.time.year}-${r.time.month.toString().padLeft(2, '0')}-${r.time.day.toString().padLeft(2, '0')}  ${r.remark ?? ''}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _fillForm(r),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () async {
                                  await Provider.of<RecordProvider>(context, listen: false).deleteRecord(r.id!, r.tripId);
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.orange),
                                    SizedBox(width: 6),
                                    const Text('自费明细'),
                                  ],
                                ),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('项目：${RegExp(r'项目:(.*?) ').firstMatch(r.detail ?? '')?.group(1) ?? ''}'),
                                      Text('收入：${RegExp(r'收入:(.*?) ').firstMatch(r.detail ?? '')?.group(1) ?? ''}'),
                                      Text('支出：${RegExp(r'支出:(.*?) ').firstMatch(r.detail ?? '')?.group(1) ?? ''}'),
                                      Text('利润：${RegExp(r'利润:(.*?)').firstMatch(r.detail ?? '')?.group(1) ?? ''}'),
                                      if (r.remark != null && r.remark!.isNotEmpty) Text('备注：${r.remark!}'),
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
                      )),
            ],
          ),
        );
      },
    );
  }
}
