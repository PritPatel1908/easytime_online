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
            // Install Conscrypt provider for older Android versions (<= N_MR1)
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.N_MR1) {
                Security.insertProviderAt(Conscrypt.newProvider(), 1)
                Log.d("MyApplication", "Conscrypt provider installed")
            }
        } catch (t: Throwable) {
            Log.w("MyApplication", "Conscrypt install failed: ${t.message}")
        }
    }
}
