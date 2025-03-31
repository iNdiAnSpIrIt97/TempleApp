# Keep ProGuard annotations used by Razorpay
-keep class proguard.annotation.Keep { *; }
-keep class proguard.annotation.KeepClassMembers { *; }

# Keep Razorpay classes that use these annotations
-keep class com.razorpay.AnalyticsEvent { *; }
-keep class com.razorpay.** { *; }  # Broader rule for Razorpay SDK
-dontwarn com.razorpay.**           # Suppress warnings if any