// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';

class Budget {
  double goal;  // Budget goal amount
  double actual; // Actual expenses

  Budget({required this.goal, this.actual = 0.0});

  // Method to fetch budget
  static Future<Budget> fetchBudget(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('budget')
          .doc('currentBudget')
          .get();

      if (doc.exists) {
        var data = doc.data();
        return Budget(
          goal: data?['goal'] ?? 0.0,
          actual: data?['actual'] ?? 0.0,
        );
      } else {
        return Budget(goal: 0.0);
      }
    } catch (e) {
      print('Error fetching budget: $e');
      return Budget(goal: 0.0);
    }
  }

  // Method to add or update budget
  Future<void> addOrUpdateBudget(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('budget')
          .doc('currentBudget')
          .set({
        'goal': goal,
        'actual': actual,
      });
    } catch (e) {
      print('Error updating budget: $e');
    }
  }
}