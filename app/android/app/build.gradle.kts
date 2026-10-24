plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ajayjasper.mimic_mixamo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
    defaultConfig {
        applicationId = "com.ajayjasper.mimic_mixamo"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    // MediaPipe must be able to memory-map its bundled task through AssetManager.
    androidResources { noCompress += listOf("task") }
    buildTypes {
        release { signingConfig = signingConfigs.getByName("debug") }
    }
}
flutter { source = "../.." }
