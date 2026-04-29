# Keep Conscrypt classes
-keep class org.conscrypt.** { *; }
-keep class com.android.org.conscrypt.** { *; }
-keep class org.apache.harmony.xnet.provider.jsse.** { *; }

# Don't warn about missing platform-specific SSL classes referenced by Conscrypt
-dontwarn org.conscrypt.**
-dontwarn com.android.org.conscrypt.**
-dontwarn org.apache.harmony.xnet.provider.jsse.**

# General - ignore missing classes from optional platform implementations
-dontwarn com.android.org.conscrypt.*
-dontwarn org.apache.harmony.**

# Keep native methods used by Conscrypt
-keepclassmembers class org.conscrypt.** {
    native <methods>;
}

# Keep sun/ssl classes rarely used on some platforms
-dontwarn sun.security.ssl.**

# Keep class members referenced via reflection
-keepclassmembers class * {
    @android.annotation.Keep *;
}
