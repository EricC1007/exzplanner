import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Import intl package
import '../models/expense.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _pickedFile;
  String? _recognizedText;
  String? totalAmount;
  String? dateStr;
  String? restaurantName;
  bool _isProcessing = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _pickImage() async {
    await _showImageSourceDialog();
  }

  Future<void> _showImageSourceDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera, color: Colors.teal),
                title: const Text('Take a Photo'),
                onTap: () {
                  _getImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.teal),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  _getImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _pickedFile = pickedFile;
          _recognizedText = null;
          totalAmount = null;
          dateStr = null;
          restaurantName = null;
          _isProcessing = true;
        });
        await _recognizeText();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _recognizeText() async {
    if (_pickedFile == null) return;

    try {
      final inputImage = InputImage.fromFilePath(_pickedFile!.path);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);

      setState(() {
        _recognizedText = recognizedText.text;
      });

      if (_recognizedText != null) {
        _extractDetails(_recognizedText!);
      }

      await _showConfirmationDialog();

      textRecognizer.close();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Text recognition error: $e')),
      );
    }
  }

  void _extractDetails(String recognizedText) {
    List<String> lines = recognizedText.split('\n');
    String? bestDate;
    String? bestTotalAmount;
    String? bestRestaurantName;

    final dateRegex = RegExp(r'(\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b)|(\b\d{4}[-/]\d{1,2}[-/]\d{1,2}\b)');
    final amountRegex = RegExp(r'\b\d+(\.\d{1,2})?\b');
    final merchantNameRegex = RegExp(r'^[A-Za-z0-9äöÄÖ\s,.\-()&*/]+$');

    for (var line in lines) {
      final trimmedLine = line.trim();

      // Extract date
      final dateMatch = dateRegex.firstMatch(trimmedLine);
      if (dateMatch != null) {
        bestDate = dateMatch.group(0);
      }

      // Extract total amount
      final amountMatch = amountRegex.firstMatch(trimmedLine);
      if (amountMatch != null) {
        bestTotalAmount = amountMatch.group(0);
      }

      // Extract restaurant name
      if (bestRestaurantName == null && merchantNameRegex.hasMatch(trimmedLine) && trimmedLine.length > 5) {
        bestRestaurantName = trimmedLine;
      }
    }

    // Assign extracted values
    dateStr = bestDate ?? "Not recognized";
    totalAmount = bestTotalAmount ?? "Not recognized";
    restaurantName = bestRestaurantName ?? "Not recognized";
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr != null && dateStr.length >= 10) {
      String datePart = dateStr.substring(0, 10); // Extract "dd/MM/yyyy"
      try {
        return DateFormat('dd/MM/yyyy').parse(datePart);
      } catch (e) {
        // Handle parsing error
      }
    }
    return null;
  }

  Future<void> _showConfirmationDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Recognized Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Restaurant Name: $restaurantName'),
              Text('Date: ${_parseDate(dateStr) ?? "Not recognized"}'),
              Text('Total Amount: $totalAmount'),
              const SizedBox(height: 8),
              const Text('Please confirm or edit the information before saving:'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showCategorySelectionDialog(
                  double.tryParse(totalAmount ?? '0') ?? 0,
                  _parseDate(dateStr),
                  restaurantName ?? '',
                );
              },
              child: const Text('Confirm'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Implement editing functionality here
              },
              child: const Text('Edit'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _pickImage();
              },
              child: const Text('Retake'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCategorySelectionDialog(double amount, DateTime? parsedDate, String restaurantName) async {
    String selectedCategory = 'Food';

    List<String> categories = [
      'Food',
      'Entertainment',
      'Shopping',
      'Toll Fee',
      'Fuel',
      'Other Fees',
    ];

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Category'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var category in categories)
                    RadioListTile<String>(
                      title: Text(category),
                      value: category,
                      groupValue: selectedCategory,
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value!;
                        });
                      },
                    ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    await _addExpense(
                      Expense(
                        name: restaurantName,
                        amount: amount,
                        date: parsedDate ?? DateTime.now(),
                        category: selectedCategory,
                        id: '',
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save Expense'),
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
        );
      },
    );
  }

  Future<void> _addExpense(Expense expense) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).collection('expenses').add(expense.toMap());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense saved successfully!')),
        );
        // Remove recognized text after saving
        setState(() {
          _recognizedText = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving expense: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        actions: [
          if (_pickedFile != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: () {
                setState(() {
                  _pickedFile = null;
                  _recognizedText = null;
                  totalAmount = null;
                  dateStr = null;
                  restaurantName = null;
                });
              },
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_pickedFile != null)
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_pickedFile!.path),
                              height: 300,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_recognizedText != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                'Recognized Text:\n$_recognizedText',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  const Text(
                    'No image selected.',
                    style: TextStyle(fontSize: 16),
                  ),
                const SizedBox(height: 20),
                if (_isProcessing)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: _pickImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text(
                      'Capture Image',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}