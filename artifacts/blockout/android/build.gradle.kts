allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val sharedBuildDirectory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(sharedBuildDirectory)

subprojects {
    val projectBuildDirectory = sharedBuildDirectory.dir(project.name)
    project.layout.buildDirectory.value(projectBuildDirectory)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
