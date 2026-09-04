package com.jobstudy.card

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

class CursorTest {

    @Test
    fun `encode then decode round-trips publishedAt millis and id`() {
        val ts = OffsetDateTime.of(2026, 4, 21, 9, 0, 0, 0, ZoneOffset.UTC)
        val id = UUID.randomUUID()

        val encoded = Cursor.encode(ts, id)
        val decoded = Cursor.decode(encoded)

        requireNotNull(decoded)
        assertEquals(ts.toInstant().toEpochMilli(), decoded.first.toInstant().toEpochMilli())
        assertEquals(id, decoded.second)
    }

    @Test
    fun `decode returns null for blank or malformed cursor`() {
        assertNull(Cursor.decode(null))
        assertNull(Cursor.decode(""))
        assertNull(Cursor.decode("!!!not-base64!!!"))
        assertNull(Cursor.decode("bm9jb2xvbg")) // base64 of "nocolon" — no ':' separator
    }

    @Test
    fun `shuffle cursor round-trips seed and offset`() {
        val encoded = ShuffleCursor.encode(seed = 20260904, offset = 40)

        assertEquals(ShuffleCursorValue(seed = 20260904, offset = 40), ShuffleCursor.decode(encoded))
        assertNull(Cursor.decode(encoded))
    }

    @Test
    fun `shuffle cursor rejects malformed and negative offsets`() {
        assertNull(ShuffleCursor.decode(null))
        assertNull(ShuffleCursor.decode("!!!not-base64!!!"))
        assertNull(ShuffleCursor.decode(java.util.Base64.getUrlEncoder().encodeToString("shuffle:1:-1".toByteArray())))
    }
}
