  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart'; // Import for TextInputFormatter
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import '../models/expense.dart';
  import '../models/budget.dart';
  import '../utils/expense_utils.dart';
  import '../utils/icon_utils.dart';  // Import the icon_utils file
  import 'package:intl/intl.dart';

  class ExpenseDashboard extends StatefulWidget {
    static const routeName = '/expense'; // Add this line

    const ExpenseDashboard({super.key});

    @override
    _ExpenseDashboardState createState() => _ExpenseDashboardState();
  }

  class _ExpenseDashboardState extends State<ExpenseDashboard> {
    List<Expense> expenses = [];
    Budget budget = Budget(goal: 0.0);
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    @override
    void initState() {
      super.initState();
      _loadExpenses();
      _loadBudget();
    }

    Future<void> _loadExpenses() async {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        try {
          final snapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('expenses')
              .orderBy('date', descending: true)
              .get();
          setState(() {
            expenses = snapshot.docs.map((doc) {
              return Expense.fromFirestore(doc.data(), doc.id);
            }).toList();
          });
        } catch (e) {
          print('Error loading expenses: $e');
        }
      }
    }

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

    Future<void> _addOrUpdateExpense(Expense expense, {String? docId}) async {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        try {
          if (docId == null) {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('expenses')
                .add(expense.toMap());
          } else {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('expenses')
                .doc(docId)
                .update(expense.toMap());
          }

          await _loadExpenses();
          budget.actual = ExpenseUtils.getMonthlyExpenses(expenses);
          await budget.addOrUpdateBudget(userId);
        } catch (e) {
          print('Error adding/updating expense: $e');
        }
      }
    }

    Future<void> _deleteExpense(String docId) async {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        try {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('expenses')
              .doc(docId)
              .delete();
          await _loadExpenses();
          budget.actual = ExpenseUtils.getMonthlyExpenses(expenses);
          await budget.addOrUpdateBudget(userId);
          _showSnackbar(context, 'Expense deleted successfully!');
        } catch (e) {
          print('Error deleting expense: $e');
        }
      }
    }

    void _showSnackbar(BuildContext context, String message) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }

    void _showExpenseDialog(BuildContext context, {Expense? existingExpense}) {
      TextEditingController nameController =
          TextEditingController(text: existingExpense?.name ?? '');
      TextEditingController amountController = TextEditingController(
          text: existingExpense?.amount.toString() ?? '0.00');
      TextEditingController categoryController =
          TextEditingController(text: existingExpense?.category ?? '');
      String selectedCategory = existingExpense?.category ?? 'Food';
      DateTime selectedDate = existingExpense?.date ?? DateTime.now();

      FocusNode amountFocusNode = FocusNode();
      FocusNode categoryFocusNode = FocusNode();

      amountFocusNode.addListener(() {
        if (amountFocusNode.hasFocus) {
          amountController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: amountController.text.length,
          );
        }
      });

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              existingExpense == null ? 'Add Expense' : 'Edit Expense',
              style: const TextStyle(fontSize: 24),
            ),
            content: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Expense Name',
                        ),
                      ),
                      TextField(
                        controller: amountController,
                        focusNode: amountFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                        ),
                      ),
                      TextField(
                        controller: categoryController,
                        focusNode: categoryFocusNode,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        onChanged: (value) {
                          setState(() {
                            selectedCategory = value;
                          });
                        },
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <String>[
                            'Food',
                            'Entertainment',
                            'Shopping',
                            'Toll Fee',
                            'Fuel',
                            'Other Fees'
                          ].map((category) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedCategory = category;
                                  categoryController.text = category;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      getCategoryIcon(category),
                                      color: selectedCategory == category
                                          ? Colors.teal
                                          : Colors.grey,
                                    ),
                                    Text(
                                      category,
                                      style: TextStyle(
                                        color: selectedCategory == category
                                            ? Colors.teal
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                        child: Text(
                          "Selected Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}",
                          style:
                              const TextStyle(color: Colors.blue, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      amountController.text.isNotEmpty &&
                      categoryController.text.isNotEmpty) {
                    _addOrUpdateExpense(
                      Expense(
                        id: existingExpense?.id ?? '',
                        name: nameController.text,
                        amount: double.parse(amountController.text),
                        date: selectedDate,
                        category: selectedCategory,
                      ),
                      docId: existingExpense?.id,
                    );
                    Navigator.of(context).pop();
                  } else {
                    _showSnackbar(context, 'Please fill all fields.');
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ).then((_) {
        amountFocusNode.dispose();
        categoryFocusNode.dispose();
      });
    }

    void _showBudgetDialog(BuildContext context) {
      TextEditingController budgetController = TextEditingController(
        text: budget.goal.toString(),
      );

      FocusNode budgetFocusNode = FocusNode();

      budgetFocusNode.addListener(() {
        if (budgetFocusNode.hasFocus) {
          budgetController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: budgetController.text.length,
          );
        }
      });

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Set Monthly Budget', style: TextStyle(fontSize: 24)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: budgetController,
                  focusNode: budgetFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(labelText: 'Budget Amount'),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  double? newBudget = double.tryParse(budgetController.text);
                  if (newBudget != null) {
                    setState(() {
                      budget.goal = newBudget;
                      budget.actual = ExpenseUtils.getMonthlyExpenses(expenses);
                    });
                    await budget.addOrUpdateBudget(_auth.currentUser!.uid);
                    Navigator.of(context).pop();
                  } else {
                    _showSnackbar(context, 'Please enter a valid budget.');
                  }
                },
                child: const Text('Save Budget'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ).then((_) {
        budgetFocusNode.dispose();
      });
    }

    @override
    Widget build(BuildContext context) {
      Map<String, List<Expense>> groupedExpenses = {};
      for (var expense in expenses) {
        var dateKey = DateFormat('MMMM yyyy').format(expense.date);
        if (groupedExpenses[dateKey] == null) {
          groupedExpenses[dateKey] = [];
        }
        groupedExpenses[dateKey]!.add(expense);
      }

      double monthlyActualExpenses = ExpenseUtils.getMonthlyExpenses(expenses);
      double remainingBudget = budget.goal - monthlyActualExpenses;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Expense Tracker',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.teal,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                _showBudgetDialog(context);
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 5,
                  color: Colors.teal.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Monthly Budget',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'RM${budget.goal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (budget.goal > 0)
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Monthly Expenses',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'RM${monthlyActualExpenses.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Remaining Budget: RM${remainingBudget.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: remainingBudget < 0
                                        ? Colors.red
                                        : Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(thickness: 2, color: Colors.grey),
              Padding(
                padding: const EdgeInsets.only(bottom: 0.0),
                child: _buildExpenseSummary(
                  'Today\'s Expenses',
                  ExpenseUtils.getTodayExpenses(expenses),
                  fontSize: 16,
                ),
              ),
              const Divider(thickness: 2, color: Colors.grey),
              ...groupedExpenses.entries.map((entry) {
                String monthYear = entry.key;
                List<Expense> monthExpenses = entry.value;

                List<Widget> monthWidgets = [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: Text(
                      monthYear,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ...monthExpenses.map((expense) {
                    return Card(
                      elevation: 3,
                      margin:
                          const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                      child: GestureDetector(
                        onTap: () {
                          _showExpenseDialog(context, existingExpense: expense);
                        },
                        child: ListTile(
                          title: Text(
                            expense.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('yyyy-MM-dd').format(expense.date),
                                style: const TextStyle(fontSize: 16),
                              ),
                              Text(
                                expense.category,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'RM${expense.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Confirm Deletion'),
                                        content: const Text(
                                          'Are you sure you want to delete this expense?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              _deleteExpense(expense.id);
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Delete'),
                                          ),
                                        ],
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
                  }),
                ];

                return Column(children: monthWidgets);
              }),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showExpenseDialog(context);
          },
          backgroundColor: Colors.teal,
          child: const Icon(Icons.add),
        ),
      );
    }

    Widget _buildExpenseSummary(String title, double amount,
        {double fontSize = 20}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
          ),
          Align(
            alignment: Alignment.center,
            child: Text(
              'RM${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ),
        ],
      );
    }
  }