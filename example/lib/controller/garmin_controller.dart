import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:synheart_wear/synheart_wear.dart';

class GarminController extends ChangeNotifier {
  // ──────────────────────────────────────────────────────────────
  // Configuration
  // ──────────────────────────────────────────────────────────────
  static String get defaultBaseUrl => GarminProvider.defaultBaseUrl;
  static String get defaultRedirectUri => GarminProvider.defaultRedirectUri;

  // Configuration getters that read from provider
  String get baseUrl => _provider.baseUrl;
  String get appId => _provider.appId;
  String get redirectUri => _provider.redirectUri ?? defaultRedirectUri;

  // ──────────────────────────────────────────────────────────────
  // Dependencies
  // ──────────────────────────────────────────────────────────────
  late GarminProvider _provider;
  GarminProvider get provider => _provider;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<WearServiceEvent>? _sseSubscription;

  // ──────────────────────────────────────────────────────────────
  // State
  // ──────────────────────────────────────────────────────────────
  String? _userId;
  String _status = 'Not connected';
  String _error = '';
  List<WearMetrics>? _data;
  String? _pendingOAuthState;
  String? _currentDataType; // Track what type of data we're displaying
  bool _isSSESubscribed = false;
  List<WearServiceEvent> _sseEvents = []; // Store recent SSE/webhook events
  Map<String, dynamic> _backfillData = {}; // Store backfill data by type

  // ──────────────────────────────────────────────────────────────
  // Getters
  // ──────────────────────────────────────────────────────────────
  String? get userId => _userId;
  String get status => _status;
  String get error => _error;
  List<WearMetrics>? get data => _data;
  String? get currentDataType => _currentDataType;
  /// Garmin connection is tracked only by Garmin OAuth (garmin_user_id in storage).
  /// Do not infer from WHOOP or a shared user ID; user must authenticate Garmin separately.
  bool get isConnected => _userId != null;
  bool get isSSESubscribed => _isSSESubscribed;
  List<WearServiceEvent> get sseEvents => _sseEvents;
  Map<String, dynamic> get backfillData => _backfillData;

  // ──────────────────────────────────────────────────────────────
  // Initialization
  // ──────────────────────────────────────────────────────────────
  GarminController() {
    _appLinks = AppLinks();
  }

  Future<void> initialize() async {
    _initializeProvider();
    await _setupDeepLinkListener();
    // Load saved user ID after the first frame (gives platform channels time to initialize)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserId();
    });
  }

  void _initializeProvider() {
    _provider = GarminProvider(loadFromStorage: true);
    debugPrint(
        '📋 Loaded Garmin configuration: baseUrl=${_provider.baseUrl}, appId=${_provider.appId}, redirectUri=${_provider.redirectUri}');
  }

  Future<void> reloadConfiguration() async {
    await _provider.reloadFromStorage();
    notifyListeners();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _sseSubscription?.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  // Deep Link Handling
  // ──────────────────────────────────────────────────────────────
  Future<void> _setupDeepLinkListener() async {
    // Handle app launch from deep link (cold start)
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) _handleIncomingLink(initialUri);

    // Handle when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (err) => debugPrint('Deep link error: $err'),
    );
  }

  Future<void> _handleIncomingLink(Uri uri) async {
    debugPrint('🔗 Garmin deep link received: $uri');
    debugPrint('   Full URI string: ${uri.toString()}');
    debugPrint('   Query parameters: ${uri.queryParameters}');
    debugPrint('   Query string: ${uri.query}');
    debugPrint('   Has query: ${uri.hasQuery}');

    // Check URI scheme, host, and path first (like WHOOP does)
    if (uri.scheme != 'synheart' ||
        uri.host != 'oauth' ||
        uri.path != '/callback') {
      debugPrint('⚠️  Ignoring non-OAuth deep link in Garmin controller');
      return;
    }

    // Check callback parameters
    final hasCodeAndState = uri.queryParameters.containsKey('code') &&
        uri.queryParameters.containsKey('state');
    final hasGarminParams = uri.queryParameters.containsKey('success') ||
        uri.queryParameters.containsKey('user_id');

    // If this has code/state but no Garmin params, it could be:
    // 1. A WHOOP callback (ignore it)
    // 2. A Garmin intermediate callback (backend handles it)
    if (hasCodeAndState && !hasGarminParams) {
      // If we have a pending Garmin OAuth state, this is likely a Garmin intermediate callback
      // The backend should receive the callback from Garmin and process it
      // Then the backend will redirect to the app with success=true&user_id=xxx
      if (_pendingOAuthState != null) {
        final code = uri.queryParameters['code'];
        final state = uri.queryParameters['state'];

        if (code == null || state == null) {
          debugPrint('❌ Missing code or state in Garmin callback');
          return;
        }

        debugPrint(
            '⏳ Garmin callback received (code/state) - backend should handle it');
        debugPrint(
            '   Code: ${code.substring(0, code.length > 20 ? 20 : code.length)}...');
        debugPrint(
            '   State: ${state.substring(0, state.length > 50 ? 50 : state.length)}...');
        debugPrint(
            '   Note: Backend receives callback from Garmin and will redirect to app');

        _updateState(
          status: 'Processing Garmin authorization...',
          error: 'Waiting for backend to process callback...',
        );

        // The backend should receive the callback from Garmin and process it
        // Then it will redirect to the app with success=true&user_id=xxx
        // We'll periodically check if the connection was successful
        _checkConnectionStatusPeriodically();

        return;
      } else {
        // No pending Garmin state - this is likely a WHOOP callback
        debugPrint('⚠️  Ignoring WHOOP callback in Garmin controller');
        return;
      }
    }

    // Extract Garmin-specific parameters to check before processing
    final success = uri.queryParameters['success'];
    final userID = uri.queryParameters['user_id'];
    final error = uri.queryParameters['error'];

    debugPrint('   Extracted parameters:');
    debugPrint('   - success: $success');
    debugPrint('   - user_id: $userID');
    debugPrint('   - error: $error');
    debugPrint('   - pendingOAuthState: $_pendingOAuthState');

    // Check if this is a Garmin callback - at this point we've already handled intermediate callbacks
    // So if we don't have success/user_id/error, it's an incomplete callback
    if (success == null && userID == null && error == null) {
      debugPrint(
          '⚠️  Ignoring incomplete Garmin callback - missing success/user_id/error');
      if (_pendingOAuthState != null) {
        debugPrint(
            '   Waiting for backend redirect with success/user_id parameters...');
      }
      return;
    }

    // Only process this callback if WE started the OAuth flow (pending state).
    // The same deep link is delivered to both WHOOP and Garmin controllers; we must
    // not process a callback that was meant for the other provider.
    final statusParam = uri.queryParameters['status'];
    if (_pendingOAuthState == null) {
      debugPrint(
          '⚠️  No pending Garmin OAuth state - ignoring (callback may be for WHOOP)');
      debugPrint(
          '   Success: $success Status: $statusParam User ID: $userID');
      // If we already have a saved Garmin user ID, just ensure UI is in sync
      final savedUserId = await _provider.loadUserId();
      if (savedUserId != null && savedUserId.isNotEmpty) {
        _updateState(
          userId: savedUserId,
          status: 'Connected (restored from storage)',
          error: '',
        );
      }
      return;
    }

    if (_userId != null && _pendingOAuthState != null) {
      debugPrint(
          '⚠️  Already connected but received Garmin OAuth callback. Processing...');
    }

    debugPrint('✅ Garmin OAuth callback received (managed flow)');
    debugPrint('   Status: $statusParam Success: $success User ID: $userID');
    debugPrint('   Error: $error');
    debugPrint('   Client state (for reference): $_pendingOAuthState');

    _updateState(
      status: 'Processing connection...',
      error: '',
    );

    try {
      // Use the provider's handleDeepLinkCallback which checks success=true&user_id
      final userId = await _provider.handleDeepLinkCallback(uri);

      if (userId != null) {
        debugPrint('✅ Garmin connection successful: $userId');
        _pendingOAuthState = null;
        // User ID is already saved by handleDeepLinkCallback

        _updateState(
          userId: userId,
          status: 'Connected successfully!',
          error: '',
        );
      } else {
        // This shouldn't happen if status=success, but handle it anyway
        debugPrint('⚠️  Garmin callback returned null user ID');
        debugPrint('   Status parameter: $statusParam');
        debugPrint('   User ID parameter: $userID');
        _pendingOAuthState = null;
        _updateState(
          error: 'Connection failed: No user ID received',
          status: 'Connection failed',
        );
      }
    } catch (e) {
      debugPrint('❌ Garmin OAuth callback error: $e');
      _pendingOAuthState = null;

      String errorMsg = e.toString();
      if (errorMsg.contains('OAuth callback failed')) {
        // Extract the actual error message from the exception
        errorMsg =
            errorMsg.replaceAll('Exception: OAuth callback failed: ', '');
      }

      _updateState(
        error: errorMsg,
        status: 'Connection failed',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // State Management
  // ──────────────────────────────────────────────────────────────
  void _updateState({
    String? userId,
    String? status,
    String? error,
    List<WearMetrics>? data,
    String? dataType,
    bool clearUserId = false,
    bool clearDataType = false,
    bool clearData = false,
  }) {
    bool changed = false;

    if (clearUserId) {
      _userId = null;
      changed = true;
    } else if (userId != null && userId != _userId) {
      _userId = userId;
      changed = true;
    }
    if (status != null && status != _status) {
      _status = status;
      changed = true;
    }
    if (error != null && error != _error) {
      _error = error;
      changed = true;
    }
    if (clearData) {
      _data = null;
      changed = true;
    } else if (data != null) {
      _data = data;
      changed = true;
    }
    if (clearDataType) {
      _currentDataType = null;
      changed = true;
    } else if (dataType != null && dataType != _currentDataType) {
      _currentDataType = dataType;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  // ──────────────────────────────────────────────────────────────
  // OAuth Connection
  // ──────────────────────────────────────────────────────────────
  Future<void> connect() async {
    _updateState(
      status: 'Preparing Garmin login...',
      error: '',
    );

    debugPrint('🔐 Starting Garmin OAuth flow');
    debugPrint('   Base URL: ${_provider.baseUrl}');
    debugPrint('   App ID: ${_provider.appId}');
    debugPrint('   Redirect URI: ${_provider.redirectUri}');
    debugPrint(
        '   Full URL will be: ${_provider.baseUrl}/v1/garmin/oauth/authorize');

    try {
      final result = await _provider.startOAuthFlow();
      debugPrint('🔐 OAuth flow started successfully');
      debugPrint('   Result: $result');
      _pendingOAuthState = result['state'];
      debugPrint(
          '🔐 Started Garmin OAuth flow with state: $_pendingOAuthState');

      _updateState(status: 'Log in to Garmin in the browser...');
    } catch (e, stackTrace) {
      debugPrint('❌ Garmin OAuth flow failed');
      debugPrint('   Error: $e');
      debugPrint('   Error type: ${e.runtimeType}');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        debugPrint('   This is a network connectivity issue');
        debugPrint('   Please check:');
        debugPrint('     1. Your internet connection');
        debugPrint('     2. Base URL is correct: ${_provider.baseUrl}');
        debugPrint('     3. The server is accessible');
      }
      debugPrint('   Stack trace: $stackTrace');
      _pendingOAuthState = null;
      final errorMessage = _extractErrorMessage(e.toString());
      debugPrint('   Extracted error message: $errorMessage');
      _updateState(
        error: errorMessage,
        status: 'Login failed',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Error Handling
  // ──────────────────────────────────────────────────────────────
  String _extractErrorMessage(String error) {
    // Check if error contains HTML
    if (error.contains('<html') || error.contains('<!DOCTYPE')) {
      // Try to extract meaningful error from HTML
      if (error.contains('404') || error.toLowerCase().contains('not found')) {
        return 'Server not found. Please check your Base URL configuration.';
      }
      if (error.contains('500') ||
          error.toLowerCase().contains('internal server error')) {
        return 'Server error. Please check your Base URL and try again.';
      }
      if (error.contains('400') ||
          error.toLowerCase().contains('bad request')) {
        return 'Invalid request. Please check your configuration settings.';
      }
      if (error.contains('403') || error.toLowerCase().contains('forbidden')) {
        return 'Access forbidden. Please check your App ID.';
      }
      if (error.contains('401') ||
          error.toLowerCase().contains('unauthorized')) {
        return 'Unauthorized. Please check your App ID.';
      }

      return 'Invalid server response. Please check your Base URL configuration in Settings.';
    }

    // Check for common connection errors
    if (error.toLowerCase().contains('failed host lookup') ||
        error.toLowerCase().contains('socketexception') ||
        error.toLowerCase().contains('network is unreachable')) {
      return 'Cannot connect to server. The Base URL "${_provider.baseUrl}" cannot be reached.\n\nPlease go to Settings and update the Base URL (e.g., https://synheart-wear-service-leatest.onrender.com)';
    }

    if (error.toLowerCase().contains('invalid url') ||
        error.toLowerCase().contains('malformed')) {
      return 'Invalid Base URL. Please check your configuration in Settings.';
    }

    // Return original error if it's already user-friendly
    return error;
  }

  // ──────────────────────────────────────────────────────────────
  // Local Storage
  // ──────────────────────────────────────────────────────────────
  /// Restore Garmin connection state from storage (garmin_user_id only). Never use WHOOP's user ID.
  Future<void> _loadUserId() async {
    final savedUserId = await _provider.loadUserId();
    if (savedUserId != null && savedUserId.isNotEmpty) {
      _updateState(
        userId: savedUserId,
        status: 'Connected (restored from storage)',
      );
      debugPrint('📂 Loaded Garmin user ID from local storage: $savedUserId');
    } else {
      debugPrint('📂 No saved Garmin user ID found in local storage');
    }
  }

  Future<void> clearUserId() async {
    await _provider.clearUserId();
    debugPrint('🗑️  Cleared Garmin user ID from local storage');
  }

  /// Periodically check if the backend has processed the callback and saved the user ID
  void _checkConnectionStatusPeriodically() {
    // Check immediately
    Future.delayed(const Duration(seconds: 1), () async {
      if (_pendingOAuthState != null) {
        final savedUserId = await _provider.loadUserId();
        if (savedUserId != null && savedUserId.isNotEmpty) {
          debugPrint(
              '✅ Connection successful! Found saved user ID: $savedUserId');
          _pendingOAuthState = null;
          _updateState(
            userId: savedUserId,
            status: 'Connected successfully!',
            error: '',
          );
          return;
        }
      }
    });

    // Check after 3 seconds
    Future.delayed(const Duration(seconds: 3), () async {
      if (_pendingOAuthState != null) {
        final savedUserId = await _provider.loadUserId();
        if (savedUserId != null && savedUserId.isNotEmpty) {
          debugPrint('✅ Connection successful on retry! User ID: $savedUserId');
          _pendingOAuthState = null;
          _updateState(
            userId: savedUserId,
            status: 'Connected successfully!',
            error: '',
          );
          return;
        }
      }
    });

    // Final check after 5 seconds
    Future.delayed(const Duration(seconds: 5), () async {
      if (_pendingOAuthState != null) {
        final savedUserId = await _provider.loadUserId();
        if (savedUserId != null && savedUserId.isNotEmpty) {
          debugPrint(
              '✅ Connection successful on final check! User ID: $savedUserId');
          _pendingOAuthState = null;
          _updateState(
            userId: savedUserId,
            status: 'Connected successfully!',
            error: '',
          );
        } else {
          debugPrint('⚠️  Backend has not processed the callback yet');
          debugPrint('   This may indicate:');
          debugPrint('   1. Garmin redirect URI is not configured correctly');
          debugPrint('   2. Backend did not receive the callback from Garmin');
          debugPrint('   3. Backend is still processing the callback');
          _updateState(
            status: 'Waiting for backend...',
            error:
                'Backend is processing the callback. This may take a few moments.',
          );
        }
      }
    });
  }

  // ──────────────────────────────────────────────────────────────
  // Data Fetching
  // ──────────────────────────────────────────────────────────────
  /// Fetch Garmin daily summaries
  /// Note: Subscription to events is automatically ensured before fetching
  Future<void> fetchDailies({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Subscribing and fetching daily summaries...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchDailies(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(hours: 8)),
        end: end ?? DateTime.now(),
      );

      _updateState(
        data: result,
        dataType: 'dailies',
        status: 'Daily summaries loaded',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  /// Fetch Garmin sleep data
  /// Note: Subscription to events is automatically ensured before fetching
  Future<void> fetchSleeps({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Subscribing and fetching sleep data...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchSleeps(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(hours: 8)),
        end: end ?? DateTime.now(),
      );

      _updateState(
        data: result,
        dataType: 'sleeps',
        status: 'Sleep data loaded',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  Future<void> fetchHRV({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching HRV data...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchHRV(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(hours: 8)),
        end: end ?? DateTime.now(),
      );

      _updateState(
        data: result,
        dataType: 'hrv',
        status: 'HRV data loaded',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  Future<void> fetchEpochs({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching epoch data...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchEpochs(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(days: 7)),
        end: end ?? DateTime.now(),
      );

      _updateState(
        data: result,
        dataType: 'epochs',
        status: 'Epoch data loaded',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  Future<void> fetchStressDetails({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching stress details...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchStressDetails(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(hours: 8)),
        end: end ?? DateTime.now(),
      );

      _updateState(
        data: result,
        dataType: 'stressDetails',
        status: 'Stress details loaded',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  Future<void> fetchUserMetrics({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching user metrics...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchUserMetrics(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(hours: 8)),
        end: end ?? DateTime.now(),
      );

      _updateState(
        data: result,
        dataType: 'userMetrics',
        status: 'User metrics loaded',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  Future<void> fetchBodyComps({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching body composition...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchBodyComps(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(hours: 8)),
        end: end ?? DateTime.now(),
      );

      _updateState(
        data: result,
        dataType: 'bodyComps',
        status: 'Body composition loaded',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  Future<void> fetchPulseOx({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching pulse oximetry...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchPulseOx(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(hours: 8)),
        end: end ?? DateTime.now(),
      );

      _updateState(
        data: result,
        dataType: 'pulseox',
        status: 'Pulse oximetry loaded',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  Future<void> fetchRespiration({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching respiration data...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchRespiration(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(hours: 8)),
        end: end ?? DateTime.now(),
      );

      _updateState(
        data: result,
        dataType: 'respiration',
        status: 'Respiration data loaded',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  Future<void> fetchHealthSnapshot({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching health snapshot...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchHealthSnapshot(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(hours: 8)),
        end: end ?? DateTime.now(),
      );

      _updateState(
        data: result,
        dataType: 'healthSnapshot',
        status: 'Health snapshot loaded',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  Future<void> fetchBloodPressures({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching blood pressure...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchBloodPressures(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(hours: 8)),
        end: end ?? DateTime.now(),
      );

      _updateState(
        data: result,
        dataType: 'bloodPressures',
        status: 'Blood pressure loaded',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  Future<void> fetchSkinTemp({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching skin temperature...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchSkinTemp(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(hours: 8)),
        end: end ?? DateTime.now(),
      );

      _updateState(
        data: result,
        dataType: 'skinTemp',
        status: 'Skin temperature loaded',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Backfill (Historical Data)
  // ──────────────────────────────────────────────────────────────
  /// Request historical Garmin data (max 90 days per request)
  /// Data is delivered asynchronously via webhooks
  Future<void> requestBackfill({
    required String summaryType,
    required DateTime start,
    required DateTime end,
  }) async {
    if (_userId == null) return;

    // Validate date range (max 90 days)
    final daysDifference = end.difference(start).inDays;
    if (daysDifference > 90) {
      _updateState(
        error:
            'Date range cannot exceed 90 days. Please select a smaller range.',
        status: 'Invalid date range',
      );
      return;
    }

    if (daysDifference < 0) {
      _updateState(
        error: 'Start date must be before end date.',
        status: 'Invalid date range',
      );
      return;
    }

    _updateState(
      status: 'Subscribing and requesting historical data (backfill)...',
      error: '',
    );

    try {
      final result = await _provider.requestBackfill(
        userId: _userId!,
        summaryType: summaryType,
        start: start,
        end: end,
      );

      _updateState(
        status:
            'Backfill request accepted! Data will be delivered via webhooks.',
        error: '',
      );

      debugPrint('✅ Backfill request successful: $result');
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Backfill request failed',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // SSE Event Subscription (Webhooks)
  // ──────────────────────────────────────────────────────────────

  /// Subscribe to real-time events via SSE
  /// This allows receiving webhook data from backfill requests
  Future<void> subscribeToEvents() async {
    if (_isSSESubscribed) {
      debugPrint('⚠️  Already subscribed to SSE events');
      return;
    }

    if (_userId == null) {
      debugPrint('⚠️  Cannot subscribe to SSE: Not connected');
      _updateState(
        error: 'Must be connected before subscribing to events',
        status: 'Subscription failed',
      );
      return;
    }

    try {
      debugPrint('📡 Subscribing to SSE events...');
      _updateState(status: 'Subscribing to real-time events...', error: '');

      _sseSubscription = _provider.subscribeToEvents(userId: _userId).listen(
        (event) {
          debugPrint('📨 SSE Event received: ${event.event}');
          debugPrint('   ID: ${event.id}');
          debugPrint('   Data: ${event.data}');

          // Add to events list (keep last 100 events)
          _sseEvents.insert(0, event);
          if (_sseEvents.length > 100) {
            _sseEvents = _sseEvents.take(100).toList();
          }

          // Handle different event types
          _handleSSEEvent(event);

          notifyListeners();
        },
        onError: (error) {
          final errorMessage = error.toString();
          debugPrint('❌ SSE subscription error: $error');

          // Check if it's a connection closure (not a real error)
          if (errorMessage.contains('Connection closed') ||
              errorMessage.contains('Connection terminated')) {
            debugPrint(
                '⚠️ SSE connection closed (may reconnect automatically)');
            _isSSESubscribed = false;
            _updateState(
              status: 'SSE connection closed - will reconnect',
              error: '',
            );
            notifyListeners();

            // Attempt to reconnect after a delay
            Future.delayed(const Duration(seconds: 3), () {
              if (isConnected && !_isSSESubscribed) {
                debugPrint('🔄 Attempting to reconnect SSE...');
                subscribeToEvents();
              }
            });
          } else {
            // Real error
            _isSSESubscribed = false;
            _updateState(
              error:
                  'SSE subscription error: ${_extractErrorMessage(errorMessage)}',
              status: 'SSE connection lost',
            );
            notifyListeners();
          }
        },
        onDone: () {
          debugPrint('🔌 SSE subscription closed');
          _isSSESubscribed = false;
          _updateState(
            status: 'SSE subscription closed',
            error: '',
          );
          notifyListeners();
        },
      );

      _isSSESubscribed = true;
      _updateState(
        status: 'Subscribed to real-time events',
        error: '',
      );
      debugPrint('✅ Successfully subscribed to SSE events');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to subscribe to SSE: $e');
      _isSSESubscribed = false;
      _updateState(
        error: 'Failed to subscribe: ${_extractErrorMessage(e.toString())}',
        status: 'Subscription failed',
      );
      notifyListeners();
    }
  }

  /// Unsubscribe from SSE events
  Future<void> unsubscribeFromEvents() async {
    if (!_isSSESubscribed) {
      debugPrint('⚠️  Not subscribed to SSE events');
      return;
    }

    try {
      debugPrint('🔌 Unsubscribing from SSE events...');
      await _sseSubscription?.cancel();
      _sseSubscription = null;
      _isSSESubscribed = false;
      _updateState(
        status: 'SSE subscription cancelled',
        error: '',
      );
      debugPrint('✅ Successfully unsubscribed from SSE events');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to unsubscribe from SSE: $e');
      _updateState(
        error: 'Failed to unsubscribe: ${_extractErrorMessage(e.toString())}',
      );
      notifyListeners();
    }
  }

  /// Handle incoming SSE events (webhook data)
  void _handleSSEEvent(WearServiceEvent event) {
    if (event.event == 'connected') {
      debugPrint('✅ SSE connection confirmed');
      debugPrint('   Client ID: ${event.data?['client_id']}');
      debugPrint('   App ID: ${event.data?['app_id']}');
      return;
    }

    // Handle Garmin-specific events (backfill data)
    if (event.data?['vendor'] == 'garmin') {
      final eventType = event.event;
      final userId = event.data?['user_id'];
      final data = event.data?['data'];

      debugPrint('📊 Garmin event: $eventType for user: $userId');

      // Store backfill data by type
      if (userId == _userId && data != null && eventType != null) {
        _backfillData[eventType] = data;
        debugPrint('💾 Stored backfill data for: $eventType');
        debugPrint(
            '   Data preview: ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}...');

        // Update status to show data was received
        _updateState(
          status: 'Received $eventType data via webhook',
          error: '',
        );
      }
    }
  }

  /// Clear SSE events history
  void clearSSEEvents() {
    _sseEvents.clear();
    notifyListeners();
  }

  /// Clear backfill data
  void clearBackfillData() {
    _backfillData.clear();
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────
  // Flux Processing
  // ──────────────────────────────────────────────────────────────
  /// Test Flux processing with Garmin data
  Future<void> testFluxProcessing(BuildContext context) async {
    if (!isConnected) {
      _updateState(
        error: 'Please connect to Garmin first',
        status: 'Not connected',
      );
      return;
    }

    try {
      // Debug info
      debugPrint('🔍 [Flux Debug] Garmin Flux Processing:');
      debugPrint('  User ID: $_userId');
      debugPrint('  Is Connected: $isConnected');
      debugPrint('  Base URL: ${_provider.baseUrl}');
      debugPrint('  App ID: ${_provider.appId}');
      debugPrint('  Provider User ID: ${_provider.userId}');

      _updateState(
        status: 'Subscribing and fetching Garmin data for Flux...',
        error: '',
      );

      // Fetch raw data for Flux
      // Note: Subscription to events is automatically ensured before fetching
      final startDate = DateTime.now().subtract(const Duration(hours: 8));
      final endDate = DateTime.now();
      debugPrint('  Date Range: $startDate to $endDate');

      // Fetch raw data for Flux
      final rawData = await _provider.fetchRawDataForFlux(
        userId: _userId,
        start: startDate,
        end: endDate,
      );

      debugPrint('📊 Raw Garmin data preview:');
      debugPrint('  Dailies: ${rawData['dailies']?.length ?? 0} records');
      debugPrint('  Sleeps: ${rawData['sleep']?.length ?? 0} records');

      // Check Flux availability
      if (!FluxProcessor.isFluxAvailable) {
        throw Exception(
          'Flux is not available. Please ensure the native library is bundled.',
        );
      }

      _updateState(
        status: 'Processing with Flux...',
        error: '',
      );

      // Process with Flux
      final rawJson = jsonEncode(rawData);
      final wear = SynheartWear(
        config: const SynheartWearConfig(enableFlux: true),
      );
      final hsiSnapshot = await wear.readFluxSnapshot(
        rawVendorJson: rawJson,
        vendor: Vendor.garmin,
        timezone: 'UTC',
        deviceId: 'garmin-device-${_userId}',
      );

      debugPrint('✅ Flux processing complete!');
      debugPrint('📊 HSI Result Summary:');
      debugPrint('  Version: ${hsiSnapshot.hsiVersion}');
      debugPrint('  Windows: ${hsiSnapshot.windows.length}');
      debugPrint('  Observed At: ${hsiSnapshot.observedAtUtc}');
      debugPrint('  Computed At: ${hsiSnapshot.computedAtUtc}');

      // Print window details from meta (wearable format)
      final meta = hsiSnapshot.meta;
      if (meta.containsKey('wearable_windows')) {
        final wearableWindows =
            meta['wearable_windows'] as Map<String, dynamic>?;
        if (wearableWindows != null && wearableWindows.isNotEmpty) {
          debugPrint('\n📅 Windows:');
          wearableWindows.forEach((windowId, windowData) {
            if (windowData is Map<String, dynamic>) {
              debugPrint('  Window: $windowId');
              final sleep = windowData['sleep'] as Map<String, dynamic>?;
              final physiology =
                  windowData['physiology'] as Map<String, dynamic>?;
              final activity = windowData['activity'] as Map<String, dynamic>?;

              if (sleep != null) {
                debugPrint('    Sleep:');
                if (sleep['duration_minutes'] != null) {
                  debugPrint(
                      '      Duration: ${(sleep['duration_minutes'] as num).toStringAsFixed(1)} min');
                }
                if (sleep['score'] != null) {
                  debugPrint(
                      '      Score: ${((sleep['score'] as num) * 100).toStringAsFixed(0)}');
                }
              }
              if (physiology != null) {
                debugPrint('    Physiology:');
                if (physiology['resting_hr_bpm'] != null) {
                  debugPrint(
                      '      Resting HR: ${(physiology['resting_hr_bpm'] as num).toStringAsFixed(0)} bpm');
                }
                if (physiology['hrv_rmssd_ms'] != null) {
                  debugPrint(
                      '      HRV: ${(physiology['hrv_rmssd_ms'] as num).toStringAsFixed(1)} ms');
                }
              }
              if (activity != null) {
                debugPrint('    Activity:');
                if (activity['steps'] != null) {
                  debugPrint('      Steps: ${activity['steps']}');
                }
                if (activity['calories'] != null) {
                  debugPrint(
                      '      Calories: ${(activity['calories'] as num).toStringAsFixed(0)}');
                }
              }
            }
          });
        }
      }

      debugPrint('=' * 80);

      // Show HSI result in dialog
      if (context.mounted) {
        _showHsiResultDialog(context, hsiSnapshot);
      }

      _updateState(
        status: 'Flux processing complete',
        error: '',
      );
    } catch (e, stackTrace) {
      final errorMsg = 'Error in Flux processing: $e';
      debugPrint('❌ $errorMsg');
      debugPrint('Stack trace: $stackTrace');

      // Check if it's a 404 error and suggest backfill
      String userFriendlyError = errorMsg;
      if (errorMsg.contains('404')) {
        userFriendlyError = 'No Garmin data found. '
            'You may need to request a backfill first to sync your Garmin data.\n\n'
            'Error details: $errorMsg';
      }

      _updateState(
        error: userFriendlyError,
        status: 'Flux processing failed',
      );
    }
  }

  void _showHsiResultDialog(BuildContext context, HsiPayload hsiSnapshot) {
    final meta = hsiSnapshot.meta;
    final wearableWindows = meta['wearable_windows'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'HSI Result',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info
                      _buildSection(
                        'Basic Info',
                        [
                          _buildInfoRow('Version', hsiSnapshot.hsiVersion),
                          _buildInfoRow(
                              'Observed At', hsiSnapshot.observedAtUtc),
                          _buildInfoRow(
                              'Computed At', hsiSnapshot.computedAtUtc),
                          _buildInfoRow(
                            'Producer',
                            '${hsiSnapshot.producer.name} v${hsiSnapshot.producer.version}',
                          ),
                          _buildInfoRow(
                              'Windows', '${hsiSnapshot.windows.length}'),
                        ],
                      ),
                      // Wearable Data
                      if (wearableWindows != null && wearableWindows.isNotEmpty)
                        ...wearableWindows.entries.map((entry) {
                          final windowId = entry.key;
                          final windowData =
                              entry.value as Map<String, dynamic>;
                          return _buildWearableWindowSection(
                              windowId, windowData);
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWearableWindowSection(
    String windowId,
    Map<String, dynamic> windowData,
  ) {
    final sleep = windowData['sleep'] as Map<String, dynamic>?;
    final physiology = windowData['physiology'] as Map<String, dynamic>?;
    final activity = windowData['activity'] as Map<String, dynamic>?;
    final baseline = windowData['baseline'] as Map<String, dynamic>?;
    final date = windowData['date'] as String? ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          'Window: $date',
          [
            // Sleep
            if (sleep != null) ...[
              const Text(
                'Sleep',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple,
                ),
              ),
              if (sleep['duration_minutes'] != null)
                _buildInfoRow(
                  'Duration',
                  '${(sleep['duration_minutes'] as num).toStringAsFixed(1)} min',
                ),
              if (sleep['efficiency'] != null)
                _buildInfoRow(
                  'Efficiency',
                  '${((sleep['efficiency'] as num) * 100).toStringAsFixed(1)}%',
                ),
              if (sleep['score'] != null)
                _buildInfoRow(
                  'Score',
                  '${((sleep['score'] as num) * 100).toStringAsFixed(0)}',
                ),
              if (sleep['deep_ratio'] != null)
                _buildInfoRow(
                  'Deep Sleep',
                  '${((sleep['deep_ratio'] as num) * 100).toStringAsFixed(1)}%',
                ),
              const SizedBox(height: 8),
            ],
            // Physiology
            if (physiology != null) ...[
              const Text(
                'Physiology',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
              if (physiology['resting_hr_bpm'] != null)
                _buildInfoRow(
                  'Resting HR',
                  '${(physiology['resting_hr_bpm'] as num).toStringAsFixed(0)} bpm',
                ),
              if (physiology['hrv_rmssd_ms'] != null)
                _buildInfoRow(
                  'HRV',
                  '${(physiology['hrv_rmssd_ms'] as num).toStringAsFixed(1)} ms',
                ),
              const SizedBox(height: 8),
            ],
            // Activity
            if (activity != null) ...[
              const Text(
                'Activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
              if (activity['steps'] != null)
                _buildInfoRow('Steps', '${activity['steps']}'),
              if (activity['calories'] != null)
                _buildInfoRow(
                  'Calories',
                  '${(activity['calories'] as num).toStringAsFixed(0)}',
                ),
              if (activity['distance_meters'] != null)
                _buildInfoRow(
                  'Distance',
                  '${((activity['distance_meters'] as num) / 1000).toStringAsFixed(2)} km',
                ),
              const SizedBox(height: 8),
            ],
            // Baseline
            if (baseline != null) ...[
              const Text(
                'Baseline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal,
                ),
              ),
              if (baseline['days_in_baseline'] != null)
                _buildInfoRow(
                  'Days',
                  '${baseline['days_in_baseline']}',
                ),
              if (baseline['hrv_deviation_pct'] != null)
                _buildInfoRow(
                  'HRV Deviation',
                  '${(baseline['hrv_deviation_pct'] as num).toStringAsFixed(1)}%',
                ),
            ],
          ],
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Disconnect
  // ──────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    if (_userId == null) return;

    _updateState(status: 'Disconnecting...');

    try {
      await _provider.disconnect(_userId!);
      await clearUserId();
      _pendingOAuthState = null;
      _updateState(
        status: 'Disconnected',
        error: '',
        clearUserId: true,
        clearDataType: true,
        clearData: true,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Garmin disconnect error: $e');
      debugPrint('$stackTrace');
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Disconnect failed',
      );
    }
  }
}
