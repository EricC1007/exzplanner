import '../models/expense.dart';

class ExpenseUtils {
  static double getTodayExpenses(List<Expense> expenses) {
    return expenses.where((expense) => expense.date.day == DateTime.now().day).fold(0.0, (sum, expense) => sum + expense.amount);
  }

  static double getMonthlyExpenses(List<Expense> expenses) {
    return expenses.where((expense) => expense.date.month == DateTime.now().month).fold(0.0, (sum, expense) => sum + expense.amount);
  }
}