import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart'; // Import for date formatting 

class FlightDetailScreen extends StatefulWidget {
  final String flightId;
  final double flightCost;

  const FlightDetailScreen(
      {super.key, required this.flightId, required this.flightCost});

  @override
  _FlightDetailScreenState createState() => _FlightDetailScreenState();
}

class _FlightDetailScreenState extends State<FlightDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _expenseNameController = TextEditingController();
  final TextEditingController _expenseAmountController =
      TextEditingController();
  String _selectedCategory = 'Accommodation';
  double totalExpense = 0.0;

  final List<String> _categories = [
    'Accommodation',
    'Train Ticket',
    'Food',
    'Transport',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadTotalExpense();
  }

  Future<void> _loadTotalExpense() async {
    final snapshot = await _firestore
        .collection('flights')
        .doc(widget.flightId)
        .collection('expenses')
        .get();
    double total = 0.0;
    for (var doc in snapshot.docs) {
      total += doc['amount'];
    }
    setState(() {
      totalExpense = total;
    });
  }

  Future<void> _addExpense() async {
    String expenseName = _expenseNameController.text;
    double expenseAmount =
        double.tryParse(_expenseAmountController.text) ?? 0.0;

    if (expenseName.isEmpty || expenseAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields correctly.')),
      );
      return;
    }

    await _firestore
        .collection('flights')
        .doc(widget.flightId)
        .collection('expenses')
        .add({
      'name': expenseName,
      'amount': expenseAmount,
      'category': _selectedCategory,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense added successfully.')),
    );

    setState(() {
      _expenseNameController.clear();
      _expenseAmountController.clear();
      totalExpense += expenseAmount;
    });
  }

  Future<void> _deleteExpense(String expenseId, double amount) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
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
      await _firestore
          .collection('flights')
          .doc(widget.flightId)
          .collection('expenses')
          .doc(expenseId)
          .delete();

      setState(() {
        totalExpense -= amount;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted successfully.')),
      );
    }
  }

  Icon _getCategoryIcon(String category) {
    switch (category) {
      case 'Accommodation':
        return const Icon(Icons.hotel);
      case 'Train Ticket':
        return const Icon(Icons.train);
      case 'Food':
        return const Icon(Icons.restaurant);
      case 'Transport':
        return const Icon(Icons.directions_car);
      default:
        return const Icon(Icons.attach_money);
    }
  }

  Future<void> _generatePdf() async {
    final flightDoc =
        await _firestore.collection('flights').doc(widget.flightId).get();
    final flightData = flightDoc.data() as Map<String, dynamic>;

    final expensesSnapshot = await _firestore
        .collection('flights')
        .doc(widget.flightId)
        .collection('expenses')
        .get();

    final pdf = pw.Document();

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
                // Header with app icon and title
                pw.Row(
                  children: [
                    pw.Image(image, width: 50, height: 50),
                    pw.SizedBox(width: 10),
                    pw.Text('Flight Expenses Report',
                        style: pw.TextStyle(
                            fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Note for the user
                pw.Text(
                  'Note: To view the whole trip total price, please generate the report from the Trip.Here only generate Flight and Expense By Category with Details.',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
                pw.SizedBox(height: 20),

                // Flight details
                pw.Text('Flight Details',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('From: ${flightData['from']}'),
                pw.Text('To: ${flightData['to']}'),
                pw.Text(
                    'Departure Time: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(flightData['departure_time']))}'),
                pw.Text(
                    'Flight Cost: RM ${widget.flightCost.toStringAsFixed(2)}'),
                pw.SizedBox(height: 20),

                // Expenses by category
                pw.Text('Expenses by Category',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                ..._createCategorizedExpenses(expensesSnapshot),
                pw.SizedBox(height: 20),

                // Totals
                pw.Text('Total Expense: RM ${totalExpense.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    'Total Cost (Flight + Expenses): RM ${(widget.flightCost + totalExpense).toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // Function to create categorized expenses list
  List<pw.Widget> _createCategorizedExpenses(QuerySnapshot expensesSnapshot) {
    // Grouping expenses by category
    final Map<String, List<Map<String, dynamic>>> categorizedExpenses = {};
    for (var doc in expensesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (!categorizedExpenses.containsKey(data['category'])) {
        categorizedExpenses[data['category']] = [];
      }
      categorizedExpenses[data['category']]!.add(data);
    }

    List<pw.Widget> categoryWidgets = [];
    for (var category in categorizedExpenses.keys) {
      double categoryTotal = categorizedExpenses[category]!
          .fold(0.0, (sum, expense) => sum + expense['amount']);
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
                    pw.Text(expense['name'], style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(
                        DateFormat('MM/dd/yyyy').format(DateTime.parse(
                            expense['date'] ??
                                DateTime.now().toIso8601String())),
                        style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('RM${expense['amount'].toStringAsFixed(2)}',
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

  @override
  Widget build(BuildContext context) {
    double totalCost = widget.flightCost + totalExpense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Expenses'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePdf,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Flight Cost and Totals
              Card(
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Flight Cost: RM ${widget.flightCost.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Total Expense For Categories:',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'RM ${totalExpense.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Total Cost: RM ${totalCost.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Add Expense Form
              Card(
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _expenseNameController,
                        decoration:
                            const InputDecoration(labelText: 'Expense Name'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _expenseAmountController,
                        decoration: const InputDecoration(labelText: 'Amount'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      DropdownButton<String>(
                        value: _selectedCategory,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCategory = newValue!;
                          });
                        },
                        items: _categories
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Row(
                              children: [
                                _getCategoryIcon(value),
                                const SizedBox(width: 8),
                                Text(value),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _addExpense,
                        child: const Text('Add Expense'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Expenses List
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('flights')
                    .doc(widget.flightId)
                    .collection('expenses')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No expenses found.'));
                  }

                  return ListView.builder(
                    shrinkWrap:
                        true, // Ensure the ListView doesn't take infinite space
                    physics:
                        const NeverScrollableScrollPhysics(), // Disable scrolling for the ListView
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      Map<String, dynamic> data = snapshot.data!.docs[index]
                          .data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: _getCategoryIcon(data['category']),
                          title: Text(data['name']),
                          subtitle:
                              Text('RM ${data['amount'].toStringAsFixed(2)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteExpense(
                                snapshot.data!.docs[index].id, data['amount']),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
