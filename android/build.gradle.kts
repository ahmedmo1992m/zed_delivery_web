// ==============================================================================
// 📌 ملف: android/build.gradle.kts (في الـ root بتاع فولدر android)
// 📝 ده الملف الرئيسي اللي بيحدد إعدادات الـ build على مستوى المشروع كله.
// ==============================================================================

// 💡 ملاحظة مهمة: الـ 'buildscript' block تم حذفه من هنا.
// الـ repositories و classpath لـ plugins (مثل com.android.tools.build:gradle و com.google.gms:google-services)
// يجب تعريفها في ملف 'settings.gradle.kts' لضمان التناسق وتجنب التعارضات.

// تعريف الـ repositories لكل المشاريع الفرعية (subprojects).
// ده بيضمن إن كل الـ modules تقدر توصل للمكتبات اللي بتحتاجها.
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// بنحدد مسار جديد لفولدر الـ build الرئيسي للمشروع.
// ده بيخلي كل الـ outputs تروح لفولدر "build" اللي جنب فولدر "android".
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// بنعمل نفس الكلام لكل المشاريع الفرعية، عشان كل واحد يبقى ليه فولدر build جوه الـ build الرئيسي.
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// بنضمن إن الـ "app" module بيتعمله evaluation الأول قبل أي subproject تاني.
// ده بيحل مشاكل الـ dependencies اللي ممكن تحصل.
subprojects {
    project.evaluationDependsOn(":app")
}

// بنعمل task اسمها "clean" عشان تمسح كل فولدرات الـ build وتنضف المشروع.
// ده مفيد جدًا لما تحصل مشاكل في الـ build.
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
