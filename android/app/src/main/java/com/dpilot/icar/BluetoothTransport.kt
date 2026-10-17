package com.dpilot.icar

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.util.Log
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID

private const val TAG = "iCAR_BT"

// Standard Serial Port Profile (SPP) UUID for Classic Bluetooth OBD-II
private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

// Standard Client Characteristic Configuration Descriptor (CCCD)
private val CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")

// Known BLE OBD-II / UART Characteristic UUIDs
private val KNOWN_NOTIFY_UUIDS = listOf(
    UUID.fromString("0000ffe1-0000-1000-8000-00805f9b34fb"), // Veepeak, Carista, generic FFE0
    UUID.fromString("00002af0-0000-1000-8000-00805f9b34fb"), // Vgate iCar Pro
    UUID.fromString("0000fff1-0000-1000-8000-00805f9b34fb"), // vLinker, OBDLink CX
    UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e")  // Nordic UART RX notify
)

private val KNOWN_WRITE_UUIDS = listOf(
    UUID.fromString("0000ffe1-0000-1000-8000-00805f9b34fb"), // Veepeak FFE1 (read/write/notify same)
    UUID.fromString("00002af1-0000-1000-8000-00805f9b34fb"), // Vgate iCar Pro TX
    UUID.fromString("0000fff2-0000-1000-8000-00805f9b34fb"), // vLinker, OBDLink CX TX
    UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e")  // Nordic UART TX write
)

class BluetoothTransport(private val context: Context) {
    private val commandMutex = Mutex()

    // Classic RFCOMM socket state
    private var rfcommSocket: BluetoothSocket? = null
    private var inputStream: InputStream? = null
    private var outputStream: OutputStream? = null

    // BLE GATT state
    private var bluetoothGatt: BluetoothGatt? = null
    private var writeCharacteristic: BluetoothGattCharacteristic? = null
    private var notifyCharacteristic: BluetoothGattCharacteristic? = null
    private var bleConnectDeferred: CompletableDeferred<Boolean>? = null
    private val bleRxBuffer = StringBuilder()
    private var bleResponseDeferred: CompletableDeferred<String>? = null

    var isConnected: Boolean = false
        private set

    @SuppressLint("MissingPermission")
    suspend fun connect(device: BluetoothDevice): Boolean = withContext(Dispatchers.IO) {
        disconnect()
        Log.d(TAG, "Attempting connection to device: ${device.name ?: device.address} (${device.address})")

        // 1. Try Classic Bluetooth RFCOMM first if device is bonded or supports Classic
        val deviceType = device.type
        val canTryClassic = deviceType == BluetoothDevice.DEVICE_TYPE_CLASSIC ||
                deviceType == BluetoothDevice.DEVICE_TYPE_DUAL ||
                device.bondState == BluetoothDevice.BOND_BONDED

        if (canTryClassic) {
            Log.d(TAG, "Trying Classic Bluetooth RFCOMM (SPP)...")
            val classicSuccess = connectClassic(device)
            if (classicSuccess) {
                isConnected = true
                Log.d(TAG, "Successfully connected via Classic Bluetooth RFCOMM.")
                return@withContext true
            }
            Log.w(TAG, "Classic RFCOMM connection failed, falling back to BLE GATT...")
        }

        // 2. Fallback to BLE GATT connection
        Log.d(TAG, "Trying BLE GATT connection...")
        val bleSuccess = connectBLE(device)
        if (bleSuccess) {
            isConnected = true
            Log.d(TAG, "Successfully connected via BLE GATT.")
            return@withContext true
        }

        Log.e(TAG, "All Bluetooth connection attempts failed for ${device.address}")
        disconnect()
        false
    }

    @SuppressLint("MissingPermission")
    private fun connectClassic(device: BluetoothDevice): Boolean {
        // Cancel discovery before connecting as recommended by Android documentation
        BluetoothAdapter.getDefaultAdapter()?.cancelDiscovery()

        // Attempt 1: Standard Secure RFCOMM
        try {
            val socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
            socket.connect()
            rfcommSocket = socket
            inputStream = socket.inputStream
            outputStream = socket.outputStream
            return true
        } catch (e: Exception) {
            Log.w(TAG, "Secure RFCOMM failed: ${e.message}. Trying Insecure RFCOMM...")
        }

        // Attempt 2: Insecure RFCOMM (compatible with unauthenticated Chinese ELM327 clones)
        try {
            val socket = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
            socket.connect()
            rfcommSocket = socket
            inputStream = socket.inputStream
            outputStream = socket.outputStream
            return true
        } catch (e: Exception) {
            Log.w(TAG, "Insecure RFCOMM failed: ${e.message}")
        }

        // Attempt 3: Reflection on channel 1 (universal fallback for older ELM adapters)
        try {
            val method = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
            val socket = method.invoke(device, 1) as BluetoothSocket
            socket.connect()
            rfcommSocket = socket
            inputStream = socket.inputStream
            outputStream = socket.outputStream
            return true
        } catch (e: Exception) {
            Log.w(TAG, "Reflection RFCOMM channel 1 failed: ${e.message}")
        }

        return false
    }

    @SuppressLint("MissingPermission")
    private suspend fun connectBLE(device: BluetoothDevice): Boolean = withContext(Dispatchers.Main) {
        val deferred = CompletableDeferred<Boolean>()
        bleConnectDeferred = deferred

        val callback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    Log.d(TAG, "GATT connected, discovering services...")
                    gatt.discoverServices()
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    Log.w(TAG, "GATT disconnected (status: $status)")
                    isConnected = false
                    bleConnectDeferred?.complete(false)
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    bleConnectDeferred?.complete(false)
                    return
                }

                // Search for suitable Write and Notify characteristics
                var foundWrite: BluetoothGattCharacteristic? = null
                var foundNotify: BluetoothGattCharacteristic? = null

                // First search known OBD UUIDs
                for (service in gatt.services) {
                    for (char in service.characteristics) {
                        if (KNOWN_WRITE_UUIDS.contains(char.uuid)) {
                            foundWrite = char
                        }
                        if (KNOWN_NOTIFY_UUIDS.contains(char.uuid)) {
                            foundNotify = char
                        }
                    }
                }

                // If not found in known lists, look for any characteristic with matching properties
                if (foundWrite == null || foundNotify == null) {
                    for (service in gatt.services) {
                        for (char in service.characteristics) {
                            val props = char.properties
                            if (foundWrite == null && (props and (BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE)) != 0) {
                                foundWrite = char
                            }
                            if (foundNotify == null && (props and (BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_INDICATE)) != 0) {
                                foundNotify = char
                            }
                        }
                    }
                }

                if (foundWrite != null && foundNotify != null) {
                    writeCharacteristic = foundWrite
                    notifyCharacteristic = foundNotify

                    // Enable notifications on notify characteristic
                    gatt.setCharacteristicNotification(foundNotify, true)
                    val descriptor = foundNotify.getDescriptor(CCCD_UUID)
                    if (descriptor != null) {
                        descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        gatt.writeDescriptor(descriptor)
                    }

                    Log.d(TAG, "GATT ready: Write=${foundWrite.uuid}, Notify=${foundNotify.uuid}")
                    bleConnectDeferred?.complete(true)
                } else {
                    Log.e(TAG, "Failed to identify OBD-II GATT characteristics")
                    bleConnectDeferred?.complete(false)
                }
            }

            private fun handleIncomingBytes(data: ByteArray?) {
                if (data == null) return
                val text = String(data, Charsets.US_ASCII)
                synchronized(bleRxBuffer) {
                    bleRxBuffer.append(text)
                    if (bleRxBuffer.contains(">")) {
                        val full = bleRxBuffer.toString()
                        bleRxBuffer.setLength(0)
                        bleResponseDeferred?.complete(full)
                    }
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                @Suppress("DEPRECATION")
                handleIncomingBytes(characteristic.value)
            }

            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
                handleIncomingBytes(value)
            }
        }

        bluetoothGatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
        val result = withTimeoutOrNull(8000) { deferred.await() } ?: false
        bleConnectDeferred = null
        result
    }

    suspend fun sendCommand(cmd: String, timeoutMs: Long = 4000): String = commandMutex.withLock {
        if (!isConnected) {
            throw IllegalStateException("Hardware adapter not connected")
        }

        val cleanCmd = cmd.trim()
        val payload = cleanCmd + "\r"

        // Execute via Classic RFCOMM
        if (rfcommSocket != null && inputStream != null && outputStream != null) {
            return@withLock executeRfcomm(payload, timeoutMs)
        }

        // Execute via BLE GATT
        if (bluetoothGatt != null && writeCharacteristic != null) {
            return@withLock executeGatt(payload, timeoutMs)
        }

        throw IllegalStateException("No active Bluetooth transport stream")
    }

    private suspend fun executeRfcomm(payload: String, timeoutMs: Long): String = withContext(Dispatchers.IO) {
        val out = outputStream ?: throw IllegalStateException("Output stream closed")
        val input = inputStream ?: throw IllegalStateException("Input stream closed")

        // Flush any stale bytes before sending new command
        while (input.available() > 0) {
            input.read()
        }

        out.write(payload.toByteArray(Charsets.US_ASCII))
        out.flush()

        val responseBuilder = StringBuilder()
        val buffer = ByteArray(256)
        val deadline = System.currentTimeMillis() + timeoutMs

        while (System.currentTimeMillis() < deadline) {
            if (input.available() > 0) {
                val readCount = input.read(buffer)
                if (readCount > 0) {
                    val chunk = String(buffer, 0, readCount, Charsets.US_ASCII)
                    responseBuilder.append(chunk)
                    if (responseBuilder.contains(">")) {
                        break
                    }
                }
            } else {
                Thread.sleep(15)
            }
        }

        val response = responseBuilder.toString()
        if (!response.contains(">") && response.isEmpty()) {
            throw java.util.concurrent.TimeoutException("ELM327 command timed out without prompt '>'")
        }
        response
    }

    @SuppressLint("MissingPermission")
    private suspend fun executeGatt(payload: String, timeoutMs: Long): String = withContext(Dispatchers.IO) {
        val gatt = bluetoothGatt ?: throw IllegalStateException("GATT disconnected")
        val writeChar = writeCharacteristic ?: throw IllegalStateException("Write characteristic missing")

        val deferred = CompletableDeferred<String>()
        bleResponseDeferred = deferred
        synchronized(bleRxBuffer) {
            bleRxBuffer.setLength(0)
        }

        val bytes = payload.toByteArray(Charsets.US_ASCII)
        writeChar.writeType = if ((writeChar.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0) {
            BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        } else {
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        }

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            gatt.writeCharacteristic(writeChar, bytes, writeChar.writeType)
        } else {
            @Suppress("DEPRECATION")
            writeChar.value = bytes
            @Suppress("DEPRECATION")
            gatt.writeCharacteristic(writeChar)
        }

        val response = withTimeoutOrNull(timeoutMs) { deferred.await() }
        bleResponseDeferred = null

        if (response == null) {
            throw java.util.concurrent.TimeoutException("GATT command timed out waiting for '>'")
        }
        response
    }

    @SuppressLint("MissingPermission")
    fun disconnect() {
        isConnected = false
        try {
            inputStream?.close()
        } catch (_: Exception) {}
        try {
            outputStream?.close()
        } catch (_: Exception) {}
        try {
            rfcommSocket?.close()
        } catch (_: Exception) {}
        rfcommSocket = null
        inputStream = null
        outputStream = null

        try {
            bluetoothGatt?.disconnect()
            bluetoothGatt?.close()
        } catch (_: Exception) {}
        bluetoothGatt = null
        writeCharacteristic = null
        notifyCharacteristic = null
    }
}
