plugins {
    id("java")
    kotlin("jvm") version "2.2.0-RC2"
    id("org.jetbrains.intellij.platform") version "2.16.0"
}

repositories {
    mavenCentral()

    intellijPlatform {
        defaultRepositories()
    }
}

dependencies {
    intellijPlatform {
        intellijIdeaCommunity("2025.2")

        bundledPlugin("com.intellij.java")
    }
}

kotlin {
    jvmToolchain(21)
}

intellijPlatform {
    pluginConfiguration {
        version = "0.1.0"

        ideaVersion {
            sinceBuild = "251"
        }
    }
}
