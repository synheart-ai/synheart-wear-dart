import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/logger.dart';

class WhoopProvider {
  // Storage keys
  static const String _userIdKey = 'whoop_user_id';
  static const String _baseUrlKey = 'sdk_base_url';
  static const String _appIdKey = 'sdk_app_id';
  static const String _redirectUriKey = 'sdk_redirect_uri';

  // Default values
  static const String defaultBaseUrl =
      'https://synheart-wear-service-leatest.onrender.com';
  static const String defaultRedirectUri = 'synheart://oauth/callback';

  String baseUrl;
  String? redirectUri;
  String appId; // REQUIRED
  String? userId;

  WhoopProvider({
    String? baseUrl,
    String? appId,
    String? redirectUri,
    this.userId,
    bool loadFromStorage = true,
  })  : baseUrl = baseUrl ?? defaultBaseUrl,
        appId = appId ?? 'app-123',
        redirectUri = redirectUri ?? defaultRedirectUri {
    if (loadFromStorage) {
      _loadFromStorage();
    }
  }

  /// Load configuration and userId from local storage
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load configuration
      final savedBaseUrl = prefs.getString(_baseUrlKey);
      final savedAppId = prefs.getString(_appIdKey);
      final savedRedirectUri = prefs.getString(_redirectUriKey);

      if (savedBaseUrl != null) baseUrl = savedBaseUrl;
      if (savedAppId != null) appId = savedAppId;
      if (savedRedirectUri != null) redirectUri = savedRedirectUri;

      // Load userId
      final savedUserId = prefs.getString(_userIdKey);
      if (savedUserId != null) userId = savedUserId;
    } catch (e) {
      // Silently fail - use provided/default values
    }
  }

  /// Save userId to local storage
  Future<void> saveUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
      this.userId = userId;
    } catch (e) {
      // Silently fail
    }
  }

  /// Load userId from local storage
  Future<String?> loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString(_userIdKey);
      if (savedUserId != null) {
        userId = savedUserId;
        return savedUserId;
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  /// Clear userId from local storage
  Future<void> clearUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      userId = null;
    } catch (e) {
      // Silently fail
    }
  }

  /// Save configuration to local storage
  Future<void> saveConfiguration({
    String? baseUrl,
    String? appId,
    String? redirectUri,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (baseUrl != null) {
        await prefs.setString(_baseUrlKey, baseUrl);
        this.baseUrl = baseUrl;
      }

      if (appId != null) {
        await prefs.setString(_appIdKey, appId);
        this.appId = appId;
      }

      if (redirectUri != null) {
        await prefs.setString(_redirectUriKey, redirectUri);
        this.redirectUri = redirectUri;
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Load configuration from local storage
  Future<Map<String, String?>> loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'baseUrl': prefs.getString(_baseUrlKey),
        'appId': prefs.getString(_appIdKey),
        'redirectUri': prefs.getString(_redirectUriKey),
      };
    } catch (e) {
      return {};
    }
  }

  /// Reload configuration and userId from storage
  Future<void> reloadFromStorage() async {
    await _loadFromStorage();
  }

  /// Generate a random state string for OAuth
  String _generateState([int length = 8]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }

  // 1. Get authorization URL
  // REPLACE the old getAuthorizationUrl with this one
  Future<String> getRealWhoopLoginUrl(String state) async {
    final serviceUrl = Uri.parse('$baseUrl/v1/whoop/oauth/authorize').replace(
      queryParameters: {
        'app_id': appId,
        'redirect_uri': redirectUri,
        'state': state,
      },
    );

    final response = await http.get(serviceUrl);
    logDebug('WHOOP login response: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to get WHOOP login URL: ${response.body}');
    }

    final json = jsonDecode(response.body);
    final String whoopUrl = json['authorization_url'];

    if (whoopUrl.isEmpty) {
      throw Exception('authorization_url is missing in response');
    }

    return whoopUrl; // This is the REAL https://api.prod.whoop.com/... URL
  }

  /// Start OAuth flow: generate state, get URL, and launch browser
  /// Returns the generated state string for tracking the OAuth callback
  Future<String> startOAuthFlow() async {
    final state = _generateState();
    final realWhoopUrl = await getRealWhoopLoginUrl(state);

    final launched = await launchUrl(
      Uri.parse(realWhoopUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      throw Exception('Cannot open browser');
    }

    return state;
  }

  // 2. Exchange code – CORRECT ENDPOINT
  Future<String> connectWithCode({
    required String code,
    required String state,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/whoop/oauth/callback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "code": code,
        "state": state,
        "redirect_uri": redirectUri,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("OAuth callback failed: ${response.body}");
    }

    final json = jsonDecode(response.body);
    final userId = json['user_id'];

    if (userId == null) {
      throw Exception("Missing user_id in callback response");
    }

    return userId;
  }

  // 3. Fetch methods – CORRECT PATH + app_id in query
  Future<Map<String, dynamic>> fetchRecovery({
    required String userId,
    DateTime? start,
    DateTime? end,
    int limit = 100,
    String? cursor,
  }) =>
      _fetch('recovery', userId, start, end, limit, cursor);

  Future<Map<String, dynamic>> fetchSleep({
    required String userId,
    DateTime? start,
    DateTime? end,
    int limit = 100,
    String? cursor,
  }) =>
      _fetch('sleep', userId, start, end, limit, cursor);

  Future<Map<String, dynamic>> fetchWorkouts({
    required String userId,
    DateTime? start,
    DateTime? end,
    int limit = 100,
    String? cursor,
  }) =>
      _fetch('workouts', userId, start, end, limit, cursor);

  Future<Map<String, dynamic>> fetchCycles({
    required String userId,
    DateTime? start,
    DateTime? end,
    int limit = 100,
    String? cursor,
  }) =>
      _fetch('cycles', userId, start, end, limit, cursor);

  Future<Map<String, dynamic>> _fetch(
    String type,
    String userId,
    DateTime? start,
    DateTime? end,
    int limit,
    String? cursor,
  ) async {
    final params = {
      'app_id': appId,
      if (start != null) 'start': start.toUtc().toIso8601String(),
      if (end != null) 'end': end.toUtc().toIso8601String(),
      'limit': limit.toString(),
      if (cursor != null) 'cursor': cursor,
    };

    final uri = Uri.parse('$baseUrl/v1/whoop/data/$userId/$type')
        .replace(queryParameters: params);
    logDebug('WHOOP data request URI: $uri');
    final res = await http.get(uri);
    logDebug('WHOOP data response: ${res.body}');
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body);
  }

  // 4. Disconnect
  Future<void> disconnect(String userId) async {
    final uri = Uri.parse('$baseUrl/v1/whoop/oauth/disconnect').replace(
      queryParameters: {'user_id': userId, 'app_id': appId},
    );
    final res = await http.delete(uri);
    if (res.statusCode != 200) throw Exception(res.body);
  }
}
