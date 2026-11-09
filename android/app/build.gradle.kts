import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.scheda_prelievo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            val keyFile = keystoreProperties.getProperty("storeFile")
            if (keyFile != null) {
                storeFile = file(keyFile)
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            } else {
                // Configurazione di default per Speleo Club Roma
                val defaultKeystore = file("speleo_keystore.jks")
                if (defaultKeystore.exists()) {
                    storeFile = defaultKeystore
                    storePassword = "SpeleoClubRoma1959!"
                    keyAlias = "speleo_key"
                    keyPassword = "SpeleoClubRoma1959!"
                }
            }
        }
    }

    defaultConfig {
        applicationId = "com.example.scheda_prelievo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            val releaseConfig = signingConfigs.getByName("release")
            if (releaseConfig.storeFile != null && releaseConfig.storeFile!!.exists()) {
                signingConfig = releaseConfig
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
