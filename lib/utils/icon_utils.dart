import 'package:flutter/material.dart';

IconData getCategoryIcon(String category) {
  switch (category) {
    case 'Food':
      return Icons.fastfood;
    case 'Entertainment':
      return Icons.local_play;
    case 'Shopping':
      return Icons.shopping_cart;
    case 'Toll Fee':
      return Icons.payments;
    case 'Fuel':
      return Icons.local_gas_station;
    case 'Other Fees':
    default:
      return Icons.attach_money;
  }
}