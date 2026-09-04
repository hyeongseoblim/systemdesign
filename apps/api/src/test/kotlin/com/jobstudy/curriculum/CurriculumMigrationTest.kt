package com.jobstudy.curriculum

import org.flywaydb.core.Flyway
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers

@Testcontainers(disabledWithoutDocker = true)
class CurriculumMigrationTest {

    @Test
    fun `fresh database migrates to unique pending curriculum topics`() {
        Flyway.configure()
            .dataSource(postgres.jdbcUrl, postgres.username, postgres.password)
            .locations("classpath:db/migration")
            .load()
            .migrate()

        postgres.createConnection("").use { connection ->
            connection.createStatement().use { statement ->
                statement.executeQuery(
                    """
                    SELECT count(*) AS total,
                           count(DISTINCT topic_key) AS unique_keys,
                           count(*) FILTER (WHERE resolution_status = 'PENDING') AS pending
                    FROM curriculum_topics
                    """.trimIndent(),
                ).use { rows ->
                    rows.next()
                    assertEquals(384, rows.getInt("total"))
                    assertEquals(384, rows.getInt("unique_keys"))
                    assertEquals(384, rows.getInt("pending"))
                }
            }
        }
    }

    companion object {
        @Container
        @JvmStatic
        val postgres = PostgreSQLContainer<Nothing>("postgres:16-alpine")
    }
}
