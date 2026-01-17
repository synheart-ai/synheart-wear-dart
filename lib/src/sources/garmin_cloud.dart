import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/logger.dart';
import '../core/models.dart';

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
  static const String defaultBaseUrl =
      'https://synheart-wear-service-leatest.onrender.com';
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

    final serviceUrl = Uri.parse('$baseUrl/v1/garmin/oauth/authorize').replace(
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

      // Validate data freshness after connection
      try {
        logWarning('🔍 Validating data freshness after Garmin connection...');
        final testData = await _fetchData(
          'dailies',
          userID,
          DateTime.now().subtract(const Duration(days: 7)),
          DateTime.now(),
        );
        _validateDataFreshness(testData, 'Garmin connection');
        logWarning('✅ Garmin connection validated: Data is fresh');
      } catch (e) {
        logWarning('⚠️ Garmin connection data validation failed: $e');
        // Don't fail connection if validation fails, just log warning
      }

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

  /// Convenience method for connection error (matches documentation - async)
  Future<void> onConnectionError(String error) async {
    throw Exception('Garmin connection error: $error');
  }

  /// Connect method (matches documentation API)
  /// Starts OAuth flow and returns encoded state
  Future<String> connect([dynamic context]) async {
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

    final data = jsonDecode(res.body);

    // Validate data freshness
    _validateDataFreshness(data, 'Garmin $summaryType fetch');

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
      for (final key in ['records', 'items', 'results', 'summaries']) {
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
      logWarning('Error extracting timestamp from Garmin response: $e');
      return null;
    }
  }

  /// Extract timestamp from a single item (object)
  DateTime? _extractTimestampFromItem(Map<String, dynamic> item) {
    // Try common timestamp field names for Garmin
    final timestampFields = [
      'timestamp',
      'created_at',
      'start_time',
      'end_time',
      'date',
      'calendarDate',
      'startTimeInSeconds',
      'endTimeInSeconds',
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

  /// Convert Garmin API response to list of WearMetrics
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
      } else if (response.containsKey('summaries') &&
          response['summaries'] is List) {
        dataList = response['summaries'] as List;
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
      logWarning('Error converting Garmin response to WearMetrics: $e');
    }

    return metricsList;
  }

  /// Convert a single Garmin API item to WearMetrics
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

      // Extract bio signals from Garmin API response
      // Garmin dailies typically contain: steps, calories, distance, heartRate, etc.

      // Heart rate
      if (item.containsKey('averageHeartRate')) {
        metrics['hr'] = _toNum(item['averageHeartRate']);
      } else if (item.containsKey('heartRate')) {
        metrics['hr'] = _toNum(item['heartRate']);
      } else if (item.containsKey('hr')) {
        metrics['hr'] = _toNum(item['hr']);
      } else if (item.containsKey('restingHeartRate')) {
        metrics['hr'] = _toNum(item['restingHeartRate']);
      }

      // HRV
      if (item.containsKey('hrv')) {
        final hrv = _toNum(item['hrv']);
        metrics['hrv_rmssd'] = hrv;
        metrics['hrv_sdnn'] = hrv;
      } else if (item.containsKey('hrvRmssd')) {
        metrics['hrv_rmssd'] = _toNum(item['hrvRmssd']);
      } else if (item.containsKey('hrvSdnn')) {
        metrics['hrv_sdnn'] = _toNum(item['hrvSdnn']);
      } else if (item.containsKey('hrv_rmssd')) {
        metrics['hrv_rmssd'] = _toNum(item['hrv_rmssd']);
      } else if (item.containsKey('hrv_sdnn')) {
        metrics['hrv_sdnn'] = _toNum(item['hrv_sdnn']);
      }

      // Steps
      if (item.containsKey('steps')) {
        metrics['steps'] = _toNum(item['steps']);
      } else if (item.containsKey('stepCount')) {
        metrics['steps'] = _toNum(item['stepCount']);
      } else if (item.containsKey('totalSteps')) {
        metrics['steps'] = _toNum(item['totalSteps']);
      }

      // Calories
      if (item.containsKey('calories')) {
        metrics['calories'] = _toNum(item['calories']);
      } else if (item.containsKey('activeKilocalories')) {
        metrics['calories'] = _toNum(item['activeKilocalories']);
      } else if (item.containsKey('totalKilocalories')) {
        metrics['calories'] = _toNum(item['totalKilocalories']);
      }

      // Distance (Garmin typically returns in meters, convert to km)
      if (item.containsKey('distanceInMeters')) {
        final meters = _toNum(item['distanceInMeters']);
        if (meters != null) {
          metrics['distance'] = meters / 1000.0;
        }
      } else if (item.containsKey('distance')) {
        // Check if already in km or meters
        final distance = _toNum(item['distance']);
        if (distance != null) {
          // Assume meters if value is large (>1000), otherwise assume km
          metrics['distance'] = distance > 1000 ? distance / 1000.0 : distance;
        }
      }

      // Stress (from stress level or body battery)
      if (item.containsKey('stressLevel')) {
        metrics['stress'] = _toNum(item['stressLevel']);
      } else if (item.containsKey('stress')) {
        metrics['stress'] = _toNum(item['stress']);
      } else if (item.containsKey('bodyBattery')) {
        // Use body battery as inverse stress (lower battery = higher stress)
        final battery = _toNum(item['bodyBattery']);
        if (battery != null) {
          metrics['stress'] = 100 - battery;
        }
      }

      // Store original Garmin data in meta for reference
      meta['garmin_data'] = item;
      meta['synced'] = true;
      meta['source_type'] = 'garmin_cloud';

      // Store additional Garmin-specific metrics in meta
      if (item.containsKey('bodyBattery')) {
        meta['body_battery'] = item['bodyBattery'];
      }
      if (item.containsKey('vo2Max')) {
        meta['vo2_max'] = item['vo2Max'];
      }
      if (item.containsKey('fitnessAge')) {
        meta['fitness_age'] = item['fitnessAge'];
      }

      return WearMetrics(
        timestamp: timestamp,
        deviceId: 'garmin_$userId',
        source: source,
        metrics: metrics,
        meta: meta,
      );
    } catch (e) {
      logWarning('Error converting Garmin item to WearMetrics: $e');
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
          'Garmin data is stale (${absoluteAge.inHours} hours old). '
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

  // ========== Data Fetching Methods (12 Summary Types) ==========

  /// Fetch daily summaries (steps, calories, heart rate, stress, body battery)
  /// userId is optional, uses stored userId if not provided
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchDailies({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetchData('dailies', effectiveUserId, start, end);
    return _convertToWearMetricsList(response, 'garmin', effectiveUserId);
  }

  /// Fetch 15-minute granular activity periods
  /// userId is optional, uses stored userId if not provided
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchEpochs({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetchData('epochs', effectiveUserId, start, end);
    return _convertToWearMetricsList(response, 'garmin', effectiveUserId);
  }

  /// Fetch sleep data (duration, levels, scores)
  /// userId is optional, uses stored userId if not provided
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchSleeps({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetchData('sleeps', effectiveUserId, start, end);
    return _convertToWearMetricsList(response, 'garmin', effectiveUserId);
  }

  /// Fetch detailed stress values and body battery events
  /// userId is optional, uses stored userId if not provided
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchStressDetails({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetchData(
      'stressDetails',
      effectiveUserId,
      start,
      end,
    );
    return _convertToWearMetricsList(response, 'garmin', effectiveUserId);
  }

  /// Fetch heart rate variability metrics
  /// userId is optional, uses stored userId if not provided
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchHRV({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetchData('hrv', effectiveUserId, start, end);
    return _convertToWearMetricsList(response, 'garmin', effectiveUserId);
  }

  /// Fetch user metrics (VO2 Max, Fitness Age)
  /// userId is optional, uses stored userId if not provided
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchUserMetrics({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetchData(
      'userMetrics',
      effectiveUserId,
      start,
      end,
    );
    return _convertToWearMetricsList(response, 'garmin', effectiveUserId);
  }

  /// Fetch body composition (weight, BMI, body fat, etc.)
  /// userId is optional, uses stored userId if not provided
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchBodyComps({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetchData('bodyComps', effectiveUserId, start, end);
    return _convertToWearMetricsList(response, 'garmin', effectiveUserId);
  }

  /// Fetch pulse oximetry data
  /// userId is optional, uses stored userId if not provided
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchPulseOx({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetchData('pulseox', effectiveUserId, start, end);
    return _convertToWearMetricsList(response, 'garmin', effectiveUserId);
  }

  /// Fetch respiration rate data
  /// userId is optional, uses stored userId if not provided
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchRespiration({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetchData(
      'respiration',
      effectiveUserId,
      start,
      end,
    );
    return _convertToWearMetricsList(response, 'garmin', effectiveUserId);
  }

  /// Fetch health snapshot data
  /// userId is optional, uses stored userId if not provided
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchHealthSnapshot({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetchData(
      'healthSnapshot',
      effectiveUserId,
      start,
      end,
    );
    return _convertToWearMetricsList(response, 'garmin', effectiveUserId);
  }

  /// Fetch blood pressure measurements
  /// userId is optional, uses stored userId if not provided
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchBloodPressures({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetchData(
      'bloodPressures',
      effectiveUserId,
      start,
      end,
    );
    return _convertToWearMetricsList(response, 'garmin', effectiveUserId);
  }

  /// Fetch skin temperature data
  /// userId is optional, uses stored userId if not provided
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchSkinTemp({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetchData('skinTemp', effectiveUserId, start, end);
    return _convertToWearMetricsList(response, 'garmin', effectiveUserId);
  }

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

  /// Request historical Garmin data (max 90 days per request)
  /// Data is delivered asynchronously via webhooks
  ///
  /// [userId] - User ID (optional, uses stored userId if not provided)
  /// [summaryType] - One of: dailies, epochs, sleeps, stressDetails, hrv,
  ///   userMetrics, bodyComps, pulseox, respiration, healthSnapshot,
  ///   bloodPressures, skinTemp
  /// [start] - Start time (RFC3339 format)
  /// [end] - End time (RFC3339 format, max 90 days range)
  ///
  /// Returns a map with status, message, user_id, summary_type, start, and end
  Future<Map<String, dynamic>> requestBackfill({
    String? userId,
    required String summaryType,
    required DateTime start,
    required DateTime end,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }

    final uri = Uri.parse(
      '$baseUrl/v1/garmin/backfill/$effectiveUserId/$summaryType',
    );
    print('Garmin backfill request URI: $uri');
    print('Garmin backfill request URI: $uri');
    print('Garmin backfill request URI: $uri');
    print('Garmin backfill request URI: $uri');

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'app_id': appId,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
      }),
    );
    print(res.body);

    if (res.statusCode != 202) {
      throw Exception('Failed to request backfill: ${res.body}');
    }

    return jsonDecode(res.body);
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
