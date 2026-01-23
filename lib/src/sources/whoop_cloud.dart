import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/logger.dart';
import '../core/models.dart';
import 'event_subscription.dart';

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
  // static const String defaultBaseUrl = 'https://wear-service-dev.synheart.io';
  static const String defaultBaseUrl =
      'https://wear-service-synheart.onrender.com';
  static const String defaultRedirectUri = 'synheart://oauth/callback';

  String baseUrl;
  String? redirectUri;
  String appId; // REQUIRED
  String? userId;
  final bool _baseUrlExplicitlyProvided;

  WhoopProvider({
    String? baseUrl,
    String? appId,
    String? redirectUri,
    this.userId,
    bool loadFromStorage = true,
  }) : baseUrl = baseUrl ?? defaultBaseUrl,
       appId = appId ?? 'app-123',
       redirectUri = redirectUri ?? defaultRedirectUri,
       _baseUrlExplicitlyProvided = baseUrl != null {
    logDebug('🔧 WhoopProvider initialized:');
    logDebug('  baseUrl: $baseUrl');
    logDebug('  appId: $appId');
    logDebug('  redirectUri: $redirectUri');
    logDebug('  userId: $userId');
    logDebug('  loadFromStorage: $loadFromStorage');
    logDebug('  baseUrl explicitly provided: $_baseUrlExplicitlyProvided');
    if (loadFromStorage) {
      _loadFromStorage();
    }
    logDebug(
      '✅ WhoopProvider ready - final baseUrl: ${this.baseUrl}, appId: ${this.appId}',
    );
  }

  /// Load configuration and userId from local storage
  Future<void> _loadFromStorage() async {
    try {
      logDebug('💾 [STORAGE] Loading configuration from storage...');
      final prefs = await SharedPreferences.getInstance();

      // Load configuration
      final savedBaseUrl = prefs.getString(_baseUrlKey);
      final savedAppId = prefs.getString(_appIdKey);
      final savedRedirectUri = prefs.getString(_redirectUriKey);

      logDebug('💾 [STORAGE] Loaded from storage:');
      logDebug('  savedBaseUrl: $savedBaseUrl');
      logDebug('  savedAppId: $savedAppId');
      logDebug('  savedRedirectUri: $savedRedirectUri');

      if (savedBaseUrl != null) {
        // If baseUrl was explicitly provided, don't override it, but still migrate storage
        if (_baseUrlExplicitlyProvided) {
          // Migrate storage to new baseUrl if it's the old one
          if (savedBaseUrl.contains(
                'synheart-wear-service-leatest.onrender.com',
              ) ||
              savedBaseUrl != defaultBaseUrl) {
            logWarning(
              '🔄 [STORAGE] Migrating stored baseUrl (keeping explicit baseUrl)',
            );
            logWarning('  Stored (old): $savedBaseUrl');
            logWarning('  Using (explicit): $baseUrl');
            logWarning('  New default: $defaultBaseUrl');
            // Save the new baseUrl to storage for future use
            await prefs.setString(_baseUrlKey, defaultBaseUrl);
            logWarning('  ✅ Migrated stored baseUrl');
          }
          logDebug('  ✅ Keeping explicitly provided baseUrl: $baseUrl');
        } else {
          // Migrate from old baseUrl to new one
          if (savedBaseUrl.contains(
                'synheart-wear-service-leatest.onrender.com',
              ) ||
              savedBaseUrl != defaultBaseUrl) {
            logWarning(
              '🔄 [STORAGE] Migrating baseUrl from old value to new default',
            );
            logWarning('  Old: $savedBaseUrl');
            logWarning('  New: $defaultBaseUrl');
            // Update to new baseUrl
            baseUrl = defaultBaseUrl;
            // Save the new baseUrl to storage
            await prefs.setString(_baseUrlKey, defaultBaseUrl);
            logWarning('  ✅ Migrated and saved new baseUrl');
          } else {
            baseUrl = savedBaseUrl;
            logDebug('  ✅ Using saved baseUrl: $baseUrl');
          }
        }
      }
      if (savedAppId != null) {
        appId = savedAppId;
        logDebug('  ✅ Using saved appId: $appId');
      }
      if (savedRedirectUri != null) {
        redirectUri = savedRedirectUri;
        logDebug('  ✅ Using saved redirectUri: $redirectUri');
      }

      // Load userId
      final savedUserId = prefs.getString(_userIdKey);
      logDebug('  savedUserId: $savedUserId');
      if (savedUserId != null) {
        userId = savedUserId;
        logDebug('  ✅ Using saved userId: $userId');
      }
      logDebug('✅ [STORAGE] Configuration loaded successfully');
    } catch (e, stackTrace) {
      logError(
        '⚠️ [STORAGE] Failed to load from storage, using defaults',
        e,
        stackTrace,
      );
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

  // 1. Get authorization URL using new unified "Managed" OAuth endpoint
  /// Initiates OAuth connection using POST /api/v1/auth/connect/whoop
  /// Returns the authorization URL and state from backend
  Future<Map<String, String>> initiateOAuthConnection() async {
    logWarning('🔐 [AUTH] Starting initiateOAuthConnection (WHOOP)');
    logDebug('  baseUrl: $baseUrl');
    logDebug('  appId: $appId');
    logDebug('  userId: $userId');

    final serviceUrl = Uri.parse('$baseUrl/api/v1/auth/connect/whoop');

    final requestBody = {
      'app_id': appId,
      if (userId != null) 'user_id': userId!,
    };

    logWarning('📡 [AUTH] POST to: $serviceUrl');
    logDebug('📤 [AUTH] Request body: $requestBody');

    try {
      final response = await http.post(
        serviceUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      logWarning('📥 [AUTH] Response status: ${response.statusCode}');
      logDebug('📥 [AUTH] Response headers: ${response.headers}');
      logWarning('📥 [AUTH] Response body: ${response.body}');

      if (response.statusCode != 200) {
        logError(
          '❌ [AUTH] Failed to initiate WHOOP OAuth connection',
          Exception('Status ${response.statusCode}'),
          StackTrace.current,
        );
        throw Exception(
          'Failed to initiate WHOOP OAuth connection (${response.statusCode}): ${response.body}',
        );
      }

      final json = jsonDecode(response.body);
      logDebug('📋 [AUTH] Parsed JSON response: $json');

      final String? authorizationUrl = json['authorization_url'] as String?;
      final String? state = json['state'] as String?;

      if (authorizationUrl == null || authorizationUrl.isEmpty) {
        logError(
          '❌ [AUTH] authorization_url is missing in response',
          Exception('Empty authorization_url'),
          StackTrace.current,
        );
        throw Exception('authorization_url is missing in response');
      }

      if (state == null || state.isEmpty) {
        logError(
          '❌ [AUTH] state is missing in response',
          Exception('Empty state'),
          StackTrace.current,
        );
        throw Exception('state is missing in response');
      }

      logWarning(
        '✅ [AUTH] Successfully obtained WHOOP authorization URL and state',
      );
      return {'authorization_url': authorizationUrl, 'state': state};
    } catch (e, stackTrace) {
      logError('❌ [AUTH] Error in initiateOAuthConnection: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Start OAuth flow: initiate connection, get URL, and launch browser
  /// Returns the state string from backend for tracking the OAuth callback
  Future<String> startOAuthFlow() async {
    logWarning('🚀 [AUTH] Starting OAuth flow (WHOOP)');

    try {
      final result = await initiateOAuthConnection();
      final authorizationUrl = result['authorization_url']!;
      final state = result['state']!;

      logWarning(
        '🌐 [AUTH] Obtained WHOOP URL, attempting to launch browser...',
      );
      logWarning('  URL: $authorizationUrl');
      logWarning(
        '  State: ${state.substring(0, state.length > 30 ? 30 : state.length)}...',
      );

      final launched = await launchUrl(
        Uri.parse(authorizationUrl),
        mode: LaunchMode.externalApplication,
      );

      logWarning('📱 [AUTH] Browser launch result: $launched');

      if (!launched) {
        logError(
          '❌ [AUTH] Cannot open browser',
          Exception('Browser launch failed'),
          StackTrace.current,
        );
        throw Exception('Cannot open browser');
      }

      logWarning(
        '✅ [AUTH] OAuth flow started successfully, state: ${state.substring(0, 30)}...',
      );
      return state;
    } catch (e, stackTrace) {
      logError('❌ [AUTH] Error in startOAuthFlow: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Connect method (matches documentation API)
  /// Starts OAuth flow and returns state
  Future<String> connect([dynamic context]) async {
    logDebug('🔌 [AUTH] connect() called');
    try {
      final state = await startOAuthFlow();
      logDebug('✅ [AUTH] connect() completed, state: $state');
      return state;
    } catch (e, stackTrace) {
      logError('❌ [AUTH] Error in connect(): $e', e, stackTrace);
      rethrow;
    }
  }

  /// Handle OAuth callback from deep link
  /// Backend handles code exchange automatically and redirects to app's redirect_uri
  /// Deep link format: myapp://callback?status=success&user_id=xxx
  /// or: myapp://callback?status=error&error=error_message
  Future<String?> handleDeepLinkCallback(Uri uri) async {
    logWarning('🔄 [AUTH] Handling deep link callback (WHOOP)');
    logWarning('  URI: $uri');

    // Extract status and user_id from deep link
    final status = uri.queryParameters['status'];
    final userID = uri.queryParameters['user_id'];
    final error = uri.queryParameters['error'];

    logWarning('🔍 [AUTH] Callback parameters:');
    logWarning('  status: $status');
    logWarning('  userID: $userID');
    logWarning('  error: $error');

    if (status == 'success' && userID != null) {
      logWarning('✅ [AUTH] Connection successful, saving userId: $userID');
      await saveUserId(userID);
      logWarning('💾 [AUTH] userId saved successfully');

      // Validate data freshness after connection
      try {
        logDebug(
          '🔍 [AUTH] Validating data freshness after WHOOP connection...',
        );
        final testData = await _fetch(
          'recovery',
          userID,
          DateTime.now().subtract(const Duration(days: 7)),
          DateTime.now(),
          1, // Just fetch 1 record to check freshness
          null,
        );
        _validateDataFreshness(testData, 'WHOOP connection');
        logDebug('✅ [AUTH] WHOOP connection validated: Data is fresh');
      } catch (e, stackTrace) {
        logWarning('⚠️ [AUTH] WHOOP connection data validation failed: $e');
        logError('⚠️ [AUTH] Validation error details', e, stackTrace);
        // Don't fail connection if validation fails, just log warning
      }

      logWarning(
        '✅ [AUTH] handleDeepLinkCallback completed successfully, userId: $userID',
      );
      return userID;
    } else if (status == 'error' || error != null) {
      // Connection failed
      final errorMessage = error ?? 'Unknown error';
      logError(
        '❌ [AUTH] OAuth callback failed: $errorMessage',
        Exception(errorMessage),
        StackTrace.current,
      );
      throw Exception('OAuth callback failed: $errorMessage');
    }

    logWarning('⚠️ [AUTH] Callback missing status/userID or error');
    return null;
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
      '$baseUrl/api/v1/whoop/data/$userId/$type',
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
      '$baseUrl/api/v1/whoop/oauth/disconnect',
    ).replace(queryParameters: {'user_id': userId, 'app_id': appId});
    final res = await http.delete(uri);
    if (res.statusCode != 200) throw Exception(res.body);
  }

  /// Subscribe to real-time events via SSE
  ///
  /// Per documentation: GET /api/v1/events/subscribe?app_id={app_id}
  ///
  /// Optional parameters:
  /// - userId: Filter events for specific user
  /// - vendors: List of vendors to filter (defaults to ['whoop'])
  ///
  /// Returns a stream of WearServiceEvent objects.
  ///
  /// Example:
  /// ```dart
  /// provider.subscribeToEvents(userId: 'user-456')
  ///   .listen((event) {
  ///     print('Received ${event.event} event: ${event.data}');
  ///   });
  /// ```
  Stream<WearServiceEvent> subscribeToEvents({
    String? userId,
    List<String>? vendors,
  }) {
    final subscriptionService = EventSubscriptionService(
      baseUrl: baseUrl,
      appId: appId,
    );
    return subscriptionService.subscribe(
      userId: userId ?? this.userId,
      vendors: vendors ?? ['whoop'],
    );
  }
}
