package com.synheart.wear.garmin

import android.content.Context

/**
 * Interface for Garmin SDK operations.
 *
 * This interface allows the bridge to work without direct SDK dependencies.
 * The actual implementation (`GarminHealthSdkWrapper`) uses the Garmin Health SDK and is only
 * instantiated when the SDK is available at runtime.
 */
interface GarminSdkWrapper {
    fun dispose()
    suspend fun initialize(licenseKey: String): Boolean
    fun startScanning(deviceTypes: List<String>?, timeout: Int)
    fun stopScanning()
    suspend fun pairDevice(identifier: String): Map<String, Any>?
    fun cancelPairing()
    fun forgetDevice(address: String, deleteData: Boolean)
    fun getPairedDevices(): List<Map<String, Any>>
    fun getConnectionState(address: String): String
    fun requestSync(address: String)
    fun getBatteryLevel(address: String): Int?
    fun startStreaming(address: String, dataTypes: List<String>?)
    fun stopStreaming(address: String?)
    suspend fun readLoggedHeartRate(address: String?, startTime: Long, endTime: Long): List<Map<String, Any>>
    suspend fun readLoggedStress(address: String?, startTime: Long, endTime: Long): List<Map<String, Any>>
    suspend fun readLoggedRespiration(address: String?, startTime: Long, endTime: Long): List<Map<String, Any>>
    suspend fun readWellnessEpochs(startTime: Long, endTime: Long): List<Map<String, Any>>
    suspend fun readWellnessSummaries(startTime: Long, endTime: Long): List<Map<String, Any>>
    suspend fun readSleepSessions(startTime: Long, endTime: Long): List<Map<String, Any>>
    suspend fun readActivitySummaries(startTime: Long, endTime: Long): List<Map<String, Any>>
    suspend fun scanAccessPoints(address: String): List<Map<String, Any>>
    suspend fun storeAccessPoint(address: String, ssid: String, password: String)

    companion object {
        /**
         * Creates a GarminSdkWrapper instance if the SDK is available.
         * Returns null if the SDK is not linked.
         */
        fun create(
            context: Context,
            connectionStateHandler: GarminConnectionStateHandler,
            scannedDevicesHandler: GarminScannedDevicesHandler,
            realTimeDataHandler: GarminRealTimeDataHandler,
            syncProgressHandler: GarminSyncProgressHandler
        ): GarminSdkWrapper? {
            return try {
                // Try to load the implementation class via reflection
                val implClass = Class.forName("com.synheart.wear.garmin.GarminHealthSdkWrapper")
                val constructor = implClass.getConstructor(
                    Context::class.java,
                    GarminConnectionStateHandler::class.java,
                    GarminScannedDevicesHandler::class.java,
                    GarminRealTimeDataHandler::class.java,
                    GarminSyncProgressHandler::class.java
                )
                constructor.newInstance(
                    context,
                    connectionStateHandler,
                    scannedDevicesHandler,
                    realTimeDataHandler,
                    syncProgressHandler
                ) as GarminSdkWrapper
            } catch (e: Exception) {
                // SDK implementation not available
                null
            }
        }
    }
}

