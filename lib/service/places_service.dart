import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlacesService {
  final String _apiKey = 'AIzaSyARPiMoBQp5IMU-vxKxYAB-vvlmMCk5jR0'; // Replace with your Google Places API key

  Future<List<String>> getPlaceSuggestions(String query) async {
    final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=$query'
        '&key=$_apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        return List<String>.from(data['predictions'].map((pred) => pred['description']));
      } else {
        print('Error getting place suggestions: ${data['status']}');
        return [];
      }
    } else {
      print('Error getting place suggestions: ${response.statusCode}');
      return [];
    }
  }

  Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    final url = 'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&key=$_apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        return data['result'];
      } else {
        print('Error getting place details: ${data['status']}');
        return {};
      }
    } else {
      print('Error getting place details: ${response.statusCode}');
      return {};
    }
  }

  Future<Map<String, dynamic>> getPlaceFromCoordinates(LatLng coordinates) async {
    final url = 'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${coordinates.latitude},${coordinates.longitude}'
        '&key=$_apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        return data['results'][0];
      } else {
        print('Error getting place from coordinates: ${data['status']}');
        return {};
      }
    } else {
      print('Error getting place from coordinates: ${response.statusCode}');
      return {};
    }
  }
}

