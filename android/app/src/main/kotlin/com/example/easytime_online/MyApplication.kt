package com.example.easytime_online

import android.app.Application
import android.os.Build
import android.util.Log
import org.conscrypt.Conscrypt
import java.security.Security

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        try {
            // Install Conscrypt 2.5.2 as the primary SSL provider on all Android versions.
            // This overrides the (potentially older) system Conscrypt on Android 8–11 and
            // adds TLS 1.2/1.3 support on Android 5–7, fixing SSL handshake failures
            // that would otherwise cause "Connection error: Could not reach API via HTTPS or HTTP".
            Security.insertProviderAt(Conscrypt.newProvider(), 1)
            Log.d("MyApplication", "Conscrypt provider installed for API ${Build.VERSION.SDK_INT}")
        } catch (t: Throwable) {
            Log.w("MyApplication", "Conscrypt install failed: ${t.message}")
        }
    }
}
