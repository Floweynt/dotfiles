package dev.nixsdk

import com.intellij.openapi.application.ApplicationManager
import com.intellij.openapi.application.WriteAction
import com.intellij.openapi.diagnostic.Logger
import com.intellij.openapi.project.Project
import com.intellij.openapi.projectRoots.JavaSdk
import com.intellij.openapi.projectRoots.ProjectJdkTable
import com.intellij.openapi.projectRoots.Sdk
import com.intellij.openapi.startup.ProjectActivity

class SyncActivity : ProjectActivity {
    private val log = Logger.getInstance(SyncActivity::class.java)

    private fun createSdk(entry: JdkEntry): Sdk {
        log.info("Creating SDK: name=${entry.name}, path=${entry.path}")
        return JavaSdk.getInstance().createJdk(
            entry.name,
            entry.path,
            false
        )
    }

    override suspend fun execute(project: Project) {
        val desired = ArrayList(GeneratedSdkManifest.jdks)
        val table = ProjectJdkTable.getInstance()

        val existingJavaSdks = table.allJdks
            .filter { it.sdkType is JavaSdk }

        ApplicationManager.getApplication().invokeLater {
            WriteAction.run<RuntimeException> {
                log.warn("Existing Java SDKs: ${existingJavaSdks.map { it.name + "@" + it.homePath }}")
                log.warn("Desired SDKs: ${desired.map { it.name + "@" + it.path }}")

                for (sdk in existingJavaSdks) {
                    val root = sdk.homePath
                    val name = sdk.name

                    val matched = desired.removeIf { x ->
                        x.name == name && x.path == root
                    }

                    if (!matched) {
                        log.warn("Removing SDK not in desired list: $name @ $root")
                        table.removeJdk(sdk)
                    } else {
                        log.warn("Keeping SDK: $name @ $root")
                    }
                }

                for (desiredSdk in desired) {
                    log.warn("Adding SDK: ${desiredSdk.name} @ ${desiredSdk.path}")
                    table.addJdk(createSdk(desiredSdk))
                }

                log.warn("SDK sync completed. Final SDK count=${table.allJdks.size}")
            }
        }
    }
}
