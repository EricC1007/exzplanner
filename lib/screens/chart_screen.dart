import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../models/expense.dart';
import '../models/budget.dart';
import '../utils/icon_utils.dart'; // For category icons

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  _ChartScreenState createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  List<Expense> expenses = [];
  Budget budget = Budget(goal: 0.0);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedMonth = '';
  String selectedYear = '';
  bool isLoading = false;

  final List<String> months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  List<String> years = [];

  // Map to store category budgets
  Map<String, double> categoryBudgets = {};

  @override
  void initState() {
    super.initState();
    _initializeDateSelection();
    _loadExpenses();
    _loadBudget();
    _loadCategoryBudgets();
  }

  // Initialize the date selection based on the current date
  void _initializeDateSelection() {
    final now = DateTime.now();
    selectedMonth = months[now.month - 1]; // Months are 1-indexed
    selectedYear = now.year.toString();

    // Generate years from current year to 10 years back
    years = List.generate(10, (index) => (now.year - index).toString());
  }

  // Load the budget
  Future<void> _loadBudget() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      try {
        budget = await Budget.fetchBudget(userId);
        setState(() {});
      } catch (e) {
        print('Error loading budget: $e');
      }
    }
  }

  // Load category budgets from Firestore
  Future<void> _loadCategoryBudgets() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('categoryBudgets')
          .get();

      setState(() {
        categoryBudgets = {
          for (var doc in snapshot.docs) doc.id: doc['budget'].toDouble()
        };
      });
    }
  }

  // Convert month names to index
  int monthNameToIndex(String monthName) {
    return months.indexOf(monthName) + 1; // Months are 1-indexed
  }

  // Load expenses from Firestore
  Future<void> _loadExpenses() async {
    setState(() {
      isLoading = true;
    });
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .get();

      final monthIndex = monthNameToIndex(selectedMonth);
      final filteredExpenses = snapshot.docs
          .map((doc) {
            return Expense.fromFirestore(doc.data(), doc.id);
          })
          .where((expense) =>
              expense.date.month == monthIndex &&
              expense.date.year.toString() == selectedYear)
          .toList();

      setState(() {
        expenses = filteredExpenses;
        isLoading = false; // Stop loading when done
      });
    } else {
      setState(() {
        isLoading = false; // Stop loading if no user
      });
    }
  }

  // Calculate total expenses
  double _calculateTotalExpenses() {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  // Create pie chart data
  List<PieChartSectionData> _createPieChartData() {
    final dataMap = <String, double>{};
    for (var expense in expenses) {
      dataMap[expense.category] =
          (dataMap[expense.category] ?? 0.0) + expense.amount;
    }

    return dataMap.entries.map((entry) {
      return PieChartSectionData(
        color: Colors.primaries[
            dataMap.keys.toList().indexOf(entry.key) % Colors.primaries.length],
        value: entry.value,
        title: '${entry.key}\nRM${entry.value.toStringAsFixed(2)}',
        radius: 80,
        titleStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  // Export to PDF function
  Future<void> _exportToPDF() async {
    final pdf = pw.Document();
    final totalExpenses = _calculateTotalExpenses();

    // Load the app icon
    final ByteData bytes =
        await rootBundle.load('assets/exzplanner.png'); // Adjust path as needed
    final pw.MemoryImage image = pw.MemoryImage(bytes.buffer.asUint8List());

    // Build PDF content
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Image(image, width: 100, height: 100),
                pw.SizedBox(height: 10),
                pw.Text('Monthly Expenses for $selectedMonth $selectedYear',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),

                // Table for total expenses
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FractionColumnWidth(0.55),
                    1: const pw.FractionColumnWidth(0.25),
                    2: const pw.FractionColumnWidth(0.2),
                  },
                  children: [
                    pw.TableRow(children: [
                      pw.Text('Expense Name',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Amount',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ]),
                    ...expenses.map((expense) {
                      return pw.TableRow(children: [
                        pw.Text(expense.name,
                            style: const pw.TextStyle(fontSize: 14)),
                        pw.Text(DateFormat('MM/dd/yyyy').format(expense.date),
                            style: const pw.TextStyle(fontSize: 14)),
                        pw.Text('RM${expense.amount.toStringAsFixed(2)}',
                            style: const pw.TextStyle(
                                fontSize: 14, color: PdfColors.black)),
                      ]);
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text('Total Expenses: RM${totalExpenses.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),

                // Categorized expenses
                pw.SizedBox(height: 30),
                pw.Text('Expenses by Category',
                    style: pw.TextStyle(
                        fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                ..._createCategorizedExpenses(),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // Function to create categorized expenses list
  List<pw.Widget> _createCategorizedExpenses() {
    // Grouping expenses by category
    final Map<String, List<Expense>> categorizedExpenses = {};
    for (var expense in expenses) {
      if (!categorizedExpenses.containsKey(expense.category)) {
        categorizedExpenses[expense.category] = [];
      }
      categorizedExpenses[expense.category]!.add(expense);
    }

    List<pw.Widget> categoryWidgets = [];
    for (var category in categorizedExpenses.keys) {
      double categoryTotal = categorizedExpenses[category]!
          .fold(0.0, (sum, expense) => sum + expense.amount);
      categoryWidgets.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(category,
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
            pw.Text('Total: RM${categoryTotal.toStringAsFixed(2)}',
                style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 5),
            pw.ListView.builder(
              itemCount: categorizedExpenses[category]!.length,
              itemBuilder: (context, index) {
                final expense = categorizedExpenses[category]![index];
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(expense.name, style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(DateFormat('MM/dd/yyyy').format(expense.date),
                        style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('RM${expense.amount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 12)),
                  ],
                );
              },
            ),
            pw.SizedBox(height: 10),
          ],
        ),
      );
    }
    return categoryWidgets;
  }

  // Calculate the percentage of expenses for each category
  double _calculateCategoryPercentage(double categoryTotal, double total) {
    if (total == 0) return 0;
    return (categoryTotal / total) * 100;
  }

  // Display expenses for selected category
  void _showCategoryExpenses(String category) {
    final categoryExpenses =
        expenses.where((expense) => expense.category == category).toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$category Expenses'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: categoryExpenses.length,
              itemBuilder: (context, index) {
                final expense = categoryExpenses[index];
                return ListTile(
                  title: Text(expense.name),
                  subtitle: Text(DateFormat('MM/dd/yyyy').format(expense.date)),
                  trailing: Text('RM${expense.amount.toStringAsFixed(2)}'),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Display budget vs actual spending for each category
  Widget _buildCategoryBudgetWidget(String category, double totalSpending) {
    final double budget = categoryBudgets[category] ?? 0.0;
    final double remainingBudget = budget - totalSpending;
    final bool isOverBudget = remainingBudget < 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading:
            Icon(getCategoryIcon(category)), // Get the icon for the category
        title: Text(
          category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spent: RM${totalSpending.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              'Budget: RM${budget.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              isOverBudget
                  ? 'Exceeded: RM${(-remainingBudget).toStringAsFixed(2)}'
                  : 'Remaining: RM${remainingBudget.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                color: isOverBudget ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _editCategoryBudget(category),
        ),
        onTap: () => _showCategoryExpenses(
            category), // Show expenses for the selected category
      ),
    );
  }

  // Edit category budget
  void _editCategoryBudget(String category) async {
    TextEditingController budgetController = TextEditingController(
      text: categoryBudgets[category]?.toStringAsFixed(2) ?? '0.00',
    );

    showDialog(
      context: context,
      builder: (context) {
        // Use a Future to ensure the text is highlighted after the dialog is shown
        Future.delayed(Duration.zero, () {
          budgetController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: budgetController.text.length,
          );
        });

        return AlertDialog(
          title: Text('Set Budget for $category'),
          content: TextField(
            controller: budgetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Budget',
              border: OutlineInputBorder(),
            ),
            autofocus: true, // Automatically focus on the TextField
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final double? newBudget =
                    double.tryParse(budgetController.text);
                if (newBudget != null && newBudget >= 0) {
                  final userId = _auth.currentUser?.uid;
                  if (userId != null) {
                    await _firestore
                        .collection('users')
                        .doc(userId)
                        .collection('categoryBudgets')
                        .doc(category)
                        .set({'budget': newBudget});

                    setState(() {
                      categoryBudgets[category] = newBudget;
                    });

                    Navigator.pop(context);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a valid budget.')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Expenses'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _exportToPDF,
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(20.0),
        color: Colors.grey[100],
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Year and Month Selection
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<String>(
                            value: selectedYear,
                            items: years.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedYear = newValue!;
                                _loadExpenses();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButton<String>(
                            value: selectedMonth,
                            items: months.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedMonth = newValue!;
                                _loadExpenses();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Pie Chart with Total Expenses
                    Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'Total Expenses: RM${_calculateTotalExpenses().toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 250,
                              child: PieChart(
                                PieChartData(
                                  sections: _createPieChartData(),
                                  centerSpaceRadius: 30,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Category Breakdown with Budgets
                    const Text(
                      'Category Breakdown',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ..._createCategoryWidgets(),
                  ],
                ),
              ),
      ),
    );
  }

  // Create Category Widgets with Budgets
  List<Widget> _createCategoryWidgets() {
    final dataMap = <String, double>{};
    for (var expense in expenses) {
      dataMap[expense.category] =
          (dataMap[expense.category] ?? 0.0) + expense.amount;
    }

    List<Widget> categoryWidgets = [];
    dataMap.forEach((category, totalSpending) {
      categoryWidgets.add(_buildCategoryBudgetWidget(category, totalSpending));
    });

    return categoryWidgets;
  }
}
