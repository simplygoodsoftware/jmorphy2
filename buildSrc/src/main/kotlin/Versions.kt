import org.gradle.api.JavaVersion
import org.gradle.api.Project

data class EsVersion(
    val major: Int,
    val minor: Int,
    val patch: Int = 0
) : Comparable<EsVersion> {
    companion object {
        fun parse(version: String): EsVersion {
            val versionParts = version.split('.')
            return EsVersion(
                versionParts[0].toInt(),
                versionParts[1].toInt(),
                versionParts[2].toInt()
            )
        }
    }

    override fun toString(): String {
        return "$major.$minor.$patch"
    }

    override fun compareTo(other: EsVersion): Int {
        if (major != other.major) {
            return major.compareTo(other.major)
        }
        if (minor != other.minor) {
            return minor.compareTo(other.minor)
        }
        return patch.compareTo(other.patch)
    }
}

object Versions {
    val java = JavaVersion.VERSION_17

    val commonsCodec = "1.17.1"
    val commonsIo = "2.17.0"
    val noggit = "0.8"
    val caffeine = "3.1.8"

    val junit = "4.13.2"

    val jmhGradlePlugin = "0.6.5"

    val esLuceneVersions = mapOf(
        EsVersion(8, 6) to "9.4.2",
        EsVersion(8, 7) to "9.5.0",
        EsVersion(8, 8) to "9.6.0",
        EsVersion(8, 9) to "9.7.0",
        EsVersion(8, 10) to "9.7.0",
        EsVersion(8, 11) to "9.8.0",
        EsVersion(8, 12) to "9.9.1",
        EsVersion(8, 13) to "9.10.0",
        EsVersion(8, 14) to "9.10.0",
        EsVersion(8, 15) to "9.11.1",
        EsVersion(8, 16) to "9.12.0",
        EsVersion(8, 17) to "9.12.0",
        EsVersion(8, 18) to "9.12.1",
        EsVersion(8, 19) to "9.12.2",
    )
}

fun Project.getLibraryVersion(): String {
    return rootProject.file("project.version").readLines().first().toUpperCase().removeSuffix("-SNAPSHOT")
}

fun Project.getElasticsearchDefaultVersion(): String {
    return rootProject.file("es.version").readLines().first()
}

fun Project.getElasticsearchVersion(): String {
    return properties["esVersion"]?.toString() ?: getElasticsearchDefaultVersion()
}

fun Project.getLuceneVersion(): String {
    val curEsVersion = EsVersion.parse(getElasticsearchVersion())
    var lastLuceneVersion: String? = null
    for ((esVersion, luceneVersion) in Versions.esLuceneVersions) {
        if (curEsVersion < esVersion) {
            break
        }
        lastLuceneVersion = luceneVersion
    }
    return lastLuceneVersion
        ?: throw IllegalStateException("Invalid Elasticsearch version: $curEsVersion")
}
