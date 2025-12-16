import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.gradle.api.plugins.JavaPlugin
import org.gradle.api.plugins.JavaPluginExtension

plugins {
    // Add the dependency for the Google services Gradle plugin
    id("com.google.gms.google-services") version "4.3.15" apply false
    // Android Gradle Plugin - using existing version
    id("com.android.application") version "8.7.2" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

allprojects {
    repositories {
        // Try multiple repository sources
        mavenCentral()
        google()
        gradlePluginPortal()
        maven { 
            url = uri("https://maven.google.com")
            isAllowInsecureProtocol = false
        }
        maven { 
            url = uri("https://repo1.maven.org/maven2/")
            isAllowInsecureProtocol = false
        }
        maven { url = uri("https://jitpack.io") }
        // Add JCenter as fallback for legacy dependencies
        @Suppress("DEPRECATION")
        jcenter() {
            content {
                // Only allow specific groups that might need JCenter
                includeModule("org.jetbrains.trove4j", "trove4j")
            }
        }
    }
    
    // Configure Gradle to handle network timeouts better
    configurations.all {
        resolutionStrategy {
            cacheDynamicVersionsFor(10, "minutes")
            cacheChangingModulesFor(4, "hours")
            // Force refresh of failing dependencies
            force("com.android.tools.external.com-intellij:kotlin-compiler:31.7.2")
        }
    }
    
    // Add system properties for better network handling
    System.setProperty("org.gradle.internal.http.connectionTimeout", "120000")
    System.setProperty("org.gradle.internal.http.socketTimeout", "120000")
    System.setProperty("org.gradle.daemon.performance.enable-monitoring", "false")
    
    // Force all subprojects to use JVM target 17
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }
    
    // Configure Java toolchain for all subprojects
    plugins.withType<JavaPlugin> {
        extensions.configure<JavaPluginExtension> {
            toolchain {
                languageVersion.set(JavaLanguageVersion.of(17))
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
