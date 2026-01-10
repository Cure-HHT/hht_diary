import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("environment")

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationId = "org.curehht.clinicaldiary.dev"
            resValue(type = "string", name = "app_name", value = "Diary DEV")
        }
        create("qa") {
            dimension = "environment"
            applicationId = "org.curehht.clinicaldiary.qa"
            resValue(type = "string", name = "app_name", value = "Diary QA")
        }
        create("uat") {
            dimension = "environment"
            applicationId = "org.curehht.clinicaldiary.uat"
            resValue(type = "string", name = "app_name", value = "Clinical Diary")
        }
        create("prod") {
            dimension = "environment"
            applicationId = "org.curehht.clinicaldiary"
            resValue(type = "string", name = "app_name", value = "Clinical Diary")
        }
    }
}