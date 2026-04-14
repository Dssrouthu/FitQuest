import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

const _kTimeout = Duration(seconds: 20);

class AnalyticsService {
  static const String baseUrl = ApiService.baseUrl;

  static String _auth(String u, String p) =>
      'Basic ' + base64Encode(utf8.encode('$u:$p'));

  static Map<String, String> _headers(String u, String p) => {
        'Content-Type': 'application/json',
        'Authorization': _auth(u, p),
      };

  // ── Daily Activity ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchTodayActivity(
      String u, String p) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/analytics/daily/'),
          headers: _headers(u, p),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load daily activity');
  }

  static Future<Map<String, dynamic>> updateTodayActivity(
    String u,
    String p, {
    int? waterMl,
    int? waterGoalMl,
    int? steps,
    int? stepGoal,
  }) async {
    final body = <String, dynamic>{};
    if (waterMl != null) body['water_ml'] = waterMl;
    if (waterGoalMl != null) body['water_goal_ml'] = waterGoalMl;
    if (steps != null) body['steps'] = steps;
    if (stepGoal != null) body['step_goal'] = stepGoal;

    final response = await http
        .post(
          Uri.parse('$baseUrl/analytics/daily/'),
          headers: _headers(u, p),
          body: jsonEncode(body),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to update daily activity');
  }

  // ── Body Progress ──────────────────────────────────────────────────────────
  static Future<List<dynamic>> fetchBodyProgress(String u, String p) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/analytics/body-progress/'),
          headers: _headers(u, p),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load body progress');
  }

  static Future<Map<String, dynamic>> createBodyProgress(
      String u, String p, Map<String, dynamic> data) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/analytics/body-progress/'),
          headers: _headers(u, p),
          body: jsonEncode(data),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to create body progress entry');
  }

  static Future<void> deleteBodyProgress(String u, String p, int id) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/analytics/body-progress/$id/'),
          headers: _headers(u, p),
        )
        .timeout(_kTimeout);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete body progress entry');
    }
  }

  // ── Live Heartbeat ─────────────────────────────────────────────────────────
  static Future<void> sendHeartbeat(
      String u, String p, String activityType, int stepsLive) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/analytics/heartbeat/'),
            headers: _headers(u, p),
            body: jsonEncode({
              'activity_type': activityType,
              'steps_live': stepsLive,
            }),
          )
          .timeout(_kTimeout);
    } catch (_) {
      // Heartbeat is best-effort; don't throw
    }
  }

  // ── Team Activity (Coach/SC) ───────────────────────────────────────────────
  static Future<List<dynamic>> fetchTeamActivity(String u, String p) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/analytics/team-activity/'),
          headers: _headers(u, p),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load team activity');
  }

  // ── Workout Set Logging ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> logSet(
      String u, String p, Map<String, dynamic> data) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/analytics/log-set/'),
          headers: _headers(u, p),
          body: jsonEncode(data),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to log set');
  }

  static Future<List<dynamic>> fetchMySetLogs(String u, String p) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/analytics/my-sets/'),
          headers: _headers(u, p),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load set logs');
  }

  static Future<List<dynamic>> fetchMySetLogsForDate(String u, String p, String date) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/analytics/my-sets/?date=$date'),
          headers: _headers(u, p),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load set logs for date');
  }

  static Future<Map<String, dynamic>> fetchDailySummary(
      String u, String p, int year, int month) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/analytics/daily-summary/?year=$year&month=$month'),
          headers: _headers(u, p),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load daily summary');
  }

  static Future<List<dynamic>> fetchAthleteSetLogs(
      String u, String p, int athleteId) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/analytics/athlete/$athleteId/sets/'),
          headers: _headers(u, p),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load athlete set logs');
  }

  static Future<Map<String, dynamic>> fetchAthleteSummary(
      String u, String p, int athleteId) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/analytics/athlete/$athleteId/summary/'),
          headers: _headers(u, p),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load athlete summary');
  }

  static Future<List<dynamic>> fetchPhotoGallery(String u, String p) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/analytics/photos/'),
          headers: _headers(u, p),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load photo gallery');
  }

  static Future<List<dynamic>> fetchAthleteBodyProgress(
      String u, String p, int athleteId) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/analytics/athlete/$athleteId/body-progress/'),
          headers: _headers(u, p),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load athlete body progress');
  }

  // ── Self Transformations (Recruit) ────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchMyTransformations(
      String u, String p) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/analytics/my-transformations/'),
          headers: _headers(u, p),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load transformations');
  }

  // ── Ghost Duels (AR PvP) ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchGhostDuelData(
      String u, String p, int setId) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/analytics/ghost-duel/$setId/'),
          headers: _headers(u, p),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load ghost duel data');
  }
}
