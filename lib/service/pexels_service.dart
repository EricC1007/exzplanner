import 'dart:convert';
import 'package:http/http.dart' as http;

class PexelsService {
  final String apiKey = '5o5EIq2KNOn5xpVh7fqKGhZKhamC6ZY5qvBWXtvCk2msSWoB5RLJVNcv';
  final String baseUrl = 'https://api.pexels.com/v1/search';

  Future<List<String>> fetchImages(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl?query=$query&per_page=1'), // Fetch 1 image for simplicity
      headers: {
        'Authorization': apiKey,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Extract the image URL
      return (data['photos'] as List)
          .map((photo) => photo['src']['original'] as String)
          .toList();
    } else {
      throw Exception('Failed to load images');
    }
  }
}