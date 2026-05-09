package com.minepacu.craftpresence

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemBarStyleTest {
    @Test
    fun statusBarScrimsUseThemeBackdropsWithReadableAlpha() {
        assertEquals(0xE6, LightStatusBarScrim ushr 24)
        assertEquals(0xE6, DarkStatusBarScrim ushr 24)
        assertEquals(0xFBFDF8, LightStatusBarScrim and 0x00FFFFFF)
        assertEquals(0x101411, DarkStatusBarScrim and 0x00FFFFFF)
        assertTrue(LightStatusBarScrim != 0x00000000)
        assertTrue(DarkStatusBarScrim != 0x00000000)
    }
}
