allprojects {
    repositories {
        google()
        // Зеркало Maven Central: прямой repo.maven.apache.org отдаёт 403
        // на запросы из России. Подробности — в settings.gradle.kts.
        maven("https://cache-redirector.jetbrains.com/maven-central")
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
