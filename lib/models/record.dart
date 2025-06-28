// 收支记录模型
enum RecordType { expense, income }

class Record {
  final int? id;
  final int tripId; // 所属行程id
  final RecordType type; // 支出/收入
  final String category; // 分类（如餐费、门票、车销等）
  final double amount; // 金额
  final DateTime time; // 记录时间
  final String? remark; // 备注
  final String? payMethod; // 支付方式
  final double? shareRatio; // 分成比例（如有）
  final double? shareAmount; // 分成金额（如有）
  final String? detail; // 额外明细（如商品明细、票型等）

  Record({
    this.id,
    required this.tripId,
    required this.type,
    required this.category,
    required this.amount,
    required this.time,
    this.remark,
    this.payMethod,
    this.shareRatio,
    this.shareAmount,
    this.detail,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'type': type.index,
      'category': category,
      'amount': amount,
      'time': time.toIso8601String(),
      'remark': remark,
      'payMethod': payMethod,
      'shareRatio': shareRatio,
      'shareAmount': shareAmount,
      'detail': detail,
    };
  }

  factory Record.fromMap(Map<String, dynamic> map) {
    return Record(
      id: map['id'] as int?,
      tripId: map['tripId'] as int,
      type: RecordType.values[map['type'] as int],
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      time: DateTime.parse(map['time'] as String),
      remark: map['remark'] as String?,
      payMethod: map['payMethod'] as String?,
      shareRatio: map['shareRatio'] != null ? (map['shareRatio'] as num).toDouble() : null,
      shareAmount: map['shareAmount'] != null ? (map['shareAmount'] as num).toDouble() : null,
      detail: map['detail'] as String?,
    );
  }

  Record copyWith({
    int? id,
    int? tripId,
    RecordType? type,
    String? category,
    double? amount,
    DateTime? time,
    String? remark,
    String? payMethod,
    double? shareRatio,
    double? shareAmount,
    String? detail,
  }) {
    return Record(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      type: type ?? this.type,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      time: time ?? this.time,
      remark: remark ?? this.remark,
      payMethod: payMethod ?? this.payMethod,
      shareRatio: shareRatio ?? this.shareRatio,
      shareAmount: shareAmount ?? this.shareAmount,
      detail: detail ?? this.detail,
    );
  }
}
