package com.dpilot.icar

sealed class OBDException(message: String) : Exception(message) {
    class UnableToConnect(msg: String) : OBDException(msg)
    class BusInitError(msg: String) : OBDException(msg)
    class CanError(msg: String) : OBDException(msg)
    class NoData(msg: String) : OBDException(msg)
    class DeviceTimeout(msg: String) : OBDException(msg)
}

object OBDProtocol {

    /**
     * Cleans raw ELM327 responses, strips prompt '>' and command echo, and verifies error tokens.
     */
    fun cleanResponse(raw: String, sentCmd: String): List<String> {
        val normalizedCmd = sentCmd.replace(" ", "").uppercase()
        val lines = raw.replace("\r", "\n")
            .split("\n")
            .map { it.trim() }
            .filter { it.isNotEmpty() && it != ">" }

        val result = mutableListOf<String>()
        for (line in lines) {
            val stripped = line.replace(" ", "").uppercase()

            if (stripped == normalizedCmd || stripped.startsWith("SEARCHING")) {
                continue
            }
            if (stripped.contains("UNABLETOCONNECT")) {
                throw OBDException.UnableToConnect("Adapter reports: UNABLE TO CONNECT. Check ignition switch (must be ON in Run position).")
            }
            if (stripped.contains("BUSINIT") && stripped.contains("ERROR")) {
                throw OBDException.BusInitError("Adapter reports: BUS INIT ERROR. Vehicle bus did not respond.")
            }
            if (stripped.contains("CANERROR")) {
                throw OBDException.CanError("Adapter reports: CAN ERROR. Bus collision or baud rate mismatch.")
            }
            if (stripped == "FB ERROR" || stripped == "STOPPED") {
                throw OBDException.UnableToConnect("Adapter reports: $line")
            }

            result.add(line)
        }
        return result
    }

    /**
     * Checks if response is NO DATA.
     */
    fun isNoData(lines: List<String>): Boolean {
        if (lines.isEmpty()) return true
        for (line in lines) {
            val stripped = line.replace(" ", "").uppercase()
            if (stripped == "NODATA") return true
        }
        return false
    }

    /**
     * Parses real VIN from Mode 09 PID 02 response.
     * Supports both single-line and multi-frame (ISO 15765-4) formats:
     * e.g. "0: 49 02 01 57 42", "1: 41 33 33 41 59", etc.
     */
    fun decodeVIN(lines: List<String>): String? {
        if (isNoData(lines)) return null

        val asciiChars = StringBuilder()
        for (line in lines) {
            val clean = line.replace(Regex("^[0-9A-Fa-f]:"), "").trim()
            val tokens = clean.split(" ").filter { it.length == 2 && it.matches(Regex("[0-9A-Fa-f]{2}")) }

            for (token in tokens) {
                try {
                    val byteVal = token.toInt(16)
                    // Valid VIN characters are 0-9 and A-Z (excluding I, O, Q)
                    if (byteVal in 0x30..0x39 || byteVal in 0x41..0x5A) {
                        asciiChars.append(byteVal.toChar())
                    }
                } catch (_: Exception) {}
            }
        }

        val fullStr = asciiChars.toString()
        // Standard ISO 3779 VIN is exactly 17 characters
        if (fullStr.length >= 17) {
            // Find valid 17-character VIN window
            val match = Regex("[A-HJ-NPR-Z0-9]{17}").find(fullStr)
            if (match != null) {
                return match.value
            }
            return fullStr.take(17)
        }

        return if (fullStr.length in 11..17) fullStr else null
    }

    /**
     * Decodes VIN WMI (first 3 chars) to identify Make and 10th char to identify Year.
     */
    fun decodeVINMetadata(vin: String): Triple<String, String, Int> {
        if (vin.length < 10) {
            return Triple("OBD-II Compliant", "Vehicle", 2020)
        }

        val wmi = vin.take(3).uppercase()
        val yearChar = vin[9].uppercaseChar()

        val make = when {
            wmi.startsWith("WBA") || wmi.startsWith("WBS") || wmi.startsWith("4US") -> "BMW"
            wmi.startsWith("WVW") || wmi.startsWith("1VW") || wmi.startsWith("3VW") -> "Volkswagen"
            wmi.startsWith("WAU") || wmi.startsWith("TRU") -> "Audi"
            wmi.startsWith("1HG") || wmi.startsWith("2HG") || wmi.startsWith("JHM") -> "Honda"
            wmi.startsWith("1FA") || wmi.startsWith("1FD") || wmi.startsWith("1FT") -> "Ford"
            wmi.startsWith("JT") || wmi.startsWith("4T") || wmi.startsWith("5TD") -> "Toyota"
            wmi.startsWith("JM1") || wmi.startsWith("JM3") -> "Mazda"
            wmi.startsWith("WP0") || wmi.startsWith("WP1") -> "Porsche"
            wmi.startsWith("1G") || wmi.startsWith("2G") || wmi.startsWith("3G") -> "General Motors"
            wmi.startsWith("JN") || wmi.startsWith("1N") -> "Nissan"
            wmi.startsWith("KM") || wmi.startsWith("5NP") -> "Hyundai"
            wmi.startsWith("KN") -> "Kia"
            wmi.startsWith("VF1") || wmi.startsWith("VF7") -> "Renault / Citroën"
            wmi.startsWith("SAL") || wmi.startsWith("SAJ") -> "Jaguar Land Rover"
            wmi.startsWith("YV1") -> "Volvo"
            wmi.startsWith("WDB") || wmi.startsWith("WDC") || wmi.startsWith("WDD") -> "Mercedes-Benz"
            else -> "OBD-II Vehicle ($wmi)"
        }

        val yearMap = mapOf(
            'A' to 2010, 'B' to 2011, 'C' to 2012, 'D' to 2013, 'E' to 2014,
            'F' to 2015, 'G' to 2016, 'H' to 2017, 'J' to 2018, 'K' to 2019,
            'L' to 2020, 'M' to 2021, 'N' to 2022, 'P' to 2023, 'R' to 2024,
            'S' to 2025, 'T' to 2026, 'V' to 2027, 'W' to 2028, 'X' to 2029,
            'Y' to 2030, '1' to 2001, '2' to 2002, '3' to 2003, '4' to 2004,
            '5' to 2005, '6' to 2006, '7' to 2007, '8' to 2008, '9' to 2009
        )
        val year = yearMap[yearChar] ?: 2020
        val model = if (make != "OBD-II Compliant") "$make Connected" else "Connected Vehicle"

        return Triple(make, model, year)
    }

    /**
     * Decodes Mode 03 (Stored), Mode 07 (Pending), Mode 0A (Permanent) DTC responses.
     * Response payload starts with 43, 47, or 4A followed by DTC byte pairs.
     */
    fun decodeDTCs(lines: List<String>, status: String): List<DiagnosticCode> {
        if (isNoData(lines)) return emptyList()

        val hexBytes = mutableListOf<Int>()
        for (line in lines) {
            val clean = line.replace(Regex("^[0-9A-Fa-f]:"), "").trim()
            val tokens = clean.split(" ").filter { it.length == 2 && it.matches(Regex("[0-9A-Fa-f]{2}")) }
            for (token in tokens) {
                try {
                    hexBytes.add(token.toInt(16))
                } catch (_: Exception) {}
            }
        }

        // If response starts with service confirmation (0x43, 0x47, 0x4A), skip it
        if (hexBytes.isNotEmpty() && (hexBytes[0] == 0x43 || hexBytes[0] == 0x47 || hexBytes[0] == 0x4A)) {
            hexBytes.removeAt(0)
            // Next byte might be count of DTCs
            if (hexBytes.size % 2 != 0) {
                hexBytes.removeAt(0)
            }
        }

        val resultCodes = mutableListOf<DiagnosticCode>()
        var i = 0
        while (i + 1 < hexBytes.size) {
            val byte1 = hexBytes[i]
            val byte2 = hexBytes[i + 1]
            i += 2

            // 00 00 indicates null/padding
            if (byte1 == 0 && byte2 == 0) continue

            val systemLetter = when ((byte1 ushr 6) and 0x03) {
                0 -> "P" // Powertrain
                1 -> "C" // Chassis
                2 -> "B" // Body
                3 -> "U" // Network
                else -> "P"
            }
            val digit2 = (byte1 ushr 4) and 0x03
            val digit3 = byte1 and 0x0F
            val digit45 = byte2.toString(16).padStart(2, '0').uppercase()

            val dtcId = "$systemLetter$digit2${digit3.toString(16).uppercase()}$digit45"
            val info = lookupDTC(dtcId, status)
            resultCodes.add(info)
        }

        return resultCodes
    }

    /**
     * Looks up SAE J2012 DTC definitions with severity and common causes.
     */
    fun lookupDTC(code: String, status: String): DiagnosticCode {
        val upper = code.uppercase()
        val severity = when {
            status.equals("Permanent", ignoreCase = true) -> DTCSeverity.CRITICAL
            upper.startsWith("P03") || upper.startsWith("P02") || upper.startsWith("P01") -> DTCSeverity.WARNING
            else -> DTCSeverity.INFO
        }

        return when (upper) {
            "P0420" -> DiagnosticCode(
                id = "P0420",
                title = "Catalyst System Efficiency Below Threshold (Bank 1)",
                system = "Powertrain / Emissions",
                status = status,
                severity = severity,
                saeDescription = "The catalytic converter oxygen storage capacity is below the minimum calibrated threshold.",
                commonCauses = listOf("Degraded Catalytic Converter", "Downstream O2 Sensor Fault", "Exhaust Flange Leak")
            )
            "P0171" -> DiagnosticCode(
                id = "P0171",
                title = "System Too Lean (Bank 1)",
                system = "Fuel & Air Metering",
                status = status,
                severity = severity,
                saeDescription = "The ECM detected fuel trim compensation exceeded positive enrichment limits.",
                commonCauses = listOf("Vacuum / PCV Hose Leak", "Dirty Mass Airflow Sensor", "Weak Fuel Pump")
            )
            "P0300" -> DiagnosticCode(
                id = "P0300",
                title = "Random / Multiple Cylinder Misfire Detected",
                system = "Ignition & Combustion",
                status = status,
                severity = severity,
                saeDescription = "The ECM detected multiple combustion abnormalities across crankshaft rotation intervals.",
                commonCauses = listOf("Worn Spark Plugs", "Failing Ignition Coils", "Low Fuel Rail Pressure")
            )
            "P0128" -> DiagnosticCode(
                id = "P0128",
                title = "Coolant Thermostat Below Regulating Temperature",
                system = "Engine Cooling",
                status = status,
                severity = severity,
                saeDescription = "Engine did not reach calibrated operating temperature within the expected run period.",
                commonCauses = listOf("Stuck-Open Thermostat", "Coolant Temperature Sensor Drift")
            )
            else -> {
                val sysName = when (upper.take(1)) {
                    "P" -> "Powertrain"
                    "C" -> "Chassis"
                    "B" -> "Body Control"
                    "U" -> "Network Communications"
                    else -> "Electronic Control Unit"
                }
                DiagnosticCode(
                    id = upper,
                    title = "$sysName Diagnostic Fault $upper",
                    system = sysName,
                    status = status,
                    severity = severity,
                    saeDescription = "Diagnostic Trouble Code $upper reported by vehicle ECU.",
                    commonCauses = listOf("Component failure or sensor harness disconnection", "Wiring short or connector corrosion")
                )
            }
        }
    }

    /**
     * Decodes Mode 01 PID 0C (Engine RPM). Formula: ((A * 256) + B) / 4.0
     */
    fun decodeRPM(lines: List<String>): Double? {
        val bytes = extractPIDBytes(lines, 0x0C) ?: return null
        if (bytes.size < 2) return null
        return ((bytes[0] * 256.0) + bytes[1]) / 4.0
    }

    /**
     * Decodes Mode 01 PID 0D (Vehicle Speed). Formula: A km/h
     */
    fun decodeSpeed(lines: List<String>): Double? {
        val bytes = extractPIDBytes(lines, 0x0D) ?: return null
        if (bytes.isEmpty()) return null
        return bytes[0].toDouble()
    }

    /**
     * Decodes Mode 01 PID 05 (Coolant Temperature). Formula: A - 40 °C
     */
    fun decodeCoolantTemp(lines: List<String>): Double? {
        val bytes = extractPIDBytes(lines, 0x05) ?: return null
        if (bytes.isEmpty()) return null
        return (bytes[0] - 40).toDouble()
    }

    /**
     * Decodes Mode 01 PID 04 (Calculated Engine Load). Formula: (A * 100.0) / 255.0 %
     */
    fun decodeEngineLoad(lines: List<String>): Double? {
        val bytes = extractPIDBytes(lines, 0x04) ?: return null
        if (bytes.isEmpty()) return null
        return (bytes[0] * 100.0) / 255.0
    }

    /**
     * Parses ATRV battery voltage (e.g. "12.6V" -> 12.6).
     */
    fun decodeBatteryVoltage(lines: List<String>): Double {
        for (line in lines) {
            val clean = line.replace("V", "").replace("v", "").trim()
            try {
                val v = clean.toDouble()
                if (v in 5.0..24.0) return v
            } catch (_: Exception) {}
        }
        return 12.6
    }

    private fun extractPIDBytes(lines: List<String>, targetPid: Int): List<Int>? {
        if (isNoData(lines)) return null
        val pidHex = targetPid.toString(16).padStart(2, '0').uppercase()

        for (line in lines) {
            val clean = line.replace(Regex("^[0-9A-Fa-f]:"), "").trim()
            val tokens = clean.split(" ").filter { it.length == 2 && it.matches(Regex("[0-9A-Fa-f]{2}")) }
            // Find 41 followed by target PID
            val idx = tokens.indexOfFirst { it.equals("41", ignoreCase = true) }
            if (idx != -1 && idx + 1 < tokens.size && tokens[idx + 1].equals(pidHex, ignoreCase = true)) {
                return tokens.drop(idx + 2).mapNotNull {
                    try { it.toInt(16) } catch (_: Exception) { null }
                }
            }
        }
        return null
    }
}
