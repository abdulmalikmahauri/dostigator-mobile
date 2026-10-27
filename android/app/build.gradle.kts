import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Пароли и путь к хранилищу ключей лежат вне репозитория:
// C:\Claude Project\dostigator-keystore\key.properties
//
// Каталог намеренно на латинице: кириллица в пути ломает цепочку сборки.
// Сам файл обязан быть в UTF-8 БЕЗ BOM — Java читает .properties как
// ISO-8859-1, и метка порядка байт прилипает к имени первого ключа,
// после чего storePassword молча становится null.
//
// Потеря этого файла и самого .jks означает, что обновление приложения
// больше нельзя поставить поверх установленного — ни у резидентов,
// ни в RuStore. Хранить в двух местах, одно из них вне рабочей машины.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("../../dostigator-keystore/key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "org.dostigator.dostigator"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // Планировщик уведомлений использует классы дат из Java 8.
        // На Android ниже 26 их нет, и desugaring подкладывает
        // совместимую реализацию. Без этого сборка падает.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "org.dostigator.dostigator"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Требуем все четыре значения разом: частично заполненный
            // key.properties даёт невнятное «null cannot be cast to String»
            // вместо понятного сообщения о том, что не так.
            val required = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            val missing = required.filter { keystoreProperties.getProperty(it).isNullOrBlank() }

            if (keystorePropertiesFile.exists() && missing.isNotEmpty()) {
                throw GradleException(
                    "В ${keystorePropertiesFile.path} не заполнено: ${missing.joinToString(", ")}. " +
                    "Проверьте, что файл сохранён в UTF-8 без BOM."
                )
            }

            if (missing.isEmpty()) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Без своего ключа Flutter подписывает release отладочным.
            // С таким APK нельзя ни выложиться в стор, ни обновить
            // приложение со сборки, сделанной на другой машине.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
