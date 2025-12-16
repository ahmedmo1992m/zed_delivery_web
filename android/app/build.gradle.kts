// 📌 ملف: android/app/build.gradle.kts
// 📝 ده الملف الخاص بإعدادات الـ build بتاع الـ "app" module نفسه.

plugins {
    // بنطبق الـ plugins اللي عرفناها في settings.gradle.kts هنا.
    id("com.android.application") // الـ plugin بتاع الأندرويد
    id("com.google.gms.google-services") // الـ plugin بتاع خدمات جوجل (Firebase)
    id("kotlin-android") // الـ plugin بتاع Kotlin
    id("dev.flutter.flutter-gradle-plugin") // الـ plugin بتاع Flutter
}

android {
    // 💡 إعدادات التوقيع (Signing Configurations)
    signingConfigs {
        create("release") {
            storeFile = file("C:/Users/ahmed/release-keystore.jks")
            storePassword = "0145495263"
            keyAlias = "sapeq-release"
            keyPassword = "0145495263"
        }
    }

    // 💡 إعدادات الـ Build Types (تم دمجها وتصحيحها)
    buildTypes {
        getByName("release") {
            isMinifyEnabled = true // 💡 تفعيل تقليل حجم الكود (Minification)
            isShrinkResources = true // 💡 تفعيل تقليل حجم الموارد (Resource Shrinking)
            signingConfig = signingConfigs.getByName("release") // 💡 استخدام توقيع الـ "release"
        }
        // لو عندك أي build types تانية زي "debug" ممكن تضيفها هنا
        getByName("debug") {
            // إعدادات الـ debug build (عادةً لا يتم تفعيل Minify/Shrink هنا)
            // isMinifyEnabled = false
            // isShrinkResources = false
            // signingConfig = signingConfigs.getByName("debug") // لو عندك debug signing config
        }
    }

    namespace = "com.sapeqbd456new.app"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17 // تأكد إن دي 17
        targetCompatibility = JavaVersion.VERSION_17 // وتأكد إن دي 17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // بنحدد الـ JVM target version لـ Kotlin.
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.sapeqbd456new.app"
        minSdk = 23
        targetSdk = 35
        versionCode = 9
        versionName = "1.8"
    }
}
dependencies {
    // 💡 مهم جداً: لو بتستخدم مكتبات بتحتاج Java 8 (زي flutter_local_notifications)
    // السطر ده هو اللي بيخلي خاصية Desugaring تشتغل بفاعلية.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // ... لو عندك أي dependencies تانية (مثل Firebase BoM/Analytics/Storage) بتضيفها هنا:
    // implementation(platform("com.google.firebase:firebase-bom:33.0.0"))
    // implementation("com.google.firebase:firebase-analytics")
}
flutter {
    // بيحدد مسار ملفات Flutter الرئيسية للمشروع.
    source = "../.."
}

// ✅ ملاحظة مهمة: تم حذف block الـ "repositories" بالكامل من هنا.
// الـ repositories دلوقتي بتتعرف كلها في ملف settings.gradle.kts فقط.
// ده بيحل مشكلة "Build was configured to prefer settings repositories over project repositories".
