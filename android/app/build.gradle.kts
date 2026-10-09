
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")

if (!keyPropertiesFile.exists()) {
    throw GradleException(
        "Release signing configuration not found: android/key.properties"
    )
}

keyPropertiesFile.inputStream().use { keyProperties.load(it) }

android {
    namespace = "lk.lasindu.threatguard"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "lk.lasindu.threatguard"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storePath = keyProperties.getProperty("storeFile")
                ?: throw GradleException("Missing storeFile in android/key.properties")
            storeFile = file(storePath)

            storePassword = keyProperties.getProperty("storePassword")
                ?: throw GradleException("Missing storePassword in android/key.properties")
            keyAlias = keyProperties.getProperty("keyAlias")
                ?: throw GradleException("Missing keyAlias in android/key.properties")
            keyPassword = keyProperties.getProperty("keyPassword")
                ?: throw GradleException("Missing keyPassword in android/key.properties")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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