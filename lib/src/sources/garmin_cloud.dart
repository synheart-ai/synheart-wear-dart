import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/logger.dart';

/// Garmin Cloud Provider for Synheart Wear SDK
///
/// Connects to Garmin Health API via backend connector service.
/// Implements OAuth2 PKCE flow with intermediate redirect per documentation.
class GarminProvider {
  // Storage keys
  static const String _userIdKey = 'garmin_user_id';
  static const String _baseUrlKey = 'sdk_base_url';
  static const String _appIdKey = 'sdk_app_id';
  static const String _redirectUriKey = 'sdk_redirect_uri';

  // Default values
  static const String defaultBaseUrl = 'https://synheart-wear-service-leatest.onrender.com';
  static const String defaultRedirectUri = 'synheart://oauth/callback';

  String baseUrl;
  String? redirectUri;
  String appId; // REQUIRED
  String? userId;

  GarminProvider({
    String? baseUrl,
    String? appId,
    String? redirectUri,
    this.userId,
    bool loadFromStorage = true,
  }) : baseUrl = baseUrl ?? defaultBaseUrl,
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
  String _generateState([int length = 32]) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  /// Generate PKCE code verifier (43-128 characters, URL-safe)
  /// The service will generate the code_challenge from this verifier
  String _generateCodeVerifier() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final rand = Random.secure();
    // Generate 128 characters for maximum security
    return List.generate(128, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Get authorization URL from service
  /// Returns the authorization URL and encoded state (containing original state + code_verifier)
  Future<Map<String, String>> getAuthorizationUrl(String state) async {
    // Generate PKCE code verifier (service will generate code_challenge)
    final codeVerifier = _generateCodeVerifier();

    // Encode state with code_verifier (service will decode this and generate code_challenge)
    final stateData = {
      'state': state,
      'code_verifier': codeVerifier,
      'redirect_uri': redirectUri, // App's deep link
    };
    final encodedState = base64UrlEncode(
      utf8.encode(jsonEncode(stateData)),
    ).replaceAll('=', '');

    final serviceUrl = Uri.parse('https://synheart-wear-service-leatest.onrender.com/v1/garmin/oauth/authorize').replace(
      queryParameters: {
        'app_id': appId,
        'redirect_uri': redirectUri ?? defaultRedirectUri,
        'state': encodedState,
        if (userId != null) 'user_id': userId!,
      },
    );

    final response = await http.get(serviceUrl);
    logDebug('Garmin authorization response: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get Garmin authorization URL: ${response.body}',
      );
    }

    final json = jsonDecode(response.body);
    final String authUrl = json['authorization_url'];

    if (authUrl.isEmpty) {
      throw Exception('authorization_url is missing in response');
    }

    // Return both the authorization URL and the encoded state
    // The SDK should pass the encoded state to the callback handler
    return {
      'authorization_url': authUrl,
      'state': encodedState, // Return encoded state for callback
    };
  }

  /// Start OAuth flow: generate state, get URL, and launch browser
  /// Returns a map with 'state' (encoded) and 'authorization_url'
  Future<Map<String, String>> startOAuthFlow() async {
    final state = _generateState();
    final result = await getAuthorizationUrl(state);
    logDebug('Garmin authorization result: $result');
    final launched = await launchUrl(
      Uri.parse(result['authorization_url']!),
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      throw Exception('Cannot open browser');
    }

    return result; // Return encoded state for callback handling
  }

  /// Handle OAuth callback from deep link
  /// This is called when the app receives the deep link after service redirects
  /// Deep link format: synheart://oauth/callback?success=true&user_id=xxx
  /// or: synheart://oauth/callback?success=false&error=error_message
  Future<String?> handleDeepLinkCallback(Uri uri) async {
    if (uri.scheme != 'synheart' ||
        uri.host != 'oauth' ||
        uri.path != '/callback') {
      return null; // Not our callback
    }

    final success = uri.queryParameters['success'];
    final userID = uri.queryParameters['user_id'];
    final error = uri.queryParameters['error'];

    if (success == 'true' && userID != null) {
      // Connection successful
      await saveUserId(userID);
      return userID;
    } else if (error != null) {
      // Connection failed
      throw Exception('OAuth callback failed: $error');
    }

    return null;
  }

  /// Convenience method for connection success
  Future<void> onConnectionSuccess(String userID) async {
    await saveUserId(userID);
  }

  /// Convenience method for connection error
  void onConnectionError(String error) {
    throw Exception('Garmin connection error: $error');
  }

  /// Connect method (for compatibility with WHOOP-style API)
  /// Note: For Garmin, the actual connection happens via deep link callback
  /// This method just starts the OAuth flow
  Future<String> connect() async {
    final result = await startOAuthFlow();
    // Return the encoded state - the actual user_id will come from deep link callback
    return result['state'] ?? '';
  }

  /// Fetch Garmin data - generic method for all summary types
  Future<Map<String, dynamic>> _fetchData(
    String summaryType,
    String userId,
    DateTime? start,
    DateTime? end,
  ) async {
    final params = {
      'app_id': appId,
      if (start != null) 'start': start.toUtc().toIso8601String(),
      if (end != null) 'end': end.toUtc().toIso8601String(),
    };

    final uri = Uri.parse(
      '$baseUrl/v1/garmin/data/$userId/$summaryType',
    ).replace(queryParameters: params);

    logDebug('Garmin data request URI: $uri');
    final res = await http.get(uri);
    logDebug('Garmin data response: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch Garmin $summaryType: ${res.body}');
    }

    return jsonDecode(res.body);
  }

  // ========== Data Fetching Methods (12 Summary Types) ==========

  /// Fetch daily summaries (steps, calories, heart rate, stress, body battery)
  Future<Map<String, dynamic>> fetchDailies({
    required String userId,
    DateTime? start,
    DateTime? end,
  }) => _fetchData('dailies', userId, start, end);

  /// Fetch 15-minute granular activity periods
  Future<Map<String, dynamic>> fetchEpochs({
    required String userId,
    DateTime? start,
    DateTime? end,
  }) => _fetchData('epochs', userId, start, end);

  /// Fetch sleep data (duration, levels, scores)
  Future<Map<String, dynamic>> fetchSleeps({
    required String userId,
    DateTime? start,
    DateTime? end,
  }) => _fetchData('sleeps', userId, start, end);

  /// Fetch detailed stress values and body battery events
  Future<Map<String, dynamic>> fetchStressDetails({
    required String userId,
    DateTime? start,
    DateTime? end,
  }) => _fetchData('stressDetails', userId, start, end);

  /// Fetch heart rate variability metrics
  Future<Map<String, dynamic>> fetchHRV({
    required String userId,
    DateTime? start,
    DateTime? end,
  }) => _fetchData('hrv', userId, start, end);

  /// Fetch user metrics (VO2 Max, Fitness Age)
  Future<Map<String, dynamic>> fetchUserMetrics({
    required String userId,
    DateTime? start,
    DateTime? end,
  }) => _fetchData('userMetrics', userId, start, end);

  /// Fetch body composition (weight, BMI, body fat, etc.)
  Future<Map<String, dynamic>> fetchBodyComps({
    required String userId,
    DateTime? start,
    DateTime? end,
  }) => _fetchData('bodyComps', userId, start, end);

  /// Fetch pulse oximetry data
  Future<Map<String, dynamic>> fetchPulseOx({
    required String userId,
    DateTime? start,
    DateTime? end,
  }) => _fetchData('pulseox', userId, start, end);

  /// Fetch respiration rate data
  Future<Map<String, dynamic>> fetchRespiration({
    required String userId,
    DateTime? start,
    DateTime? end,
  }) => _fetchData('respiration', userId, start, end);

  /// Fetch health snapshot data
  Future<Map<String, dynamic>> fetchHealthSnapshot({
    required String userId,
    DateTime? start,
    DateTime? end,
  }) => _fetchData('healthSnapshot', userId, start, end);

  /// Fetch blood pressure measurements
  Future<Map<String, dynamic>> fetchBloodPressures({
    required String userId,
    DateTime? start,
    DateTime? end,
  }) => _fetchData('bloodPressures', userId, start, end);

  /// Fetch skin temperature data
  Future<Map<String, dynamic>> fetchSkinTemp({
    required String userId,
    DateTime? start,
    DateTime? end,
  }) => _fetchData('skinTemp', userId, start, end);

  // ========== Additional Garmin Methods ==========

  /// Get Garmin User ID (Garmin's API User ID)
  Future<String> getGarminUserId(String userId) async {
    final uri = Uri.parse(
      '$baseUrl/v1/garmin/data/$userId/user_id',
    ).replace(queryParameters: {'app_id': appId});

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to get Garmin User ID: ${res.body}');
    }

    final json = jsonDecode(res.body);
    return json['user_id'] as String;
  }

  /// Get Garmin user permissions
  Future<List<String>> getUserPermissions(String userId) async {
    final uri = Uri.parse(
      '$baseUrl/v1/garmin/data/$userId/user_permissions',
    ).replace(queryParameters: {'app_id': appId});

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to get user permissions: ${res.body}');
    }

    final json = jsonDecode(res.body);
    return List<String>.from(json);
  }

  /// Disconnect Garmin integration
  Future<void> disconnect(String userId) async {
    final uri = Uri.parse(
      '$baseUrl/v1/garmin/oauth/disconnect',
    ).replace(queryParameters: {'user_id': userId, 'app_id': appId});

    final res = await http.delete(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to disconnect: ${res.body}');
    }

    // Clear local storage
    await clearUserId();
  }
}
