package com.reactnativestripesdk

import android.app.Activity
import android.content.Intent
import androidx.activity.result.ActivityResult
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.FragmentActivity
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.WritableMap
import com.google.android.gms.tasks.Task
import com.google.android.gms.wallet.PaymentCardRecognitionIntentResponse
import com.google.android.gms.wallet.PaymentCardRecognitionResult
import java.util.UUID

internal data class StandaloneScannedCard(
  val number: String,
  val expiryMonth: Int?,
  val expiryYear: Int?,
)

internal sealed interface StandaloneCardScanResult {
  data class Completed(
    val card: StandaloneScannedCard,
  ) : StandaloneCardScanResult

  data object Canceled : StandaloneCardScanResult

  data class Failed(
    val code: String,
    val message: String,
  ) : StandaloneCardScanResult
}

internal fun StandaloneCardScanResult.toWritableMap(): WritableMap {
  val result = Arguments.createMap()
  when (this) {
    is StandaloneCardScanResult.Completed -> {
      result.putString("status", "completed")
      val cardMap = Arguments.createMap()
      cardMap.putString("number", card.number)
      card.expiryMonth?.let { cardMap.putInt("expiryMonth", it) }
      card.expiryYear?.let { cardMap.putInt("expiryYear", it) }
      result.putMap("card", cardMap)
    }
    StandaloneCardScanResult.Canceled -> result.putString("status", "canceled")
    is StandaloneCardScanResult.Failed -> {
      result.putString("status", "failed")
      val errorMap = Arguments.createMap()
      errorMap.putString("code", code)
      errorMap.putString("message", message)
      errorMap.putString("localizedMessage", message)
      result.putMap("error", errorMap)
    }
  }
  return result
}

/** Owns a standalone card scan and reconnects its result after Activity recreation. */
internal class StandaloneCardScanLauncher(
  private val context: ReactApplicationContext,
  private val callback: (StandaloneCardScanResult) -> Unit,
  private val parseResult: (Intent) -> StandaloneScannedCard? = ::parsePaymentCardRecognitionResult,
) : LifecycleEventListener {
  private val key = "StripeCardScan_${UUID.randomUUID()}"
  private var activity: FragmentActivity? = null
  private var launcher: ActivityResultLauncher<IntentSenderRequest>? = null
  private var pendingRequest: IntentSenderRequest? = null
  private var destroyed = false

  fun launch(
    currentActivity: FragmentActivity,
    task: Task<PaymentCardRecognitionIntentResponse>,
  ) {
    context.addLifecycleEventListener(this)
    register(currentActivity)
    task
      .addOnSuccessListener { response ->
        if (destroyed) return@addOnSuccessListener
        pendingRequest = IntentSenderRequest.Builder(
          response.paymentCardRecognitionPendingIntent.intentSender,
        ).build()
        launchPendingRequest()
      }.addOnFailureListener { error ->
        finish(
          StandaloneCardScanResult.Failed(
            code = "NotSupported",
            message = error.localizedMessage ?: "Card scanning is not available on this device.",
          ),
        )
      }
  }

  private fun register(currentActivity: FragmentActivity) {
    if (destroyed || activity === currentActivity) return
    launcher?.unregister()
    activity = currentActivity
    val registered = currentActivity.activityResultRegistry.register(
      key,
      ActivityResultContracts.StartIntentSenderForResult(),
    ) { result ->
      if (!destroyed) {
        finish(parseActivityResult(result))
      }
    }
    // Registration can immediately deliver a pending result after Activity recreation.
    if (destroyed) registered.unregister() else launcher = registered
    launchPendingRequest()
  }

  @Suppress("TooGenericExceptionCaught")
  private fun launchPendingRequest() {
    val request = pendingRequest ?: return
    val currentLauncher = launcher ?: return
    if (destroyed) return
    pendingRequest = null
    try {
      currentLauncher.launch(request)
    } catch (error: Exception) {
      finish(
        StandaloneCardScanResult.Failed(
          code = "Failed",
          message = error.localizedMessage ?: "Unable to launch the card scanner.",
        ),
      )
    }
  }

  internal fun parseActivityResult(result: ActivityResult): StandaloneCardScanResult =
    when {
      result.resultCode == Activity.RESULT_OK && result.data != null -> {
        val card = parseResult(result.data!!)
        if (card != null) {
          StandaloneCardScanResult.Completed(card)
        } else {
          StandaloneCardScanResult.Failed(
            code = "Failed",
            message = "The card scanner returned no card number.",
          )
        }
      }
      result.resultCode == Activity.RESULT_CANCELED -> StandaloneCardScanResult.Canceled
      else -> StandaloneCardScanResult.Failed(
        code = "Failed",
        message = "The card scanner returned an invalid result.",
      )
    }

  private fun finish(result: StandaloneCardScanResult) {
    if (destroyed) return
    destroy()
    callback(result)
  }

  fun destroy() {
    destroyed = true
    pendingRequest = null
    launcher?.unregister()
    launcher = null
    activity = null
    context.removeLifecycleEventListener(this)
  }

  override fun onHostResume() {
    (context.currentActivity as? FragmentActivity)?.let(::register)
  }

  override fun onHostPause() = Unit

  override fun onHostDestroy() {
    launcher?.unregister()
    launcher = null
    activity = null
  }
}

private fun parsePaymentCardRecognitionResult(intent: Intent): StandaloneScannedCard? {
  val result = PaymentCardRecognitionResult.getFromIntent(intent) ?: return null
  val number = result.pan.takeIf { it.isNotBlank() } ?: return null
  val expiry = result.creditCardExpirationDate
  return StandaloneScannedCard(
    number = number,
    expiryMonth = expiry?.month,
    expiryYear = expiry?.year,
  )
}
