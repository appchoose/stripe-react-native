package com.reactnativestripesdk.pushprovisioning

import android.os.Parcel
import android.os.Parcelable
import com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider

class EphemeralKeyProvider(
  private val ephemeralKey: String,
) : PushProvisioningEphemeralKeyProvider {
  private constructor(parcel: Parcel) : this(ephemeralKey = parcel.readString() ?: "")

  override fun describeContents(): Int = hashCode()

  override fun writeToParcel(
    dest: Parcel,
    flags: Int,
  ) {
    dest.writeString(ephemeralKey)
  }

  override fun createEphemeralKey(
    apiVersion: String,
    keyUpdateListener: com.stripe.android.pushProvisioning.EphemeralKeyUpdateListener,
  ) {
    keyUpdateListener.onKeyUpdate(ephemeralKey)
  }

  companion object CREATOR : Parcelable.Creator<EphemeralKeyProvider> {
    override fun createFromParcel(parcel: Parcel): EphemeralKeyProvider = EphemeralKeyProvider(parcel)

    override fun newArray(size: Int): Array<EphemeralKeyProvider?> = arrayOfNulls(size)
  }
}
