package com.reactnativestripesdk

import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Locale
import java.util.UUID

internal class LinkConsumerRepository(private val publishableKey: String) {
    private val apiBase = "https://api.stripe.com/v1"

    fun lookupConsumer(email: String): JSONObject {
        val params = buildString {
            append("email_address=${encode(email)}")
            append("&request_surface=android_payment_element")
            append("&session_id=${UUID.randomUUID()}")
        }
        return post("$apiBase/consumers/sessions/lookup", params, publishableKey)
    }

    fun startVerification(consumerSessionClientSecret: String, consumerAccountPublishableKey: String?) {
        val params = buildString {
            append("credentials[consumer_session_client_secret]=${encode(consumerSessionClientSecret)}")
            append("&type=SMS")
            append("&locale=${encode(Locale.getDefault().toLanguageTag())}")
        }
        post("$apiBase/consumers/sessions/start_verification", params, consumerAccountPublishableKey ?: publishableKey)
    }

    fun confirmVerification(consumerSessionClientSecret: String, code: String, consumerAccountPublishableKey: String?): JSONObject {
        val params = buildString {
            append("credentials[consumer_session_client_secret]=${encode(consumerSessionClientSecret)}")
            append("&type=SMS")
            append("&code=${encode(code)}")
            append("&request_surface=android_payment_element")
        }
        return post("$apiBase/consumers/sessions/confirm_verification", params, consumerAccountPublishableKey ?: publishableKey)
    }

    fun listPaymentDetails(consumerSessionClientSecret: String, consumerAccountPublishableKey: String?): JSONArray {
        val params = buildString {
            append("credentials[consumer_session_client_secret]=${encode(consumerSessionClientSecret)}")
            append("&request_surface=android_payment_element")
            append("&types[]=CARD")
            append("&types[]=BANK_ACCOUNT")
        }
        val json = post("$apiBase/consumers/payment_details/list", params, consumerAccountPublishableKey ?: publishableKey)
        return json.optJSONArray("redactedPaymentDetails") ?: JSONArray()
    }

    private fun post(url: String, body: String, apiKey: String): JSONObject {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Authorization", "Bearer $apiKey")
            connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
            connection.doOutput = true
            connection.connectTimeout = 30_000
            connection.readTimeout = 30_000

            OutputStreamWriter(connection.outputStream).use { it.write(body) }

            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val response = BufferedReader(InputStreamReader(stream)).readText()
            val json = JSONObject(response)

            if (code !in 200..299) {
                val error = json.optJSONObject("error")
                val msg = error?.optString("message") ?: "HTTP $code"
                throw Exception(msg)
            }

            return json
        } finally {
            connection.disconnect()
        }
    }

    private fun encode(value: String): String = URLEncoder.encode(value, "UTF-8")
}
