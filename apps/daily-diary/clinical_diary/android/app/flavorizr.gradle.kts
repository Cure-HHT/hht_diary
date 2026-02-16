import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("environment")

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationId = "org.anspar.curehht.app.dev"
            resValue(type = "string", name = "app_name", value = "CureHHT Tracker DEV")
        }
        create("qa") {
            dimension = "environment"
            applicationId = "org.anspar.curehht.app.qa"
            resValue(type = "string", name = "app_name", value = "Diary QA")
        }
        create("uat") {
            dimension = "environment"
            applicationId = "org.anspar.curehht.app-uat"
            resValue(type = "string", name = "app_name", value = "Clinical Diary")
        }
        create("prod") {
            dimension = "environment"
            applicationId = "org.anspar.curehht.app"
            resValue(type = "string", name = "app_name", value = "Clinical Diary")
        }
    }
}