allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Pin transitive AndroidX dependencies to versions compatible with AGP 8.7.3.
// Newer versions (pulled by image_picker/flutter_image_compress) require AGP 8.9.1+.
subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.15.0")
            force("androidx.core:core-ktx:1.15.0")
            force("androidx.activity:activity:1.9.3")
            force("androidx.activity:activity-ktx:1.9.3")
        }
    }
}

// Align Kotlin JVM target with Java target in plugin subprojects.
// Prevents JVM-target mismatch errors where plugins set Java and Kotlin
// to different targets (e.g. receive_sharing_intent: Java 1.8 + Kotlin 17).
// Skip :app — it has explicit JVM 11 config and triggers "already evaluated"
// with afterEvaluate due to evaluationDependsOn(":app") above.
subprojects {
    if (name != "app") {
        afterEvaluate {
            val javaTarget = tasks.withType<JavaCompile>()
                .firstOrNull()?.targetCompatibility ?: "17"
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                kotlinOptions.jvmTarget = javaTarget
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
