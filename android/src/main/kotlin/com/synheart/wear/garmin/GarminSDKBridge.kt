package com.synheart.wear.garmin

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

/**
 * Main bridge class for Garmin SDK integration on Android
 *
 * This bridge uses reflection to check if the Garmin Health SDK is available at runtime.
 * If the SDK is not linked, placeholder implementations are used instead.
 */
class GarminSDKBridge(private val context: Context) : MethodChannel.MethodCallHandler {

    private var methodChannel: MethodChannel? = null
    private var connectionStateChannel: EventChannel? = null
    private var scannedDevicesChannel: EventChannel? = null
    private var realTimeDataChannel: EventChannel? = null
    private var syncProgressChannel: EventChannel? = null

    private var connectionStateHandler: GarminConnectionStateHandler? = null
    private var scannedDevicesHandler: GarminScannedDevicesHandler? = null
    private var realTimeDataHandler: GarminRealTimeDataHandler? = null
    private var syncProgressHandler: GarminSyncProgressHandler? = null

    private var isSDKInitialized = false
    private var licenseKey: String? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // SDK availability flag - checked via reflection
    private val isGarminSDKAvailable: Boolean by lazy {
        try {
            Class.forName("com.garmin.health.GarminHealth")
            true
        } catch (e: ClassNotFoundException) {
            false
        }
    }

    // SDK wrapper for actual SDK calls
    private var sdkWrapper: GarminSdkWrapper? = null

    companion object {
        fun registerWith(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
            val instance = GarminSDKBridge(flutterPluginBinding.applicationContext)
            instance.setupChannels(flutterPluginBinding)
        }
    }

    private fun setupChannels(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        // Method channel
        methodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "synheart_wear/garmin_sdk"
        ).apply {
            setMethodCallHandler(this@GarminSDKBridge)
        }

        // Connection state event channel
        connectionStateHandler = GarminConnectionStateHandler()
        connectionStateChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "synheart_wear/garmin_sdk/connection_state"
        ).apply {
            setStreamHandler(connectionStateHandler)
        }

        // Scanned devices event channel
        scannedDevicesHandler = GarminScannedDevicesHandler()
        scannedDevicesChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "synheart_wear/garmin_sdk/scanned_devices"
        ).apply {
            setStreamHandler(scannedDevicesHandler)
        }

        // Real-time data event channel
        realTimeDataHandler = GarminRealTimeDataHandler()
        realTimeDataChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "synheart_wear/garmin_sdk/real_time_data"
        ).apply {
            setStreamHandler(realTimeDataHandler)
        }

        // Sync progress event channel
        syncProgressHandler = GarminSyncProgressHandler()
        syncProgressChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "synheart_wear/garmin_sdk/sync_progress"
        ).apply {
            setStreamHandler(syncProgressHandler)
        }

        // Initialize SDK wrapper if SDK is available
        if (isGarminSDKAvailable) {
            sdkWrapper = GarminSdkWrapper.create(
                context = context,
                connectionStateHandler = connectionStateHandler!!,
                scannedDevicesHandler = scannedDevicesHandler!!,
                realTimeDataHandler = realTimeDataHandler!!,
                syncProgressHandler = syncProgressHandler!!
            )
        }
    }

    fun dispose() {
        coroutineScope.cancel()
        sdkWrapper?.dispose()
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        connectionStateChannel?.setStreamHandler(null)
        connectionStateChannel = null
        scannedDevicesChannel?.setStreamHandler(null)
        scannedDevicesChannel = null
        realTimeDataChannel?.setStreamHandler(null)
        realTimeDataChannel = null
        syncProgressChannel?.setStreamHandler(null)
        syncProgressChannel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> handleIsAvailable(result)
            "initializeSDK" -> handleInitializeSDK(call, result)
            "isInitialized" -> result.success(isSDKInitialized)
            "startScanning" -> handleStartScanning(call, result)
            "stopScanning" -> handleStopScanning(result)
            "pairDevice" -> handlePairDevice(call, result)
            "cancelPairing" -> handleCancelPairing(result)
            "forgetDevice" -> handleForgetDevice(call, result)
            "getPairedDevices" -> handleGetPairedDevices(result)
            "getConnectionState" -> handleGetConnectionState(call, result)
            "requestSync" -> handleRequestSync(call, result)
            "getBatteryLevel" -> handleGetBatteryLevel(call, result)
            "startStreaming" -> handleStartStreaming(call, result)
            "stopStreaming" -> handleStopStreaming(call, result)
            "readLoggedHeartRate" -> handleReadLoggedHeartRate(call, result)
            "readLoggedStress" -> handleReadLoggedStress(call, result)
            "readLoggedRespiration" -> handleReadLoggedRespiration(call, result)
            "readWellnessEpochs" -> handleReadWellnessEpochs(call, result)
            "readWellnessSummaries" -> handleReadWellnessSummaries(call, result)
            "readSleepSessions" -> handleReadSleepSessions(call, result)
            "readActivitySummaries" -> handleReadActivitySummaries(call, result)
            "scanAccessPoints" -> handleScanAccessPoints(call, result)
            "storeAccessPoint" -> handleStoreAccessPoint(call, result)
            else -> result.notImplemented()
        }
    }

    // ============================================
    // SDK Initialization
    // ============================================

    private fun handleIsAvailable(result: MethodChannel.Result) {
        result.success(isGarminSDKAvailable)
    }

    private fun handleInitializeSDK(call: MethodCall, result: MethodChannel.Result) {
        val licenseKey = call.argument<String>("licenseKey")
        if (licenseKey.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENTS", "License key is required", null)
            return
        }

        this.licenseKey = licenseKey

        if (!isGarminSDKAvailable) {
            result.error(
                "SDK_NOT_AVAILABLE",
                "Garmin Health SDK is not linked. Add the SDK dependency to your build.gradle.",
                null
            )
            return
        }

        coroutineScope.launch {
            try {
                val success = sdkWrapper?.initialize(licenseKey) ?: false
                isSDKInitialized = success
                mainHandler.post {
                    if (success) {
                        result.success(true)
                    } else {
                        result.error("INITIALIZATION_FAILED", "Failed to initialize Garmin SDK", null)
                    }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("INITIALIZATION_ERROR", e.message ?: "Unknown error", null)
                }
            }
        }
    }

    // ============================================
    // Device Scanning
    // ============================================

    private fun handleStartScanning(call: MethodCall, result: MethodChannel.Result) {
        if (!isSDKInitialized) {
            result.error("NOT_INITIALIZED", "Garmin SDK not initialized", null)
            return
        }

        val deviceTypes = call.argument<List<String>>("deviceTypes")
        val timeout = call.argument<Int>("timeout") ?: 30

        if (isGarminSDKAvailable) {
            sdkWrapper?.startScanning(deviceTypes, timeout)
        }

        result.success(null)
    }

    private fun handleStopScanning(result: MethodChannel.Result) {
        if (isGarminSDKAvailable) {
            sdkWrapper?.stopScanning()
        }
        result.success(null)
    }

    // ============================================
    // Device Pairing
    // ============================================

    private fun handlePairDevice(call: MethodCall, result: MethodChannel.Result) {
        if (!isSDKInitialized) {
            result.error("NOT_INITIALIZED", "Garmin SDK not initialized", null)
            return
        }

        val identifier = call.argument<String>("identifier")
        if (identifier.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENTS", "Device identifier is required", null)
            return
        }

        if (!isGarminSDKAvailable) {
            // Placeholder response for development
            result.success(
                mapOf(
                    "unitId" to 12345,
                    "identifier" to identifier,
                    "name" to "Garmin Device",
                    "type" to "fitness_tracker",
                    "connectionState" to "connected",
                    "supportsStreaming" to true
                )
            )
            return
        }

        coroutineScope.launch {
            try {
                val deviceMap = sdkWrapper?.pairDevice(identifier)
                mainHandler.post {
                    if (deviceMap != null) {
                        result.success(deviceMap)
                    } else {
                        result.error("PAIRING_FAILED", "Failed to pair device", null)
                    }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("PAIRING_ERROR", e.message ?: "Pairing failed", null)
                }
            }
        }
    }

    private fun handleCancelPairing(result: MethodChannel.Result) {
        if (isGarminSDKAvailable) {
            sdkWrapper?.cancelPairing()
        }
        result.success(null)
    }

    private fun handleForgetDevice(call: MethodCall, result: MethodChannel.Result) {
        val unitId = call.argument<Int>("unitId")
        val address = call.argument<String>("address")
        if (unitId == null && address == null) {
            result.error("INVALID_ARGUMENTS", "Unit ID or address is required", null)
            return
        }

        val deleteData = call.argument<Boolean>("deleteData") ?: false

        if (!isGarminSDKAvailable) {
            result.success(null)
            return
        }

        coroutineScope.launch {
            try {
                sdkWrapper?.forgetDevice(address ?: "", deleteData)
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("FORGET_FAILED", e.message ?: "Failed to forget device", null)
                }
            }
        }
    }

    private fun handleGetPairedDevices(result: MethodChannel.Result) {
        if (!isSDKInitialized) {
            result.error("NOT_INITIALIZED", "Garmin SDK not initialized", null)
            return
        }

        if (!isGarminSDKAvailable) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        val devices = sdkWrapper?.getPairedDevices() ?: emptyList()
        result.success(devices)
    }

    // ============================================
    // Connection State
    // ============================================

    /**
     * Look up device address by unitId from paired devices
     */
    private fun getDeviceAddressByUnitId(unitId: Int): String? {
        val devices = sdkWrapper?.getPairedDevices() ?: return null
        return devices.find { (it["unitId"] as? Int) == unitId }?.get("identifier") as? String
    }

    private fun handleGetConnectionState(call: MethodCall, result: MethodChannel.Result) {
        val unitId = call.argument<Int>("unitId")
        if (unitId == null) {
            result.error("INVALID_ARGUMENTS", "Unit ID is required", null)
            return
        }

        if (!isGarminSDKAvailable) {
            result.success("disconnected")
            return
        }

        val address = getDeviceAddressByUnitId(unitId)
        if (address == null) {
            result.success("disconnected")
            return
        }

        val state = sdkWrapper?.getConnectionState(address) ?: "disconnected"
        result.success(state)
    }

    // ============================================
    // Sync Operations
    // ============================================

    private fun handleRequestSync(call: MethodCall, result: MethodChannel.Result) {
        val unitId = call.argument<Int>("unitId")
        if (unitId == null) {
            result.error("INVALID_ARGUMENTS", "Unit ID is required", null)
            return
        }

        if (isGarminSDKAvailable) {
            val address = getDeviceAddressByUnitId(unitId)
            if (address != null) {
                sdkWrapper?.requestSync(address)
            }
        }
        result.success(null)
    }

    private fun handleGetBatteryLevel(call: MethodCall, result: MethodChannel.Result) {
        val unitId = call.argument<Int>("unitId")
        if (unitId == null) {
            result.error("INVALID_ARGUMENTS", "Unit ID is required", null)
            return
        }

        if (!isGarminSDKAvailable) {
            result.success(null)
            return
        }

        val address = getDeviceAddressByUnitId(unitId)
        if (address == null) {
            result.success(null)
            return
        }

        val level = sdkWrapper?.getBatteryLevel(address)
        result.success(level)
    }

    // ============================================
    // Real-Time Streaming
    // ============================================

    private fun handleStartStreaming(call: MethodCall, result: MethodChannel.Result) {
        if (!isSDKInitialized) {
            result.error("NOT_INITIALIZED", "Garmin SDK not initialized", null)
            return
        }

        val unitId = call.argument<Int>("unitId") ?: call.argument<Int>("deviceId")
        val dataTypes = call.argument<List<String>>("dataTypes")

        if (isGarminSDKAvailable && unitId != null) {
            val address = getDeviceAddressByUnitId(unitId)
            if (address != null) {
                sdkWrapper?.startStreaming(address, dataTypes)
            }
        }

        result.success(null)
    }

    private fun handleStopStreaming(call: MethodCall, result: MethodChannel.Result) {
        val unitId = call.argument<Int>("unitId") ?: call.argument<Int>("deviceId")

        if (isGarminSDKAvailable) {
            val address = if (unitId != null) getDeviceAddressByUnitId(unitId) else null
            sdkWrapper?.stopStreaming(address)
        }
        result.success(null)
    }

    // ============================================
    // Logged Data Reading
    // ============================================

    private fun handleReadLoggedHeartRate(call: MethodCall, result: MethodChannel.Result) {
        val startTime = call.argument<Long>("startTime")
        val endTime = call.argument<Long>("endTime")
        if (startTime == null || endTime == null) {
            result.error("INVALID_ARGUMENTS", "Start and end time are required", null)
            return
        }

        val unitId = call.argument<Int>("unitId") ?: call.argument<Int>("deviceId")
        val address = if (unitId != null) getDeviceAddressByUnitId(unitId) else null

        if (!isGarminSDKAvailable) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        coroutineScope.launch {
            try {
                val data = sdkWrapper?.readLoggedHeartRate(address, startTime, endTime) ?: emptyList()
                mainHandler.post { result.success(data) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("DATA_ERROR", e.message ?: "Failed to read data", null)
                }
            }
        }
    }

    private fun handleReadLoggedStress(call: MethodCall, result: MethodChannel.Result) {
        val startTime = call.argument<Long>("startTime")
        val endTime = call.argument<Long>("endTime")
        if (startTime == null || endTime == null) {
            result.error("INVALID_ARGUMENTS", "Start and end time are required", null)
            return
        }

        val unitId = call.argument<Int>("unitId") ?: call.argument<Int>("deviceId")
        val address = if (unitId != null) getDeviceAddressByUnitId(unitId) else null

        if (!isGarminSDKAvailable) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        coroutineScope.launch {
            try {
                val data = sdkWrapper?.readLoggedStress(address, startTime, endTime) ?: emptyList()
                mainHandler.post { result.success(data) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("DATA_ERROR", e.message ?: "Failed to read data", null)
                }
            }
        }
    }

    private fun handleReadLoggedRespiration(call: MethodCall, result: MethodChannel.Result) {
        val startTime = call.argument<Long>("startTime")
        val endTime = call.argument<Long>("endTime")
        if (startTime == null || endTime == null) {
            result.error("INVALID_ARGUMENTS", "Start and end time are required", null)
            return
        }

        val unitId = call.argument<Int>("unitId") ?: call.argument<Int>("deviceId")
        val address = if (unitId != null) getDeviceAddressByUnitId(unitId) else null

        if (!isGarminSDKAvailable) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        coroutineScope.launch {
            try {
                val data = sdkWrapper?.readLoggedRespiration(address, startTime, endTime) ?: emptyList()
                mainHandler.post { result.success(data) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("DATA_ERROR", e.message ?: "Failed to read data", null)
                }
            }
        }
    }

    // ============================================
    // Wellness Data
    // ============================================

    private fun handleReadWellnessEpochs(call: MethodCall, result: MethodChannel.Result) {
        val startTime = call.argument<Long>("startTime")
        val endTime = call.argument<Long>("endTime")
        if (startTime == null || endTime == null) {
            result.error("INVALID_ARGUMENTS", "Start and end time are required", null)
            return
        }

        if (!isGarminSDKAvailable) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        coroutineScope.launch {
            try {
                val data = sdkWrapper?.readWellnessEpochs(startTime, endTime) ?: emptyList()
                mainHandler.post { result.success(data) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("DATA_ERROR", e.message ?: "Failed to read data", null)
                }
            }
        }
    }

    private fun handleReadWellnessSummaries(call: MethodCall, result: MethodChannel.Result) {
        val startTime = call.argument<Long>("startTime")
        val endTime = call.argument<Long>("endTime")
        if (startTime == null || endTime == null) {
            result.error("INVALID_ARGUMENTS", "Start and end time are required", null)
            return
        }

        if (!isGarminSDKAvailable) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        coroutineScope.launch {
            try {
                val data = sdkWrapper?.readWellnessSummaries(startTime, endTime) ?: emptyList()
                mainHandler.post { result.success(data) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("DATA_ERROR", e.message ?: "Failed to read data", null)
                }
            }
        }
    }

    // ============================================
    // Sleep Data
    // ============================================

    private fun handleReadSleepSessions(call: MethodCall, result: MethodChannel.Result) {
        val startTime = call.argument<Long>("startTime")
        val endTime = call.argument<Long>("endTime")
        if (startTime == null || endTime == null) {
            result.error("INVALID_ARGUMENTS", "Start and end time are required", null)
            return
        }

        if (!isGarminSDKAvailable) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        coroutineScope.launch {
            try {
                val data = sdkWrapper?.readSleepSessions(startTime, endTime) ?: emptyList()
                mainHandler.post { result.success(data) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("DATA_ERROR", e.message ?: "Failed to read data", null)
                }
            }
        }
    }

    // ============================================
    // Activity Data
    // ============================================

    private fun handleReadActivitySummaries(call: MethodCall, result: MethodChannel.Result) {
        val startTime = call.argument<Long>("startTime")
        val endTime = call.argument<Long>("endTime")
        if (startTime == null || endTime == null) {
            result.error("INVALID_ARGUMENTS", "Start and end time are required", null)
            return
        }

        if (!isGarminSDKAvailable) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        coroutineScope.launch {
            try {
                val data = sdkWrapper?.readActivitySummaries(startTime, endTime) ?: emptyList()
                mainHandler.post { result.success(data) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("DATA_ERROR", e.message ?: "Failed to read data", null)
                }
            }
        }
    }

    // ============================================
    // WiFi Operations
    // ============================================

    private fun handleScanAccessPoints(call: MethodCall, result: MethodChannel.Result) {
        val unitId = call.argument<Int>("unitId")
        if (unitId == null) {
            result.error("INVALID_ARGUMENTS", "Unit ID is required", null)
            return
        }

        if (!isGarminSDKAvailable) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        val address = getDeviceAddressByUnitId(unitId)
        if (address == null) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        coroutineScope.launch {
            try {
                val accessPoints = sdkWrapper?.scanAccessPoints(address) ?: emptyList()
                mainHandler.post { result.success(accessPoints) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("WIFI_ERROR", e.message ?: "Failed to scan access points", null)
                }
            }
        }
    }

    private fun handleStoreAccessPoint(call: MethodCall, result: MethodChannel.Result) {
        val unitId = call.argument<Int>("unitId")
        val ssid = call.argument<String>("ssid")
        val password = call.argument<String>("password")

        if (unitId == null || ssid == null || password == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Unit ID, SSID, and password are required",
                null
            )
            return
        }

        if (!isGarminSDKAvailable) {
            result.success(null)
            return
        }

        val address = getDeviceAddressByUnitId(unitId)
        if (address == null) {
            result.error("DEVICE_NOT_FOUND", "Device not found", null)
            return
        }

        coroutineScope.launch {
            try {
                sdkWrapper?.storeAccessPoint(address, ssid, password)
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("WIFI_ERROR", e.message ?: "Failed to store access point", null)
                }
            }
        }
    }
}

// ============================================
// Event Channel Handlers
// ============================================

/**
 * Handler for connection state events
 */
class GarminConnectionStateHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun sendConnectionState(state: String, deviceId: Int?, error: String?) {
        mainHandler.post {
            val data = mutableMapOf<String, Any>(
                "state" to state,
                "timestamp" to System.currentTimeMillis()
            )
            deviceId?.let { data["deviceId"] = it }
            error?.let { data["error"] = it }
            eventSink?.success(data)
        }
    }
}

/**
 * Handler for scanned devices events
 */
class GarminScannedDevicesHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun sendScannedDevice(device: Map<String, Any>) {
        mainHandler.post {
            eventSink?.success(device)
        }
    }

    fun sendScanFailed(errorCode: Int?) {
        mainHandler.post {
            eventSink?.error("SCAN_FAILED", "Device scanning failed", errorCode)
        }
    }
}

/**
 * Handler for real-time data events
 */
class GarminRealTimeDataHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun sendRealTimeData(data: Map<String, Any>) {
        mainHandler.post {
            eventSink?.success(data)
        }
    }
}

/**
 * Handler for sync progress events
 */
class GarminSyncProgressHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun sendSyncProgress(progress: Double, direction: String, deviceId: Int) {
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "progress" to progress,
                    "direction" to direction,
                    "deviceId" to deviceId
                )
            )
        }
    }
}
