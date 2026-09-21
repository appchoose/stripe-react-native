package com.reactnativestripesdk

import android.app.Activity
import android.content.Intent
import android.os.Looper
import androidx.activity.result.ActivityResult
import androidx.fragment.app.FragmentActivity
import com.facebook.react.bridge.ReactApplicationContext
import com.google.android.gms.tasks.TaskCompletionSource
import com.google.android.gms.wallet.PaymentCardRecognitionIntentResponse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

@RunWith(RobolectricTestRunner::class)
class StandaloneCardScanLauncherTest {
  @Test
  fun parsesCompletedResult() {
    val context = mock(ReactApplicationContext::class.java)
    val expectedCard = StandaloneScannedCard("4242424242424242", 12, 2034)
    val launcher = StandaloneCardScanLauncher(context, {}, parseResult = { expectedCard })

    val result = launcher.parseActivityResult(ActivityResult(Activity.RESULT_OK, Intent()))

    assertEquals(StandaloneCardScanResult.Completed(expectedCard), result)
  }

  @Test
  fun parsesCanceledResult() {
    val context = mock(ReactApplicationContext::class.java)
    val launcher = StandaloneCardScanLauncher(context, {})

    val result = launcher.parseActivityResult(ActivityResult(Activity.RESULT_CANCELED, null))

    assertEquals(StandaloneCardScanResult.Canceled, result)
  }

  @Test
  fun reportsUnavailableApi() {
    val context = mock(ReactApplicationContext::class.java)
    val activity = Robolectric.buildActivity(FragmentActivity::class.java).setup().get()
    `when`(context.currentActivity).thenReturn(activity)
    val task = TaskCompletionSource<PaymentCardRecognitionIntentResponse>()
    var result: StandaloneCardScanResult? = null
    val launcher = StandaloneCardScanLauncher(context, { result = it })

    launcher.launch(activity, task.task)
    task.setException(IllegalStateException("Card scanning unavailable"))
    shadowOf(Looper.getMainLooper()).idle()

    assertTrue(result is StandaloneCardScanResult.Failed)
    assertEquals("NotSupported", (result as StandaloneCardScanResult.Failed).code)
    verify(context).addLifecycleEventListener(launcher)
    verify(context).removeLifecycleEventListener(launcher)
  }

  @Test
  fun mapsCompletedResultForReactNative() {
    val result = StandaloneCardScanResult.Completed(
      StandaloneScannedCard("4242424242424242", 12, 2034),
    ).toWritableMap()

    assertEquals("completed", result.getString("status"))
    val card = result.getMap("card")!!
    assertEquals("4242424242424242", card.getString("number"))
    assertEquals(12, card.getInt("expiryMonth"))
    assertEquals(2034, card.getInt("expiryYear"))
  }
}
