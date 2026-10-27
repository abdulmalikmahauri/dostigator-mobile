pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        /*
         * Зеркало вместо mavenCentral(): Maven Central отдаёт 403 на
         * запросы из России, и сборка падает на любом артефакте, которого
         * ещё нет в локальном кеше Gradle. Зеркало JetBrains проксирует
         * тот же Maven Central и доступно отсюда.
         */
        maven("https://cache-redirector.jetbrains.com/maven-central")
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
