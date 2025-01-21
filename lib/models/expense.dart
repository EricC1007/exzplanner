// ignore_for_file: unnecessary_this

class Expense {
  final String id; 
  final String name;
  final double amount;
  final DateTime date;
  final String category;

  Expense({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
    };
  }

  factory Expense.fromFirestore(Map<String, dynamic> data, String id) {
    return Expense(
      id: id, 
      name: data['name'],
      amount: data['amount'],
      date: DateTime.parse(data['date']),
      category: data['category'],
    );
  }

  Expense copyWith({String? name, double? amount, DateTime? date, String? category}) {
    return Expense(
      id: this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
    );
  }

  @override
  String toString() {
    return 'Expense{id: $id, name: $name, amount: $amount, date: $date, category: $category}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Expense && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}