import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TripScheduleList extends StatelessWidget {
  final String tripId;

  const TripScheduleList({required this.tripId, super.key});

  Future<void> _deleteExpense(String expenseId, double cost) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Delete the expense
    await firestore
        .collection('trips')
        .doc(tripId)
        .collection('schedule')
        .doc(expenseId)
        .delete();

    // Update the total expenses for the trip
    await firestore.collection('trips').doc(tripId).update({
      'total_expenses': FieldValue.increment(-cost), // Decrement the total expenses
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .collection('schedule')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No places added yet"));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String placeName = data['place'] ?? 'Unknown Place';
            final double cost = data['cost'] ?? 0.0;

            return ListTile(
              title: Text(placeName),
              subtitle: Text('Cost: RM ${cost.toStringAsFixed(2)}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  await _deleteExpense(doc.id, cost);
                },
              ),
            );
          },
        );
      },
    );
  }
}