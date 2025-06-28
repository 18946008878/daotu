import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../models/record.dart';
import 'package:provider/provider.dart';
import '../providers/record_provider.dart';

class ExpenseTabPage extends StatefulWidget {
  final Trip trip;
  const ExpenseTabPage({super.key, required this.trip});

  @override
  State<ExpenseTabPage> createState() => _ExpenseTabPageState();
}

class _ExpenseTabPageState extends State<ExpenseTabPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 3个Tab
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
            const Icon(Icons.money_off, color: Colors.redAccent, size: 22),
            SizedBox(width: 6),
            const Text('添加支出', style: TextStyle(fontSize: 18)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            alignment: Alignment.center,
            child: TabBar(
              controller: _tabController,
              isScrollable: false, // 改为平均分配宽度
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              labelPadding: EdgeInsets.zero,
              tabs: const [
                Tab(icon: Icon(Icons.restaurant, color: Colors.orange, size: 18), text: '餐费'),
                Tab(icon: Icon(Icons.confirmation_number, color: Colors.blue, size: 18), text: '门票'),
                Tab(icon: Icon(Icons.hotel, color: Colors.teal, size: 18), text: '住宿'),
              ],
              indicatorSize: TabBarIndicatorSize.tab, // 平均分配
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MealExpenseForm(trip: widget.trip),
          _TicketExpenseForm(trip: widget.trip),
          _StayExpenseForm(trip: widget.trip),
        ],
      ),
    );
  }
}

class _MealExpenseForm extends StatefulWidget {
  final Trip trip;
  const _MealExpenseForm({required this.trip});
  @override
  State<_MealExpenseForm> createState() => _MealExpenseFormState();
}

class _MealExpenseFormState extends State<_MealExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController restaurantController = TextEditingController();
  String mealType = '早餐';
  DateTime mealDate = DateTime.now();
  final TextEditingController priceController = TextEditingController(); // 单价
  final TextEditingController peopleCountController = TextEditingController();
  String mealPayMethod = '现金';
  final TextEditingController mealRemarkController = TextEditingController();
  double totalAmount = 0;

  void _calcTotal() {
    final price = double.tryParse(priceController.text) ?? 0;
    final count = int.tryParse(peopleCountController.text) ?? 0;
    setState(() => totalAmount = price * count);
  }

  @override
  Widget build(BuildContext context) {
    priceController.removeListener(_calcTotal);
    peopleCountController.removeListener(_calcTotal);
    priceController.addListener(_calcTotal);
    peopleCountController.addListener(_calcTotal);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: restaurantController,
              decoration: const InputDecoration(labelText: '餐厅名称*'),
              validator: (v) => v == null || v.trim().isEmpty ? '必填' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('类别：'),
                ...['早餐', '午餐', '晚餐'].map((type) => Row(
                  children: [
                    Radio<String>(
                      value: type,
                      groupValue: mealType,
                      onChanged: (v) => setState(() => mealType = v!),
                    ),
                    Text(type),
                  ],
                )),
              ],
            ),
            Row(
              children: [
                const Text('用餐日期：'),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: mealDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => mealDate = picked);
                  },
                  child: Text('${mealDate.year}-${mealDate.month.toString().padLeft(2, '0')}-${mealDate.day.toString().padLeft(2, '0')}'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: '单价*'),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v == null || double.tryParse(v) == null ? '请输入有效单价' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: peopleCountController,
                    decoration: const InputDecoration(labelText: '人数*'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || int.tryParse(v) == null ? '请输入有效人数' : null,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text('合计金额：¥${totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            Row(
              children: [
                const Text('结算方式：'),
                ...['现金', '签单'].map((m) => Row(
                  children: [
                    Radio<String>(
                      value: m,
                      groupValue: mealPayMethod,
                      onChanged: (v) => setState(() => mealPayMethod = v!),
                    ),
                    Text(m),
                  ],
                )),
              ],
            ),
            TextFormField(
              controller: mealRemarkController,
              decoration: const InputDecoration(labelText: '备注'),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final record = Record(
                        tripId: widget.trip.id!,
                        type: RecordType.expense,
                        category: mealType,
                        amount: totalAmount,
                        time: mealDate,
                        remark: mealRemarkController.text.trim().isEmpty ? null : mealRemarkController.text.trim(),
                        payMethod: mealPayMethod,
                        detail: '餐厅:${restaurantController.text.trim()} 单价:${priceController.text} 人数:${peopleCountController.text}',
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

class _TicketExpenseForm extends StatefulWidget {
  final Trip trip;
  const _TicketExpenseForm({required this.trip});
  @override
  State<_TicketExpenseForm> createState() => _TicketExpenseFormState();
}

class _TicketExpenseFormState extends State<_TicketExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController scenicController = TextEditingController();
  DateTime ticketDate = DateTime.now();
  final TextEditingController discountCountController = TextEditingController();
  final TextEditingController discountAmountController = TextEditingController();
  final TextEditingController halfCountController = TextEditingController();
  final TextEditingController halfAmountController = TextEditingController();
  final TextEditingController fullCountController = TextEditingController();
  final TextEditingController fullAmountController = TextEditingController();
  String ticketPayMethod = '现金';
  final TextEditingController ticketRemarkController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    int discountCount = int.tryParse(discountCountController.text) ?? 0;
    double discountPrice = double.tryParse(discountAmountController.text) ?? 0;
    int halfCount = int.tryParse(halfCountController.text) ?? 0;
    double halfPrice = double.tryParse(halfAmountController.text) ?? 0;
    int fullCount = int.tryParse(fullCountController.text) ?? 0;
    double fullPrice = double.tryParse(fullAmountController.text) ?? 0;
    double discountTotal = discountCount * discountPrice;
    double halfTotal = halfCount * halfPrice;
    double fullTotal = fullCount * fullPrice;
    double ticketTotal = discountTotal + halfTotal + fullTotal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: scenicController,
              decoration: const InputDecoration(labelText: '景区名称*'),
              validator: (v) => v == null || v.trim().isEmpty ? '必填' : null,
            ),
            Row(
              children: [
                const Text('日期：'),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: ticketDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => ticketDate = picked);
                  },
                  child: Text('${ticketDate.year}-${ticketDate.month.toString().padLeft(2, '0')}-${ticketDate.day.toString().padLeft(2, '0')}'),
                ),
              ],
            ),
            Row(
              children: [
                const Text('打折票'),
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    controller: discountCountController,
                    decoration: const InputDecoration(hintText: '人数'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: discountAmountController,
                    decoration: const InputDecoration(hintText: '单价'),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Text('= ${discountCount * discountPrice}', style: const TextStyle(color: Colors.orange)),
              ],
            ),
            Row(
              children: [
                const Text('半价票'),
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    controller: halfCountController,
                    decoration: const InputDecoration(hintText: '人数'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: halfAmountController,
                    decoration: const InputDecoration(hintText: '单价'),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Text('= ${halfCount * halfPrice}', style: const TextStyle(color: Colors.orange)),
              ],
            ),
            Row(
              children: [
                const Text('全价票'),
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    controller: fullCountController,
                    decoration: const InputDecoration(hintText: '人数'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: fullAmountController,
                    decoration: const InputDecoration(hintText: '单价'),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Text('= ${fullCount * fullPrice}', style: const TextStyle(color: Colors.orange)),
              ],
            ),
            // 结算方式（门票）
            Row(
              children: [
                const Text('结算方式：'),
                ...['现金', '签单'].map((m) => Row(
                  children: [
                    Radio<String>(
                      value: m,
                      groupValue: ticketPayMethod,
                      onChanged: (v) => setState(() => ticketPayMethod = v!),
                    ),
                    Text(m),
                  ],
                )),
              ],
            ),
            TextFormField(
              controller: ticketRemarkController,
              decoration: const InputDecoration(labelText: '备注'),
            ),
            const SizedBox(height: 10),
            Text('合计金额：¥${ticketTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('明细：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (discountCount > 0) Text('打折票: $discountCount × ${discountPrice.toStringAsFixed(2)} = ¥${discountTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange)),
                  if (halfCount > 0) Text('半价票: $halfCount × ${halfPrice.toStringAsFixed(2)} = ¥${halfTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange)),
                  if (fullCount > 0) Text('全价票: $fullCount × ${fullPrice.toStringAsFixed(2)} = ¥${fullTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final record = Record(
                        tripId: widget.trip.id!,
                        type: RecordType.expense,
                        category: '门票',
                        amount: ticketTotal,
                        time: ticketDate,
                        remark: ticketRemarkController.text.trim().isEmpty ? null : ticketRemarkController.text.trim(),
                        payMethod: ticketPayMethod,
                        detail: '景区:${scenicController.text.trim()} 打折票${discountCountController.text}/${discountAmountController.text} 半价票${halfCountController.text}/${halfAmountController.text} 全价票${fullCountController.text}/${fullAmountController.text}',
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

// 新增住宿表单Tab
class _StayExpenseForm extends StatefulWidget {
  final Trip trip;
  const _StayExpenseForm({required this.trip});
  @override
  State<_StayExpenseForm> createState() => _StayExpenseFormState();
}

class _StayExpenseFormState extends State<_StayExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController hotelController = TextEditingController();
  DateTime stayDate = DateTime.now();
  // 标间
  final TextEditingController standardRoomCountController = TextEditingController();
  final TextEditingController standardRoomPriceController = TextEditingController();
  // 三人间
  final TextEditingController tripleRoomCountController = TextEditingController();
  final TextEditingController tripleRoomPriceController = TextEditingController();
  String stayPayMethod = '现金';
  final TextEditingController stayRemarkController = TextEditingController();
  double totalAmount = 0;

  void _calcTotal() {
    final stdCount = int.tryParse(standardRoomCountController.text) ?? 0;
    final stdPrice = double.tryParse(standardRoomPriceController.text) ?? 0;
    final triCount = int.tryParse(tripleRoomCountController.text) ?? 0;
    final triPrice = double.tryParse(tripleRoomPriceController.text) ?? 0;
    setState(() => totalAmount = stdCount * stdPrice + triCount * triPrice);
  }

  @override
  Widget build(BuildContext context) {
    standardRoomCountController.removeListener(_calcTotal);
    standardRoomPriceController.removeListener(_calcTotal);
    tripleRoomCountController.removeListener(_calcTotal);
    tripleRoomPriceController.removeListener(_calcTotal);
    standardRoomCountController.addListener(_calcTotal);
    standardRoomPriceController.addListener(_calcTotal);
    tripleRoomCountController.addListener(_calcTotal);
    tripleRoomPriceController.addListener(_calcTotal);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: hotelController,
              decoration: const InputDecoration(labelText: '酒店名称*'),
              validator: (v) => v == null || v.trim().isEmpty ? '必填' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('住宿日期：'),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: stayDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => stayDate = picked);
                  },
                  child: Text('${stayDate.year}-${stayDate.month.toString().padLeft(2, '0')}-${stayDate.day.toString().padLeft(2, '0')}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('标间'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: standardRoomCountController,
                    decoration: const InputDecoration(labelText: '数量*'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || int.tryParse(v) == null ? '请输入有效数量' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: standardRoomPriceController,
                    decoration: const InputDecoration(labelText: '单价*'),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v == null || double.tryParse(v) == null ? '请输入有效单价' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('三人间'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: tripleRoomCountController,
                    decoration: const InputDecoration(labelText: '数量*'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || int.tryParse(v) == null ? '请输入有效数量' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: tripleRoomPriceController,
                    decoration: const InputDecoration(labelText: '单价*'),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v == null || double.tryParse(v) == null ? '请输入有效单价' : null,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text('合计金额：¥${totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            // 结算方式（住宿）
            Row(
              children: [
                const Text('结算方式：'),
                ...['现金', '签单'].map((m) => Row(
                  children: [
                    Radio<String>(
                      value: m,
                      groupValue: stayPayMethod,
                      onChanged: (v) => setState(() => stayPayMethod = v!),
                    ),
                    Text(m),
                  ],
                )),
              ],
            ),
            TextFormField(
              controller: stayRemarkController,
              decoration: const InputDecoration(labelText: '备注'),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final record = Record(
                        tripId: widget.trip.id!,
                        type: RecordType.expense,
                        category: '住宿',
                        amount: totalAmount,
                        time: stayDate,
                        remark: stayRemarkController.text.trim().isEmpty ? null : stayRemarkController.text.trim(),
                        payMethod: stayPayMethod,
                        detail: '酒店:${hotelController.text.trim()} 标间:${standardRoomCountController.text}×${standardRoomPriceController.text} 三人间:${tripleRoomCountController.text}×${tripleRoomPriceController.text}',
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
