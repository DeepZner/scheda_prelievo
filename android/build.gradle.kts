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
    if (project.name != "app") {
        val applyCompileSdk = {
            val android = extensions.findByName("android")
            if (android != null) {
                try {
                    val method = android.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                    method.invoke(android, 36)
                } catch (e: Exception) {
                    try {
                        val method = android.javaClass.getMethod("setCompileSdk", Int::class.java)
                        method.invoke(android, 36)
                    } catch (_: Exception) {}
                }
            }
        }
        if (state.executed) {
            applyCompileSdk()
        } else {
            afterEvaluate { applyCompileSdk() }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
