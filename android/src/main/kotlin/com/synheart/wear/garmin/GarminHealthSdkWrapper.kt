@file:Suppress("unused")
package com.synheart.wear.garmin

import android.content.Context
import com.garmin.device.realtime.RealTimeDataType
import com.garmin.device.realtime.RealTimeResult
import com.garmin.device.realtime.listeners.RealTimeDataListener
import com.garmin.health.*
import com.garmin.health.bluetooth.FailureCode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Implementation of [GarminSdkWrapper] that uses the actual Garmin Health SDK.
 *
 * This class will only compile when the Garmin Health SDK is added as a dependency.
 * To enable this, uncomment the SDK dependency in android/build.gradle:
 *
 *   implementation 'com.garmin.health:companion-sdk:4.4.0'
 *   // or
 *   implementation 'com.garmin.health:standard-sdk:4.4.0'
 *
 * The GarminSDKBridge uses reflection to instantiate this class only when the SDK
 * is available at runtime, allowing the plugin to compile and run without the SDK.
 */
class GarminHealthSdkWrapper(
    private val context: Context,
    private val connectionStateHandler: GarminConnectionStateHandler,
    private val scannedDevicesHandler: GarminScannedDevicesHandler,
    private val realTimeDataHandler: GarminRealTimeDataHandler,
    private val syncProgressHandler: GarminSyncProgressHandler
) : GarminSdkWrapper, DeviceConnectionStateListener, RealTimeDataListener, DevicePairedStateListener {

    private var scanner: GarminDeviceScanner? = null
    private var activeStreamingAddress: String? = null
    private var activeRealTimeTypes: Set<RealTimeDataType> = emptySet()
    private var pendingScannedDevice: ScannedDevice? = null
    private val coroutineScope = CoroutineScope(Dispatchers.IO)

    init {
        // Register listeners when SDK is initialized
        try {
            DeviceManager.deviceManager.addConnectionStateListener(this)
            DeviceManager.deviceManager.addDevicePairedStateListener(this)
        } catch (e: Exception) {
            // SDK may not be fully initialized yet
        }
    }

    override fun dispose() {
        stopScanning()
        stopStreaming(null)
        try {
            DeviceManager.deviceManager.removeConnectionStateListener(this)
            DeviceManager.deviceManager.removeDevicePairedStateListener(this)
        } catch (e: Exception) {
            // Ignore cleanup errors
        }
    }

    // ============================================
    // SDK Initialization
    // ============================================

    override suspend fun initialize(licenseKey: String): Boolean {
        return suspendCancellableCoroutine { continuation ->
            try {
                val future = GarminHealth.initialize(context, licenseKey)
                future.addListener({
                    try {
                        val result = future.get()
                        // Re-register listeners after initialization
                        DeviceManager.deviceManager.addConnectionStateListener(this)
                        DeviceManager.deviceManager.addDevicePairedStateListener(this)
                        continuation.resume(result)
                    } catch (e: Exception) {
                        continuation.resumeWithException(e)
                    }
                }, { it.run() })
            } catch (e: GarminHealthInitializationException) {
                continuation.resumeWithException(e)
            } catch (e: Exception) {
                continuation.resumeWithException(e)
            }
        }
    }

    // ============================================
    // Device Scanning
    // ============================================

    override fun startScanning(deviceTypes: List<String>?, timeout: Int) {
        stopScanning()

        scanner = object : GarminDeviceScanner(scanUnknownDevices = true) {
            override fun onScannedDevice(device: ScannedDevice) {
                // Store for pairing
                pendingScannedDevice = device

                // Send to Flutter
                scannedDevicesHandler.sendScannedDevice(
                    mapOf(
                        "identifier" to device.address,
                        "name" to (device.friendlyName ?: device.address),
                        "type" to mapDeviceType(device),
                        "rssi" to (device.rssi ?: -100)
                    )
                )
            }

            override fun onBatchScannedDevices(devices: List<ScannedDevice>) {
                devices.forEach { onScannedDevice(it) }
            }

            override fun onScanFailed(errorCode: Int?) {
                scannedDevicesHandler.sendScanFailed(errorCode)
            }
        }

        DeviceManager.deviceManager.registerGarminDeviceScanner(scanner!!)
    }

    override fun stopScanning() {
        scanner?.let {
            try {
                DeviceManager.deviceManager.unregisterGarminDeviceScanner(it)
            } catch (e: Exception) {
                // Ignore errors
            }
            scanner = null
        }
    }

    // ============================================
    // Device Pairing
    // ============================================

    override suspend fun pairDevice(identifier: String): Map<String, Any>? {
        // Find the scanned device by identifier
        val scannedDevice = pendingScannedDevice?.takeIf { it.address == identifier }
            ?: return null

        return suspendCancellableCoroutine { continuation ->
            coroutineScope.launch {
                try {
                    val device = DeviceManager.deviceManager.pair(scannedDevice, object : PairingCallback {
                        override suspend fun authRequested(): Int? = null
                        override fun authTimeout() {}
                    })
                    continuation.resume(deviceToMap(device))
                } catch (e: Exception) {
                    continuation.resumeWithException(e)
                }
            }
        }
    }

    override fun cancelPairing() {
        // Pairing cancellation is handled by coroutine cancellation
    }

    override fun forgetDevice(address: String, deleteData: Boolean) {
        try {
            DeviceManager.deviceManager.forget(address)
        } catch (e: Exception) {
            // Ignore errors
        }
    }

    override fun getPairedDevices(): List<Map<String, Any>> {
        return try {
            DeviceManager.deviceManager.getPairedDevices()?.map { deviceToMap(it) } ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    // ============================================
    // Connection State
    // ============================================

    override fun getConnectionState(address: String): String {
        return try {
            val device = DeviceManager.deviceManager.getDevice(address) ?: return "disconnected"
            mapConnectionState(device.connectionState())
        } catch (e: Exception) {
            "disconnected"
        }
    }

    override fun onDeviceConnected(device: Device) {
        connectionStateHandler.sendConnectionState(
            "connected",
            device.unitId()?.toInt(),
            null
        )
    }

    override fun onDeviceDisconnected(device: Device) {
        connectionStateHandler.sendConnectionState(
            "disconnected",
            device.unitId()?.toInt(),
            null
        )
    }

    override fun onDeviceConnectionFailed(device: Device, failure: FailureCode) {
        connectionStateHandler.sendConnectionState(
            "failed",
            device.unitId()?.toInt(),
            failure.name
        )
    }

    override fun onServiceDisconnected() {
        connectionStateHandler.sendConnectionState("disconnected", null, "Service disconnected")
    }

    // ============================================
    // Device Paired State
    // ============================================

    override fun onDevicePaired(device: Device) {
        connectionStateHandler.sendConnectionState(
            "connected",
            device.unitId()?.toInt(),
            null
        )
    }

    override fun onDeviceUnpaired(macAddress: String) {
        // When unpaired by MAC address, we may not have the unitId
        // Try to find it from cached devices, otherwise send null
        connectionStateHandler.sendConnectionState(
            "disconnected",
            null,
            null
        )
    }

    // ============================================
    // Sync Operations
    // ============================================

    override fun requestSync(address: String) {
        // Sync is typically triggered automatically by the SDK when connected
        // The SDK handles sync automatically on connection
    }

    override fun getBatteryLevel(address: String): Int? {
        return try {
            val device = DeviceManager.deviceManager.getDevice(address) ?: return null
            device.batteryLevel()?.get()
        } catch (e: Exception) {
            null
        }
    }

    // ============================================
    // Real-Time Streaming
    // ============================================

    override fun startStreaming(address: String, dataTypes: List<String>?) {
        stopStreaming(address)

        val realTimeTypes = if (dataTypes.isNullOrEmpty()) {
            setOf(
                RealTimeDataType.HEART_RATE,
                RealTimeDataType.STRESS,
                RealTimeDataType.STEPS,
                RealTimeDataType.HEART_RATE_VARIABILITY,
                RealTimeDataType.SPO2,
                RealTimeDataType.RESPIRATION,
                RealTimeDataType.ACCELEROMETER
            )
        } else {
            dataTypes.mapNotNull { mapRealTimeDataType(it) }.toSet()
        }

        if (realTimeTypes.isEmpty()) return

        activeStreamingAddress = address
        activeRealTimeTypes = realTimeTypes

        try {
            DeviceManager.deviceManager.enableRealTimeData(address, realTimeTypes)
            DeviceManager.deviceManager.addRealTimeDataListener(this, realTimeTypes)
        } catch (e: Exception) {
            // Handle errors gracefully
        }
    }

    override fun stopStreaming(address: String?) {
        val streamAddress = address ?: activeStreamingAddress ?: return

        if (activeRealTimeTypes.isNotEmpty()) {
            try {
                DeviceManager.deviceManager.disableRealTimeData(streamAddress, activeRealTimeTypes)
                DeviceManager.deviceManager.removeRealTimeDataListener(this, activeRealTimeTypes)
            } catch (e: Exception) {
                // Ignore cleanup errors
            }
        }

        activeStreamingAddress = null
        activeRealTimeTypes = emptySet()
    }

    override fun onDataUpdate(macAddress: String, dataType: RealTimeDataType, result: RealTimeResult) {
        if (macAddress != activeStreamingAddress) return

        // Get the device to retrieve unitId
        val device = try {
            DeviceManager.deviceManager.getDevice(macAddress)
        } catch (e: Exception) {
            null
        }

        val data = mutableMapOf<String, Any>(
            "timestamp" to System.currentTimeMillis()
        )
        device?.unitId()?.let { data["deviceId"] = it.toInt() }

        when (dataType) {
            RealTimeDataType.HEART_RATE -> {
                result.heartRate?.let {
                    data["heartRate"] = it.currentHeartRate
                }
            }
            RealTimeDataType.STRESS -> {
                result.stress?.let {
                    data["stress"] = it.stressScore
                }
            }
            RealTimeDataType.STEPS -> {
                result.steps?.let {
                    data["steps"] = it.currentStepCount
                }
            }
            RealTimeDataType.HEART_RATE_VARIABILITY -> {
                result.heartRateVariability?.let {
                    data["hrv"] = it.heartRateVariability
                    // BBI intervals if available
                    it.beatToBeatIntervals?.let { bbi ->
                        data["bbiIntervals"] = bbi.toList()
                    }
                }
            }
            RealTimeDataType.SPO2 -> {
                result.spo2?.let {
                    data["spo2"] = it.spo2Reading
                }
            }
            RealTimeDataType.RESPIRATION -> {
                result.respiration?.let {
                    data["respiration"] = it.respirationRate
                }
            }
            RealTimeDataType.ACCELEROMETER -> {
                result.accelerometer?.accelerometerSamples?.lastOrNull()?.let { accel ->
                    data["accelerometer"] = mapOf(
                        "x" to accel.x,
                        "y" to accel.y,
                        "z" to accel.z,
                        "timestamp" to System.currentTimeMillis()
                    )
                }
            }
            else -> {}
        }

        if (data.size > 2) { // Has more than just timestamp and deviceAddress
            realTimeDataHandler.sendRealTimeData(data)
        }
    }

    // ============================================
    // Logged Data Reading
    // ============================================

    override suspend fun readLoggedHeartRate(address: String?, startTime: Long, endTime: Long): List<Map<String, Any>> {
        // Logged data reading requires database queries through the SDK
        // Implementation depends on specific SDK version and data access APIs
        return emptyList()
    }

    override suspend fun readLoggedStress(address: String?, startTime: Long, endTime: Long): List<Map<String, Any>> {
        return emptyList()
    }

    override suspend fun readLoggedRespiration(address: String?, startTime: Long, endTime: Long): List<Map<String, Any>> {
        return emptyList()
    }

    // ============================================
    // Wellness Data
    // ============================================

    override suspend fun readWellnessEpochs(startTime: Long, endTime: Long): List<Map<String, Any>> {
        return emptyList()
    }

    override suspend fun readWellnessSummaries(startTime: Long, endTime: Long): List<Map<String, Any>> {
        return emptyList()
    }

    // ============================================
    // Sleep Data
    // ============================================

    override suspend fun readSleepSessions(startTime: Long, endTime: Long): List<Map<String, Any>> {
        return emptyList()
    }

    // ============================================
    // Activity Data
    // ============================================

    override suspend fun readActivitySummaries(startTime: Long, endTime: Long): List<Map<String, Any>> {
        return emptyList()
    }

    // ============================================
    // WiFi Operations
    // ============================================

    override suspend fun scanAccessPoints(address: String): List<Map<String, Any>> {
        return emptyList()
    }

    override suspend fun storeAccessPoint(address: String, ssid: String, password: String) {
        // WiFi operations are device-specific and version-dependent
    }

    // ============================================
    // Helper Methods
    // ============================================

    private fun deviceToMap(device: Device): Map<String, Any> {
        val map = mutableMapOf<String, Any>(
            "identifier" to device.address(),
            "name" to device.friendlyName(),
            "type" to "fitness_tracker",
            "connectionState" to mapConnectionState(device.connectionState()),
            "supportsStreaming" to true
        )
        device.unitId()?.let { map["unitId"] = it.toInt() }
        return map
    }

    private fun mapConnectionState(state: ConnectionState?): String {
        return when (state) {
            ConnectionState.CONNECTED -> "connected"
            ConnectionState.CONNECTING -> "connecting"
            ConnectionState.DISCONNECTED -> "disconnected"
            else -> "disconnected"
        }
    }

    private fun mapDeviceType(device: ScannedDevice): String {
        // Map based on device characteristics
        return "fitness_tracker"
    }

    private fun mapRealTimeDataType(type: String): RealTimeDataType? {
        return when (type.lowercase()) {
            "heart_rate", "heartrate" -> RealTimeDataType.HEART_RATE
            "stress" -> RealTimeDataType.STRESS
            "steps" -> RealTimeDataType.STEPS
            "hrv", "heart_rate_variability" -> RealTimeDataType.HEART_RATE_VARIABILITY
            "spo2" -> RealTimeDataType.SPO2
            "respiration" -> RealTimeDataType.RESPIRATION
            "accelerometer" -> RealTimeDataType.ACCELEROMETER
            else -> null
        }
    }
}

