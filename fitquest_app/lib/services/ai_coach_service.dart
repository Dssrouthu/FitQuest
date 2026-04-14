import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AICoachService {
  static const String baseUrl = ApiService.baseUrl;

  static Future<List<dynamic>> fetchMessages(String username, String password) async {
    String basicAuth = 'Basic ' + base64Encode(utf8.encode('$username:$password'));
    final response = await http.get(
      Uri.parse('$baseUrl/ai-services/messages/'),
      headers: {"Content-Type": "application/json", "Authorization": basicAuth},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load AI Coach messages');
  }

  static Future<void> markAsRead(String username, String password, int messageId) async {
    String basicAuth = 'Basic ' + base64Encode(utf8.encode('$username:$password'));
    final response = await http.patch(
      Uri.parse('$baseUrl/ai-services/messages/$messageId/'),
      headers: {"Content-Type": "application/json", "Authorization": basicAuth},
      body: jsonEncode({"is_read": true}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark message as read');
    }
  }

  static Future<void> acceptSuggestion(String username, String password, int messageId) async {
    String basicAuth = 'Basic ' + base64Encode(utf8.encode('$username:$password'));
    final response = await http.post(
      Uri.parse('$baseUrl/ai-services/messages/$messageId/accept_suggestion/'),
      headers: {"Content-Type": "application/json", "Authorization": basicAuth},
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to accept suggestion');
    }
  }
}
