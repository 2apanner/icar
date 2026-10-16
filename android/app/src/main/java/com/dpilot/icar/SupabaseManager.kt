package com.dpilot.icar

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

object SupabaseManager {
    private const val PROJECT_URL = "https://mhmsyfjhvvnaokzhizts.supabase.co"
    private const val ANON_KEY = "sb_publishable__IZgEBiFNFGVEsdMMXLc9A_goCb_29t"
    
    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    private fun isoDate(): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        sdf.timeZone = TimeZone.getTimeZone("UTC")
        return sdf.format(Date())
    }

    suspend fun syncVehicleProfile(profile: VehicleProfile): Boolean = withContext(Dispatchers.IO) {
        try {
            val url = "$PROJECT_URL/rest/v1/vehicles?on_conflict=vin"
            val payload = JSONObject().apply {
                put("vin", profile.vin)
                put("make", profile.make)
                put("model", profile.model)
                put("year", profile.year)
                put("engine", profile.engine)
                put("bus_protocol", profile.protocolName)
                put("resting_voltage", profile.restingVoltage)
                put("last_scanned_at", isoDate())
                put("metadata", JSONObject().apply {
                    put("scanned_by", "iCAR Mobile Android")
                    put("app_version", "1.0.0")
                })
            }

            val request = Request.Builder()
                .url(url)
                .header("Authorization", "Bearer $ANON_KEY")
                .header("apikey", ANON_KEY)
                .header("Content-Type", "application/json")
                .header("Prefer", "resolution=merge-duplicates")
                .post(payload.toString().toRequestBody(jsonMediaType))
                .build()

            client.newCall(request).execute().use { response ->
                response.isSuccessful
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    suspend fun uploadScanReport(
        profile: VehicleProfile,
        storedDTCs: List<DiagnosticCode>,
        pendingDTCs: List<DiagnosticCode>,
        permanentDTCs: List<DiagnosticCode>,
        readinessPassed: Int,
        readinessTotal: Int,
        batteryVoltage: Double,
        batterySOC: Int,
        batteryType: String,
        cbsItems: List<ServiceResetItem>,
        reportText: String
    ): Boolean = withContext(Dispatchers.IO) {
        try {
            val url = "$PROJECT_URL/rest/v1/diagnostic_scans"
            
            val allCodes = (storedDTCs + pendingDTCs + permanentDTCs)
            val dtcsArray = JSONArray()
            for (code in allCodes) {
                dtcsArray.put(JSONObject().apply {
                    put("id", code.id)
                    put("title", code.title)
                    put("system", code.system)
                    put("status", code.status)
                    put("severity", code.severity.name.lowercase())
                    put("sae_description", code.saeDescription)
                })
            }

            val cbsArray = JSONArray()
            for (cbs in cbsItems) {
                cbsArray.put(JSONObject().apply {
                    put("id", cbs.id)
                    put("name", cbs.name)
                    put("status", cbs.statusText)
                    put("is_due", cbs.isDue)
                })
            }

            val payload = JSONObject().apply {
                put("vin", profile.vin)
                put("scan_timestamp", isoDate())
                put("total_faults_count", allCodes.size)
                put("stored_dtcs_count", storedDTCs.size)
                put("pending_dtcs_count", pendingDTCs.size)
                put("permanent_dtcs_count", permanentDTCs.size)
                put("readiness_passed", readinessPassed)
                put("readiness_total", readinessTotal)
                put("battery_voltage", batteryVoltage)
                put("battery_soc", batterySOC)
                put("registered_battery_type", batteryType)
                put("dtcs", dtcsArray)
                put("cbs_intervals", cbsArray)
                put("full_report_text", reportText)
            }

            val request = Request.Builder()
                .url(url)
                .header("Authorization", "Bearer $ANON_KEY")
                .header("apikey", ANON_KEY)
                .header("Content-Type", "application/json")
                .header("Prefer", "return=minimal")
                .post(payload.toString().toRequestBody(jsonMediaType))
                .build()

            client.newCall(request).execute().use { response ->
                response.isSuccessful
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
