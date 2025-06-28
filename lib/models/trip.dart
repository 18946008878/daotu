// 行程数据模型 Trip
class Trip {
  final int? id;
  final String groupCode; // 团号/名称
  final DateTime? startDate; // 行程开始日期
  final DateTime? endDate; // 行程结束日期
  final DateTime date; // 兼容旧字段，默认用startDate
  final int? peopleCount; // 人数，可选
  final String? remark; // 备注，可选

  Trip({
    this.id,
    required this.groupCode,
    this.startDate,
    this.endDate,
    DateTime? date,
    this.peopleCount,
    this.remark,
  }) : date = date ?? startDate ?? DateTime.now();

  // 用于数据库存储的Map转换
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupCode': groupCode,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'date': date.toIso8601String(),
      'peopleCount': peopleCount,
      'remark': remark,
    };
  }

  // 从数据库Map还原对象
  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] as int?,
      groupCode: map['groupCode'] as String,
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
      peopleCount: map['peopleCount'] as int?,
      remark: map['remark'] as String?,
    );
  }

  Trip copyWith({
    int? id,
    String? groupCode,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? date,
    int? peopleCount,
    String? remark,
  }) {
    return Trip(
      id: id ?? this.id,
      groupCode: groupCode ?? this.groupCode,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      date: date ?? this.date,
      peopleCount: peopleCount ?? this.peopleCount,
      remark: remark ?? this.remark,
    );
  }
}
