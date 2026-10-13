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

// Plugins such as isar_flutter_libs 3.1.0+1 predate AGP 8: no namespace,
// and compileSdk 30, which cannot link AndroidX resources like android:attr/lStar.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
            if (namespace.isNullOrEmpty()) {
                namespace = project.group.toString()
            }
        }
        extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension>(
            "androidComponents",
        ) {
            finalizeDsl { extension ->
                if ((extension.compileSdk ?: 0) < 36) {
                    extension.compileSdk = 36
                }
                extension.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
                extension.compileOptions.targetCompatibility = JavaVersion.VERSION_17
                project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                    compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
