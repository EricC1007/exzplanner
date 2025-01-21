import 'package:exzplanner/screens/map_search_screen.dart';
import 'package:exzplanner/screens/trip_schedule_list.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:typed_data'; // For ByteData

class TripDetailScreen extends StatelessWidget {
  final String tripId;

  const TripDetailScreen({required this.tripId, super.key});

  // Helper function to format ISO 8601 date strings
  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) {
      return 'Unknown Date'; // Handle null or empty strings
    }
    try {
      final DateTime date = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  // Function to validate if the flight's departure_time falls within the trip's date range
  bool isDateValid(
      String tripFromDate, String tripToDate, String flightDepartureTime) {
    try {
      final DateTime tripStart = DateTime.parse(tripFromDate);
      final DateTime tripEnd = DateTime.parse(tripToDate);
      final DateTime flightDate = DateTime.parse(flightDepartureTime);

      // Check if the flight's departure_time is within the trip's date range
      return flightDate.isAfter(tripStart.subtract(const Duration(days: 1))) &&
          flightDate.isBefore(tripEnd.add(const Duration(days: 1)));
    } catch (e) {
      // Handle date parsing errors
      return false;
    }
  }

  // Function to fetch combined trip and flight data
  Future<Map<String, dynamic>?> fetchCombinedData(String tripId) async {
    final tripDoc =
        await FirebaseFirestore.instance.collection('trips').doc(tripId).get();

    if (!tripDoc.exists) {
      return null; // Trip not found
    }

    final tripData = tripDoc.data() as Map<String, dynamic>;
    final tripDestination =
        tripData['country'] ?? 'Unknown Destination'; // Default value
    final tripFromDate =
        tripData['from_date'] ?? 'Unknown Date'; // Default value
    final tripToDate = tripData['to_date'] ?? 'Unknown Date'; // Default value

    // Fetch all flights and find the one with a matching destination and valid date
    final flightsSnapshot =
        await FirebaseFirestore.instance.collection('flights').get();

    for (var flightDoc in flightsSnapshot.docs) {
      final flightData = flightDoc.data();
      final flightDestination =
          flightData['to'] ?? 'Unknown Destination'; // Default value
      final flightDepartureTime =
          flightData['departure_time'] ?? 'Unknown Date'; // Default value

      // Check if the flight destination is a substring of the trip destination
      if (tripDestination
          .toLowerCase()
          .contains(flightDestination.toLowerCase())) {
        // Validate the date
        if (isDateValid(tripFromDate, tripToDate, flightDepartureTime)) {
          return {
            'trip': tripData,
            'flight': flightData,
            'flightId': flightDoc.id,
          };
        }
      }
    }

    return null; // No matching flight found
  }

  // Function to fetch transactions from the schedule subcollection under trips
  Future<List<Map<String, dynamic>>> fetchTransactions(String tripId) async {
    try {
      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .collection('schedule') // Fetch from the 'schedule' subcollection
          .get();

      if (transactionsSnapshot.docs.isEmpty) {
        print("No transactions found for trip: $tripId");
      } else {
        print("Transactions found: ${transactionsSnapshot.docs.length}");
      }

      return transactionsSnapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      print("Error fetching transactions: $e");
      return [];
    }
  }

  // Function to fetch flight expenses from the expenses subcollection under flights
  Future<List<Map<String, dynamic>>> fetchFlightExpenses(
      String flightId) async {
    try {
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('flights')
          .doc(flightId)
          .collection('expenses') // Fetch from the 'expenses' subcollection
          .get();

      if (expensesSnapshot.docs.isEmpty) {
        print("No flight expenses found for flight: $flightId");
      } else {
        print("Flight expenses found: ${expensesSnapshot.docs.length}");
      }

      return expensesSnapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      print("Error fetching flight expenses: $e");
      return [];
    }
  }

  // Function to calculate total expenses by category for flight expenses
  Map<String, double> _calculateFlightExpensesByCategory(
      List<Map<String, dynamic>> flightExpenses) {
    final Map<String, double> categoryTotals = {};

    for (var expense in flightExpenses) {
      final String category = expense['category'] ?? 'Other';
      final double amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;

      if (categoryTotals.containsKey(category)) {
        categoryTotals[category] = categoryTotals[category]! + amount;
      } else {
        categoryTotals[category] = amount;
      }
    }

    return categoryTotals;
  }

  // Function to generate combined PDF with automatic pagination
  Future<void> _generateCombinedPdf(
    Map<String, dynamic> tripData,
    Map<String, dynamic> flightData,
    List<Map<String, dynamic>> scheduleTransactions,
    List<Map<String, dynamic>> flightExpenses,
  ) async {
    final pdf = pw.Document();

    // Load the app icon
    final ByteData bytes =
        await rootBundle.load('assets/exzplanner.png'); // Adjust path as needed
    final pw.MemoryImage image = pw.MemoryImage(bytes.buffer.asUint8List());

    // Debug print to check trip and flight data
    print("Trip Data: $tripData");
    print("Flight Data: $flightData");

    // Calculate total cost with null checks
    final double tripBudget = (tripData['budget'] as num?)?.toDouble() ?? 0.0;
    final double tripExpenses =
        (tripData['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final double flightCost = (flightData['cost'] as num?)?.toDouble() ?? 0.0;

    // Calculate total budget (trip budget + flight cost)
    final double totalBudget = tripBudget + flightCost;

    // Calculate flight expenses by category
    final Map<String, double> flightExpensesByCategory =
        _calculateFlightExpensesByCategory(flightExpenses);
    final double totalFlightExpenses = flightExpensesByCategory.values
        .fold(0.0, (sum, amount) => sum + amount);

    // Calculate total actual expenses
    final double totalActualExpenses =
        tripExpenses + flightCost + totalFlightExpenses;

    // Calculate remaining/exceeding expenses for the whole trip
    final double remainingExceedingExpenses = totalBudget - totalActualExpenses;
    final String remainingExceedingMessage = remainingExceedingExpenses >= 0
        ? 'Remaining Expenses for Whole Trip: RM ${remainingExceedingExpenses.toStringAsFixed(2)}'
        : 'Exceeded Expenses for Whole Trip: RM ${(-remainingExceedingExpenses).toStringAsFixed(2)}';

    // Build PDF content with automatic pagination
    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Header with app icon and title
            pw.Row(
              children: [
                pw.Image(image, width: 50, height: 50),
                pw.SizedBox(width: 10),
                pw.Text('Trip and Flight Report',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 20),

            // Trip details
            pw.Text('Trip Details',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text(
                'Destination: ${tripData['country'] ?? 'Unknown Destination'}'),
            pw.Text('From: ${_formatDate(tripData['from_date'])}'),
            pw.Text('To: ${_formatDate(tripData['to_date'])}'),
            pw.Text('Trip Budget: RM ${tripBudget.toStringAsFixed(2)}'),
            pw.Text(
                'Total Expense for Places/Sightseeing:\nRM ${tripExpenses.toStringAsFixed(2)}',
                style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 20),

            // Flight details
            pw.Text('Flight Details',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('From: ${flightData['from'] ?? 'Unknown Origin'}'),
            pw.Text('To: ${flightData['to'] ?? 'Unknown Destination'}'),
            pw.Text(
                'Departure Time: ${_formatDate(flightData['departure_time'])}'),
            pw.Text('Flight Cost: RM ${flightCost.toStringAsFixed(2)}'),
            pw.SizedBox(height: 20),

            // Schedule List (from schedule subcollection under trips)
            pw.Text('Schedule List',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            // Create a table for the schedule list
            if (scheduleTransactions.isNotEmpty)
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(),
                headers: ['Place', 'Cost (RM)'], // Table headers
                data: scheduleTransactions
                    .map((transaction) => [
                          transaction['place'] ?? 'N/A', // Place
                          (transaction['cost'] as num?)?.toStringAsFixed(2) ??
                              '0.00', // Cost
                        ])
                    .toList(),
              ),
            if (scheduleTransactions.isEmpty)
              pw.Text('No schedule items found.',
                  style: const pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 20),

            // Flight Expenses List (from expenses subcollection under flights)
            pw.Text('Flight Expenses by Category',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            // Create a table for the flight expenses list
            if (flightExpensesByCategory.isNotEmpty)
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(),
                headers: ['Category', 'Total Cost (RM)'], // Table headers
                data: flightExpensesByCategory.entries
                    .map((entry) => [
                          entry.key, // Category
                          entry.value.toStringAsFixed(2), // Total Cost
                        ])
                    .toList(),
              ),
            if (flightExpensesByCategory.isEmpty)
              pw.Text('No flight expenses found.',
                  style: const pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 20),

            // Combined total budget and expenses
            pw.Text('Total Budget: RM ${totalBudget.toStringAsFixed(2)}',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Total Expenses For Whole Trip: RM ${totalActualExpenses.toStringAsFixed(2)}',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                remainingExceedingMessage, // Add the remaining/exceeding message here
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: remainingExceedingExpenses >= 0
                        ? PdfColors.green
                        : PdfColors.red)),
          ];
        },
      ),
    );

    // Save and open the PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // Function to delete the trip and its associated schedules
  Future<void> _deleteTrip(BuildContext context) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text(
            'Are you sure you want to delete this trip and all its associated schedules?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        // Delete all schedule items associated with the trip
        final scheduleSnapshot = await FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId)
            .collection('schedule')
            .get();

        for (var doc in scheduleSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete the trip document
        await FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId)
            .delete();

        // Show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Trip and associated schedules deleted successfully.')),
        );

        // Navigate back to the previous screen
        Navigator.pop(context);
      } catch (e) {
        // Show an error message if something goes wrong
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting trip: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Details',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final combinedData = await fetchCombinedData(tripId);
              if (combinedData != null) {
                final scheduleTransactions = await fetchTransactions(tripId);
                final flightId = combinedData['flightId'];
                if (flightId != null) {
                  final flightExpenses = await fetchFlightExpenses(flightId);
                  _generateCombinedPdf(
                    combinedData['trip'],
                    combinedData['flight'],
                    scheduleTransactions,
                    flightExpenses,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Flight ID is missing.')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('No matching flight found for this trip.')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteTrip(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('trips')
                .doc(tripId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.data() == null) {
                return const Center(child: Text("Trip not found"));
              }

              final tripData = snapshot.data!.data() as Map<String, dynamic>;
              double totalExpenses = tripData['total_expenses'] ?? 0.0;
              double tripBudget = tripData['budget'] ?? 0.0;

              // Calculate remaining budget (trip budget - total expenses for places/sightseeing)
              double remainingBudget = tripBudget - totalExpenses;

              // Prepare budget message
              Widget budgetMessage;
              if (remainingBudget < 0) {
                budgetMessage = Text(
                  'Exceeded Budget by RM ${(-remainingBudget).toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                );
              } else {
                budgetMessage = Text(
                  'Remaining Budget: RM ${remainingBudget.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display the trip image
                  if (tripData['image_url'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        tripData['image_url'],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.error);
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text("Destination: ${tripData['country']}",
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("From: ${_formatDate(tripData['from_date'])}",
                      style: const TextStyle(fontSize: 16)),
                  Text("To: ${_formatDate(tripData['to_date'])}",
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  Text("Budget: RM ${tripBudget.toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                      "Total Expense for Places/Sightseeing:\nRM ${totalExpenses.toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  budgetMessage, // Add the budget message here
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapSearchScreen(tripId: tripId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                    ),
                    child: const Text("Add Places to Visit",
                        style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  TripScheduleList(tripId: tripId),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}