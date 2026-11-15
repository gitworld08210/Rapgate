pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropertiesFile = file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { properties.load(it) }
        }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
            ?: System.getenv("FLUTTER_ROOT")
            ?: System.getenv("FLUTTER_HOME")
            ?: run {
                try {
                    val p = ProcessBuilder("which", "flutter").start()
                    val path = p.inputStream.bufferedReader().readText().trim()
                    if (path.isNotEmpty()) java.io.File(path).parentFile?.parentFile?.absolutePath else null
                } catch (e: Exception) {
                    null
                }
            }
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.10.0" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
