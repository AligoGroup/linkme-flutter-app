import java.io.File
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

// 与 app/build.gradle.kts 中 compileOptions / kotlinOptions / compileSdk 保持一致（勿在此处改 :app 的 android{}）
val linkmeJvm = JavaVersion.VERSION_11
// 将 library 的 Java 升到 9+ 时 AGP 要求 compileSdk >= 30；与主工程 compileSdk=36 对齐，避免旧插件仍为 28/29
val linkmeCompileSdk = 36

/** 反射设置 compileSdk（AGP 8+ 多为 setCompileSdk，旧为 setCompileSdkVersion） */
fun forceCompileSdk(androidExt: Any, sdk: Int) {
    var last: ReflectiveOperationException? = null
    for (methodName in listOf("setCompileSdk", "setCompileSdkVersion")) {
        try {
            androidExt.javaClass.getMethod(methodName, Int::class.javaPrimitiveType).invoke(androidExt, sdk)
            return
        } catch (e: ReflectiveOperationException) {
            last = e
        }
    }
    throw last ?: IllegalStateException("forceCompileSdk: no setter on ${androidExt.javaClass.name}")
}

// 勿在此重复声明 com.android.application / com.android.library（settings 已解析 AGP），否则会报 classpath 上版本冲突。
// 仅 kotlin-android 用于解析 KotlinCompile 等类型。
plugins {
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// AGP 8+ 要求每个 Android library 声明 namespace；部分旧插件未声明。
// 在 com.android.library 应用时注入（不注册 afterEvaluate，避免与 evaluationDependsOn(":app") 冲突）：
// 1) 显式映射 legacyPluginNamespaces
// 2) 否则若仍无 namespace，从 android/src/main/AndroidManifest.xml 读取 package
val legacyPluginNamespaces =
    mapOf(
        "flutter_app_badger" to "fr.g123k.flutterappbadge.flutterappbadger",
        // 0.5.3 等旧版无 namespace，group 为 xyz.justsoft.video_thumbnail（见 justsoft/video_thumbnail）
        "video_thumbnail" to "xyz.justsoft.video_thumbnail",
    )

subprojects {
    plugins.withId("com.android.library") {
        extensions.findByName("android")?.let { androidExt ->
            fun setNamespaceValue(value: String) {
                try {
                    androidExt.javaClass
                        .getMethod("setNamespace", String::class.java)
                        .invoke(androidExt, value)
                } catch (e: ReflectiveOperationException) {
                    logger.warn("Could not set namespace for $name: ${e.message}")
                }
            }
            val explicitNs = legacyPluginNamespaces[name]
            if (explicitNs != null) {
                setNamespaceValue(explicitNs)
            } else {
                val existingNs: String? =
                    try {
                        androidExt.javaClass.getMethod("getNamespace").invoke(androidExt) as? String
                    } catch (_: Exception) {
                        null
                    }
                if (existingNs.isNullOrBlank()) {
                    val manifestFile = File(projectDir, "src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        Regex("""package\s*=\s*"([^"]+)"""")
                            .find(manifestFile.readText())
                            ?.groupValues
                            ?.get(1)
                            ?.let { pkg -> setNamespaceValue(pkg) }
                    }
                }
            }
        }
    }
}

// Kotlin JVM：与 linkmeJvm 一致（各子工程在应用 kotlin-android 时注册）
subprojects {
    plugins.withId("org.jetbrains.kotlin.android") {
        tasks.withType<KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(JvmTarget.JVM_11)
        }
    }
}

// Java compileOptions + compileSdk：必须在各插件 android{} 执行之后再改（见上）。
// compileSdk<30 且 Java 9+ 会报：In order to compile Java 9+ source, please set compileSdkVersion to 30 or above（如 flutter_app_badger）。
gradle.afterProject {
    if (!plugins.hasPlugin("com.android.library")) {
        return@afterProject
    }
    try {
        val androidExt = extensions.findByName("android") ?: return@afterProject
        forceCompileSdk(androidExt, linkmeCompileSdk)
        val co = androidExt.javaClass.getMethod("getCompileOptions").invoke(androidExt)
        co.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java).invoke(co, linkmeJvm)
        co.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java).invoke(co, linkmeJvm)
    } catch (e: Exception) {
        logger.warn("linkme: 未能为 ${path} 对齐 SDK/Java: ${e.message}")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
