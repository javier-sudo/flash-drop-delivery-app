plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.javier.proyecto_app_delivery_gessof"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.javier.proyecto_app_delivery_gessof"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // google_maps_flutter: API key leída desde android/local.properties (gitignored).
        // Defaults a "PLACEHOLDER" para que el build no falle si la propiedad no existe.
        // El cliente debe setear MAPS_API_KEY=AIza... en android/local.properties cuando quiera activar el mapa.
        val propsFile = rootProject.file("local.properties")
        val mapsKey = if (propsFile.exists()) {
            java.util.Properties().apply { propsFile.inputStream().use { load(it) } }
                .getProperty("MAPS_API_KEY") ?: "PLACEHOLDER"
        } else {
            "PLACEHOLDER"
        }
        manifestPlaceholders["MAPS_API_KEY"] = mapsKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
