import java.net.HttpURLConnection
import java.net.URL

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/** 快速测试：false = 不下载 x265、不链 native x265（与 CMake -DLINKME_ENABLE_X265 同步）。正式功能改为 true。 */
val linkmeEnableX265 = false

// 使用 libx265.so：BeckYoung 的 .a 常缺少 x265_api_get 等导出；.so 含完整符号，CMake 优先链共享库。
fun x265LibOutputPath(abi: String): File {
    return file("../../native/linkme_av_core/third_party/x265/lib/$abi/libx265.so")
}

val x265MirrorUrls: Map<String, List<String>> = mapOf(
    "arm64-v8a" to listOf(
        "https://raw.githubusercontent.com/BeckYoung/x265_android_build/master/arm64-v8a/usr/local/lib/libx265.so",
        "https://cdn.jsdelivr.net/gh/BeckYoung/x265_android_build@master/arm64-v8a/usr/local/lib/libx265.so",
        "https://ghproxy.com/https://raw.githubusercontent.com/BeckYoung/x265_android_build/master/arm64-v8a/usr/local/lib/libx265.so",
        "https://mirror.ghproxy.com/https://raw.githubusercontent.com/BeckYoung/x265_android_build/master/arm64-v8a/usr/local/lib/libx265.so",
    ),
    "armeabi-v7a" to listOf(
        "https://raw.githubusercontent.com/BeckYoung/x265_android_build/master/armeabi-v7a/usr/local/lib/libx265.so",
        "https://cdn.jsdelivr.net/gh/BeckYoung/x265_android_build@master/armeabi-v7a/usr/local/lib/libx265.so",
        "https://ghproxy.com/https://raw.githubusercontent.com/BeckYoung/x265_android_build/master/armeabi-v7a/usr/local/lib/libx265.so",
        "https://mirror.ghproxy.com/https://raw.githubusercontent.com/BeckYoung/x265_android_build/master/armeabi-v7a/usr/local/lib/libx265.so",
    ),
)

fun downloadFile(url: String, dest: File) {
    dest.parentFile.mkdirs()
    val conn = (URL(url).openConnection() as HttpURLConnection).apply {
        requestMethod = "GET"
        setRequestProperty("User-Agent", "Gradle-LinkMe/1.0 (Android build)")
        instanceFollowRedirects = true
        connectTimeout = 60_000
        readTimeout = 120_000
    }
    try {
        conn.connect()
        val code = conn.responseCode
        if (code !in 200..299) {
            throw GradleException("HTTP $code when downloading: $url")
        }
        conn.inputStream.use { input ->
            dest.outputStream().use { output -> input.copyTo(output) }
        }
    } finally {
        conn.disconnect()
    }
}

fun ensureX265ForAbi(abi: String) {
    val outFile = x265LibOutputPath(abi)
    if (outFile.exists() && outFile.length() > 100 * 1024) {
        return
    }

    val urls = x265MirrorUrls[abi] ?: error("No x265 download urls configured for ABI: $abi")
    var lastError: Throwable? = null
    for (url in urls) {
        try {
            if (outFile.exists()) {
                outFile.delete()
            }
            downloadFile(url, outFile)
            if (outFile.exists() && outFile.length() > 100 * 1024) {
                return
            }
        } catch (t: Throwable) {
            lastError = t
        }
    }
    val causeMsg = lastError?.message?.let { " Last error: $it" } ?: ""
    throw GradleException(
        "Failed to download x265 for ABI=$abi (usually network/firewall/proxy; try VPN or manual file — see native/linkme_av_core/third_party/x265/README.md). " +
            "Expected: ${outFile.absolutePath}.$causeMsg",
        lastError,
    )
}

val ensureX265 by tasks.registering {
    group = "build setup"
    description = "Ensures prebuilt libx265.so (per ABI) before CMake; see third_party/x265/README.md."

    doLast {
        ensureX265ForAbi("arm64-v8a")
        ensureX265ForAbi("armeabi-v7a")
    }
}

android {
    namespace = "com.example.linkme_flutter"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    // 须与根 android/build.gradle.kts 中 linkmeJvm / KotlinCompile JVM_11 一致
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.linkme_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // CMake閰嶇疆 - Native闊宠棰戝簱
        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++17", "-frtti", "-fexceptions")
                arguments += listOf(
                    "-DANDROID_STL=c++_shared",
                    "-DANDROID_PLATFORM=android-21",
                    "-DLINKME_ENABLE_X265=" + if (linkmeEnableX265) "ON" else "OFF",
                )
            }
        }
        
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    if (linkmeEnableX265) {
        // 链 libx265.so 时须打进 APK，否则运行时 dlopen 失败
        sourceSets {
            getByName("main") {
                jniLibs.srcDir(file("../../native/linkme_av_core/third_party/x265/lib"))
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("../../native/linkme_av_core/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Disable code shrinking/obfuscation for stable packaging and to avoid
            // third-party plugin keep-rules issues in this release build.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

// configureCMake* 往往早于 preBuild；启用 x265 时须先下载 libx265.so
if (linkmeEnableX265) {
    tasks.configureEach {
        if (name != "ensureX265" &&
            (name == "preBuild" ||
                name.startsWith("configureCMake") ||
                name.startsWith("buildCMake"))
        ) {
            dependsOn(ensureX265)
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    implementation("com.amap.api:3dmap:8.1.0")
    implementation("com.amap.api:location:5.6.0")
}

