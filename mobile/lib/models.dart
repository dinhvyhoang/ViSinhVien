class Category {
  final int id;
  final String name;
  final String type;
  final bool isArchived;
  Category.fromJson(Map<String, dynamic> json)
    : id = (json['id'] as num).toInt(),
      name = json['name'] as String,
      type = json['type'] as String,
      isArchived = json['isArchived'] as bool;
}

class FinanceTransaction {
  final int id;
  final int categoryId;
  final String categoryName;
  final String type;
  final int amountVnd;
  final DateTime date;
  final String note;
  FinanceTransaction.fromJson(Map<String, dynamic> json)
    : id = (json['id'] as num).toInt(),
      categoryId = (json['categoryId'] as num).toInt(),
      categoryName = json['categoryName'] as String,
      type = json['type'] as String,
      amountVnd = (json['amountVnd'] as num).toInt(),
      date = DateTime.parse(json['transactionDate'] as String),
      note = json['note'] as String;
}
