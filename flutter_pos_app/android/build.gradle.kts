buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.3.15")
    }
}
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some third-party Android libraries still compile with source/target 8.
// On newer JDKs this emits obsolete option warnings; suppress only that lint.
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
        options.compilerArgs.add("-Xlint:-deprecation")
    }
    afterEvaluate {
        project.extensions.findByType<com.android.build.gradle.LibraryExtension>()?.let { ext ->
            if (ext.namespace == null) {
                val manifest = project.file("src/main/AndroidManifest.xml")
                if (manifest.exists()) {
                    val content = manifest.readText()
                    val match = java.util.regex.Pattern.compile("package=\"([^\"]+)\"").matcher(content)
                    if (match.find()) {
                        ext.namespace = match.group(1)
                    }
                }
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
