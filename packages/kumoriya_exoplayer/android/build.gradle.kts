group = "dev.kumoriya.exoplayer"
version = "0.0.1"

buildscript {
    val kotlinVersion = "2.2.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
    id("org.jetbrains.kotlin.plugin.serialization") version "2.2.20"
}

android {
    namespace = "dev.kumoriya.exoplayer"

    compileSdk = 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 21
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

// Keep in sync with whatever `media_kit_libs_android_video` resolves to in
// the app. On mismatch, Gradle will upgrade the plugin's runtime classes
// to the higher version and any API drift between versions (e.g. added
// abstract method) crashes with AbstractMethodError at runtime.
val media3Version = "1.9.2"
val okhttpVersion = "4.12.0"
val coroutinesVersion = "1.8.1"
val serializationVersion = "1.7.3"

dependencies {
    // Fases 0-1: core playback + HLS/DASH/MP4 auto-detect + OkHttp datasource.
    // Cast / session / downloads / workmanager arrive in their owning phase.
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
    implementation("androidx.media3:media3-exoplayer-dash:$media3Version")
    implementation("androidx.media3:media3-datasource-okhttp:$media3Version")

    // Downloader: HLS remux. media3-transformer covers the MPEG-TS path
    // (HlsRemuxer); media3-muxer + media3-extractor power the direct
    // fMP4 transmux pipe (Mp4Transmuxer) without going through a player.
    implementation("androidx.media3:media3-transformer:$media3Version")
    implementation("androidx.media3:media3-muxer:$media3Version")
    implementation("androidx.media3:media3-extractor:$media3Version")

    // Fase 2: native anime.nexus pipeline replaces the Dart loopback proxy.
    // OkHttp is already pulled in transitively by media3-datasource-okhttp but
    // we depend on it explicitly to stay in control of the version + expose
    // OkHttp's WebSocket and CookieJar APIs to the nexus module.
    implementation("com.squareup.okhttp3:okhttp:$okhttpVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:$coroutinesVersion")

    // Downloader: atomic state manifest persistence.
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:$serializationVersion")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:$coroutinesVersion")
    testImplementation("com.squareup.okhttp3:mockwebserver:$okhttpVersion")
}
