import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/logger.dart';
import '../core/models.dart';

/// Provider for Whoop cloud API integration
///
/// Handles OAuth 2.0 authentication and data fetching from Whoop devices.
/// Supports cycles, recovery, sleep, and workout data retrieval.
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
  String _generateState([int length = 8]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
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

  /// Connect method (matches documentation API)
  /// Starts OAuth flow and returns state
  Future<String> connect([dynamic context]) async {
    return await startOAuthFlow();
  }

  // 2. Exchange code – CORRECT ENDPOINT
  /// Connect with authorization code (matches documentation signature)
  Future<String> connectWithCode(
    String code,
    String state,
    String redirectUri,
  ) async {
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

    // Auto-save userId
    await saveUserId(userId);

    // Validate data freshness after connection
    try {
      logWarning('🔍 Validating data freshness after WHOOP connection...');
      final testData = await _fetch(
        'recovery',
        userId,
        DateTime.now().subtract(const Duration(days: 7)),
        DateTime.now(),
        1, // Just fetch 1 record to check freshness
        null,
      );
      _validateDataFreshness(testData, 'WHOOP connection');
      logWarning('✅ WHOOP connection validated: Data is fresh');
    } catch (e) {
      logWarning('⚠️ WHOOP connection data validation failed: $e');
      // Don't fail connection if validation fails, just log warning
    }

    return userId;
  }

  // 3. Fetch methods – CORRECT PATH + app_id in query
  /// Fetch recovery data (userId is optional, uses stored userId if not provided)
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchRecovery({
    String? userId,
    DateTime? start,
    DateTime? end,
    int limit = 100,
    String? cursor,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetch(
      'recovery',
      effectiveUserId,
      start,
      end,
      limit,
      cursor,
    );
    return _convertToWearMetricsList(response, 'whoop', effectiveUserId);
  }

  /// Fetch sleep data (userId is optional, uses stored userId if not provided)
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchSleep({
    String? userId,
    DateTime? start,
    DateTime? end,
    int limit = 100,
    String? cursor,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetch(
      'sleep',
      effectiveUserId,
      start,
      end,
      limit,
      cursor,
    );
    return _convertToWearMetricsList(response, 'whoop', effectiveUserId);
  }

  /// Fetch workouts data (userId is optional, uses stored userId if not provided)
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchWorkouts({
    String? userId,
    DateTime? start,
    DateTime? end,
    int limit = 100,
    String? cursor,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetch(
      'workouts',
      effectiveUserId,
      start,
      end,
      limit,
      cursor,
    );
    return _convertToWearMetricsList(response, 'whoop', effectiveUserId);
  }

  /// Fetch cycles data (userId is optional, uses stored userId if not provided)
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchCycles({
    String? userId,
    DateTime? start,
    DateTime? end,
    int limit = 100,
    String? cursor,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetch(
      'cycles',
      effectiveUserId,
      start,
      end,
      limit,
      cursor,
    );
    return _convertToWearMetricsList(response, 'whoop', effectiveUserId);
  }

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

    final uri = Uri.parse(
      '$baseUrl/v1/whoop/data/$userId/$type',
    ).replace(queryParameters: params);
    logDebug('WHOOP data request URI: $uri');
    final res = await http.get(uri);
    logDebug('WHOOP data response: ${res.body}');
    if (res.statusCode != 200) throw Exception(res.body);
    final data = jsonDecode(res.body);

    // Validate data freshness
    _validateDataFreshness(data, 'WHOOP $type fetch');

    return data;
  }

  /// Extract latest timestamp from API response
  /// Handles various response formats: array, object with data array, or single object
  DateTime? _extractLatestTimestamp(Map<String, dynamic> response) {
    try {
      // Check if response has a 'data' array
      if (response.containsKey('data') && response['data'] is List) {
        final dataList = response['data'] as List;
        if (dataList.isEmpty) return null;

        DateTime? latest;
        for (final item in dataList) {
          if (item is Map<String, dynamic>) {
            final timestamp = _extractTimestampFromItem(item);
            if (timestamp != null &&
                (latest == null || timestamp.isAfter(latest))) {
              latest = timestamp;
            }
          }
        }
        return latest;
      }

      // Check if response is directly an array (wrapped in a map somehow)
      // Or check for common timestamp fields
      if (response.containsKey('timestamp')) {
        return _parseTimestamp(response['timestamp']);
      }

      // Check for common array fields
      for (final key in ['records', 'items', 'results']) {
        if (response.containsKey(key) && response[key] is List) {
          final list = response[key] as List;
          if (list.isNotEmpty && list.first is Map<String, dynamic>) {
            return _extractTimestampFromItem(
              list.first as Map<String, dynamic>,
            );
          }
        }
      }

      // If response itself might be an array (shouldn't happen but handle it)
      // This case is unlikely but we'll return null if we can't find timestamp
      return null;
    } catch (e) {
      logWarning('Error extracting timestamp from WHOOP response: $e');
      return null;
    }
  }

  /// Extract timestamp from a single item (object)
  DateTime? _extractTimestampFromItem(Map<String, dynamic> item) {
    // Try common timestamp field names
    final timestampFields = [
      'timestamp',
      'created_at',
      'start_time',
      'end_time',
      'date',
    ];
    for (final field in timestampFields) {
      if (item.containsKey(field)) {
        return _parseTimestamp(item[field]);
      }
    }
    return null;
  }

  /// Parse timestamp from various formats
  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    if (value is int) {
      // Unix timestamp (seconds or milliseconds)
      if (value > 1000000000000) {
        // Milliseconds
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else {
        // Seconds
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
    }
    return null;
  }

  /// Convert WHOOP API response to list of WearMetrics
  /// Extracts bio signals (HR, HRV, steps, calories, etc.) from API response
  List<WearMetrics> _convertToWearMetricsList(
    dynamic response,
    String source,
    String userId,
  ) {
    final List<WearMetrics> metricsList = [];

    try {
      // Handle if response is already a List
      if (response is List) {
        for (final item in response) {
          if (item is Map<String, dynamic>) {
            final metric = _convertSingleItemToWearMetrics(
              item,
              source,
              userId,
            );
            if (metric != null) {
              metricsList.add(metric);
            }
          }
        }
        return metricsList;
      }

      // Handle if response is a Map
      if (response is! Map<String, dynamic>) {
        return metricsList;
      }

      // Extract data array from response
      List<dynamic>? dataList;
      if (response.containsKey('data') && response['data'] is List) {
        dataList = response['data'] as List;
      } else if (response.containsKey('records') &&
          response['records'] is List) {
        dataList = response['records'] as List;
      } else if (response.containsKey('items') && response['items'] is List) {
        dataList = response['items'] as List;
      }

      if (dataList == null || dataList.isEmpty) {
        // If no array, try to convert single object
        final singleMetric = _convertSingleItemToWearMetrics(
          response,
          source,
          userId,
        );
        if (singleMetric != null) {
          metricsList.add(singleMetric);
        }
        return metricsList;
      }

      // Convert each item in the array
      for (final item in dataList) {
        if (item is Map<String, dynamic>) {
          final metric = _convertSingleItemToWearMetrics(item, source, userId);
          if (metric != null) {
            metricsList.add(metric);
          }
        }
      }
    } catch (e) {
      logWarning('Error converting WHOOP response to WearMetrics: $e');
    }

    return metricsList;
  }

  /// Convert a single WHOOP API item to WearMetrics
  WearMetrics? _convertSingleItemToWearMetrics(
    Map<String, dynamic> item,
    String source,
    String userId,
  ) {
    try {
      final metrics = <String, num?>{};
      final meta = <String, Object?>{};

      // Extract timestamp
      DateTime? timestamp = _extractTimestampFromItem(item);
      if (timestamp == null) {
        // Try to use current time if no timestamp found
        timestamp = DateTime.now();
      }

      // Extract bio signals from WHOOP API response
      // WHOOP recovery data typically contains: recovery_score, hr, hrv, etc.
      if (item.containsKey('recovery_score')) {
        meta['recovery_score'] = item['recovery_score'];
      }
      if (item.containsKey('strain_score')) {
        meta['strain_score'] = item['strain_score'];
      }
      if (item.containsKey('sleep_score')) {
        meta['sleep_score'] = item['sleep_score'];
      }

      // Heart rate
      if (item.containsKey('heart_rate')) {
        metrics['hr'] = _toNum(item['heart_rate']);
      } else if (item.containsKey('hr')) {
        metrics['hr'] = _toNum(item['hr']);
      } else if (item.containsKey('heartRate')) {
        metrics['hr'] = _toNum(item['heartRate']);
      }

      // HRV (WHOOP typically provides HRV in recovery data)
      if (item.containsKey('hrv')) {
        final hrv = _toNum(item['hrv']);
        metrics['hrv_rmssd'] = hrv;
        metrics['hrv_sdnn'] =
            hrv; // Use same value for both if only one provided
      } else if (item.containsKey('hrv_rmssd')) {
        metrics['hrv_rmssd'] = _toNum(item['hrv_rmssd']);
      } else if (item.containsKey('hrv_sdnn')) {
        metrics['hrv_sdnn'] = _toNum(item['hrv_sdnn']);
      }

      // Steps (from workout data)
      if (item.containsKey('steps')) {
        metrics['steps'] = _toNum(item['steps']);
      } else if (item.containsKey('step_count')) {
        metrics['steps'] = _toNum(item['step_count']);
      }

      // Calories
      if (item.containsKey('calories')) {
        metrics['calories'] = _toNum(item['calories']);
      } else if (item.containsKey('kilojoule')) {
        // WHOOP sometimes uses kilojoules, convert to kcal (1 kJ = 0.239 kcal)
        final kj = _toNum(item['kilojoule']);
        if (kj != null) {
          metrics['calories'] = kj * 0.239;
        }
      } else if (item.containsKey('calorie')) {
        metrics['calories'] = _toNum(item['calorie']);
      }

      // Distance (from workout data)
      if (item.containsKey('distance')) {
        metrics['distance'] = _toNum(item['distance']);
      } else if (item.containsKey('distance_meter')) {
        // Convert meters to km
        final meters = _toNum(item['distance_meter']);
        if (meters != null) {
          metrics['distance'] = meters / 1000.0;
        }
      }

      // Stress (recovery score can be used as stress indicator)
      if (item.containsKey('recovery_score')) {
        final recovery = _toNum(item['recovery_score']);
        if (recovery != null) {
          // Invert recovery score as stress (lower recovery = higher stress)
          metrics['stress'] = 100 - recovery;
        }
      }

      // Store original WHOOP data in meta for reference
      meta['whoop_data'] = item;
      meta['synced'] = true;
      meta['source_type'] = 'whoop_cloud';

      return WearMetrics(
        timestamp: timestamp,
        deviceId: 'whoop_$userId',
        source: source,
        metrics: metrics,
        meta: meta,
      );
    } catch (e) {
      logWarning('Error converting WHOOP item to WearMetrics: $e');
      return null;
    }
  }

  /// Helper to safely convert dynamic value to num
  num? _toNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value);
    }
    return null;
  }

  /// Validate data freshness (within 24 hours)
  void _validateDataFreshness(Map<String, dynamic> response, String context) {
    final latestTimestamp = _extractLatestTimestamp(response);

    if (latestTimestamp == null) {
      logWarning('⚠️ $context: Could not extract timestamp from response');
      return; // Don't fail if we can't extract timestamp
    }

    final dataAge = DateTime.now().difference(latestTimestamp);
    const maxStaleAge = Duration(hours: 24);

    // Handle timezone differences
    final isFutureData = dataAge.isNegative;
    final absoluteAge = isFutureData ? -dataAge : dataAge;

    if (absoluteAge > maxStaleAge) {
      final errorMessage =
          'WHOOP data is stale (${absoluteAge.inHours} hours old). '
          'Please check if your wearable device is connected to get latest data.';
      logWarning('❌ $context: $errorMessage');
      throw Exception(errorMessage);
    }

    if (isFutureData) {
      logWarning(
        '⏰ $context: Data timestamp is ${absoluteAge.inHours} hours in the future (likely timezone difference) - treating as valid',
      );
    } else {
      logWarning(
        '✅ $context: Data is fresh (${absoluteAge.inHours} hours old)',
      );
    }
  }

  // 4. Disconnect
  Future<void> disconnect(String userId) async {
    final uri = Uri.parse(
      '$baseUrl/v1/whoop/oauth/disconnect',
    ).replace(queryParameters: {'user_id': userId, 'app_id': appId});
    final res = await http.delete(uri);
    if (res.statusCode != 200) throw Exception(res.body);
  }
}
