// ==============================================================================
// 📌 ملف: android/settings.gradle.kts
// 📝 ده الملف اللي بيحدد إعدادات المشاريع الفرعية والـ plugins اللي بنستخدمها.
// 💡 تم تغيير repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
//    إلى repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
//    للسماح للـ plugins بإضافة الـ repositories الخاصة بها دون تعارض.
// ==============================================================================

pluginManagement {
    // الجزء ده بيحدد منين Gradle هيجيب الـ plugins بتاعته.
    // مهم جدًا لـ Flutter عشان يلاقي الـ plugin بتاعه.
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        // بنقرأ مسار الـ Flutter SDK من ملف local.properties
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        // بنتأكد إن المسار موجود، لو مش موجود هيطلع إيرور.
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    // بنضيف الـ plugin بتاع Flutter عشان Gradle يقدر يتعرف عليه.
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    // دي الـ repositories اللي Gradle هيدور فيها على الـ plugins.
    repositories {
        google() // مستودع جوجل
        mavenCentral() // المستودع المركزي لـ Maven
        gradlePluginPortal() // بوابة الـ plugins بتاعة Gradle
    }
}

dependencyResolutionManagement {
    // ✅ تم تغيير هذا السطر:
    // بدل ما كنا بنقول "افشل لو أي project repository اتحطت"، بنقول "فضل الـ project repositories".
    // ده بيسمح للـ plugins زي flutter-gradle-plugin إنها تضيف الـ repositories بتاعتها.
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
    }
}

// هنا بنعرف الـ plugins اللي المشروع كله هيستخدمها، وبنحدد الـ versions بتاعتها.
// "apply false" معناها إننا بنعرف الـ plugin بس مش بنطبقه دلوقتي، هيتطبق في ملف الـ build بتاع كل module.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0" // الـ plugin بتاع Flutter
    id("com.android.application") version "8.7.3" apply false // الـ plugin بتاع الأندرويد
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false // الـ plugin بتاع Kotlin
    id("com.google.gms.google-services") version "4.4.1" apply false // الـ plugin بتاع خدمات جوجل (Firebase)
}

// بنضم الـ module بتاع الـ "app" للمشروع.
include(":app")
