
rootProject.ext.set("kotlin_version", "1.8.10") 

buildscript {
    val agp_version by extra("7.3.0")
    val kotlin_version by extra("1.8.10")     
    
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        // A versão do Android Gradle Plugin
        classpath("com.android.tools.build:gradle:$agp_version")
        
        // A dependência do Kotlin Gradle Plugin
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Seu código de configuração de diretório de build e clean
val newBuildDir: org.gradle.api.file.Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: org.gradle.api.file.Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}