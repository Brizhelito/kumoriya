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

// ── Media3 version pin ──────────────────────────────────────────────────────
// All subprojects must resolve to the same Media3 version to avoid
// AbstractMethodError at runtime when the app bundles a newer version than
// the plugin was compiled against.
val media3Pin = "1.9.2"
subprojects {
    configurations.configureEach {
        resolutionStrategy {
            force(
                "androidx.media3:media3-common:$media3Pin",
                "androidx.media3:media3-exoplayer:$media3Pin",
                "androidx.media3:media3-exoplayer-hls:$media3Pin",
                "androidx.media3:media3-exoplayer-dash:$media3Pin",
                "androidx.media3:media3-datasource:$media3Pin",
                "androidx.media3:media3-datasource-okhttp:$media3Pin",
                "androidx.media3:media3-transformer:$media3Pin",
                "androidx.media3:media3-muxer:$media3Pin",
            )
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
