package com.example.mobile_banking_app

import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for SmsBroadcastReceiver — verifies sender matching, security
 * filtering, and SHA-256 idempotency key generation without needing an
 * Android emulator.
 */
class SmsBroadcastReceiverTest {

    // ── Sender Matching ─────────────────────────────────────────────────────

    @Test
    fun `matches CBE sender`() {
        assertEquals("CBE", SmsBroadcastReceiver.matchBankSender("CBE"))
    }

    @Test
    fun `matches Telebirr sender`() {
        assertEquals("Telebirr", SmsBroadcastReceiver.matchBankSender("TELEBIRR"))
    }

    @Test
    fun `matches Telebirr short code 127`() {
        assertEquals("Telebirr", SmsBroadcastReceiver.matchBankSender("127"))
    }

    @Test
    fun `matches CBE Birr sender`() {
        assertEquals("CBE Birr", SmsBroadcastReceiver.matchBankSender("CBEBIRR"))
    }

    @Test
    fun `matches CBE BIRR with space`() {
        assertEquals("CBE Birr", SmsBroadcastReceiver.matchBankSender("CBE BIRR"))
    }

    @Test
    fun `matches Ahadu Bank sender`() {
        assertEquals("Ahadu Bank", SmsBroadcastReceiver.matchBankSender("AHADU"))
    }

    @Test
    fun `case insensitive sender matching`() {
        assertEquals("CBE", SmsBroadcastReceiver.matchBankSender("cbe"))
        assertEquals("Telebirr", SmsBroadcastReceiver.matchBankSender("Telebirr"))
    }

    @Test
    fun `rejects personal phone numbers`() {
        assertNull(SmsBroadcastReceiver.matchBankSender("+251911234567"))
        assertNull(SmsBroadcastReceiver.matchBankSender("0911234567"))
        assertNull(SmsBroadcastReceiver.matchBankSender("251911234567"))
    }

    @Test
    fun `rejects null and blank senders`() {
        assertNull(SmsBroadcastReceiver.matchBankSender(null))
        assertNull(SmsBroadcastReceiver.matchBankSender(""))
        assertNull(SmsBroadcastReceiver.matchBankSender("   "))
    }

    @Test
    fun `rejects unknown sender`() {
        assertNull(SmsBroadcastReceiver.matchBankSender("AMAZON"))
        assertNull(SmsBroadcastReceiver.matchBankSender("Google"))
    }

    // ── Security Message Filtering ──────────────────────────────────────────

    @Test
    fun `detects OTP messages`() {
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Your OTP code is 123456. Do not share it."))
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Your OTP is 5678"))
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "One-Time Password: 9999"))
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "One time password for login is 4321"))
    }

    @Test
    fun `detects PIN and password failure messages`() {
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Your PIN or password is incorrect. Please try again."))
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Incorrect PIN entered."))
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Invalid password. Account locked."))
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Wrong PIN detected."))
    }

    @Test
    fun `detects PIN reset and change messages`() {
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Please reset your PIN to continue."))
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Password reset link sent."))
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Change your PIN for security."))
    }

    @Test
    fun `detects auth and verification codes`() {
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Your auth code is 456789"))
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Your verification code is 1234. Enter it now."))
    }

    @Test
    fun `allows transaction messages through`() {
        assertFalse(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "You have received ETB 1,500.00 from John. Balance: ETB 5,000.00"))
        assertFalse(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Your account has been credited with Birr 2000.00"))
        assertFalse(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Payment of ETB 500 sent to merchant ABC."))
    }

    // ── SHA-256 ID Generation ───────────────────────────────────────────────

    @Test
    fun `generates consistent SHA-256 IDs`() {
        val id1 = SmsBroadcastReceiver.generateId("CBE", 1000L, "Hello")
        val id2 = SmsBroadcastReceiver.generateId("CBE", 1000L, "Hello")
        assertEquals(id1, id2)
    }

    @Test
    fun `generates different IDs for different inputs`() {
        val id1 = SmsBroadcastReceiver.generateId("CBE", 1000L, "Hello")
        val id2 = SmsBroadcastReceiver.generateId("CBE", 1001L, "Hello")
        val id3 = SmsBroadcastReceiver.generateId("CBE", 1000L, "Hello!")
        assertNotEquals(id1, id2)
        assertNotEquals(id1, id3)
    }

    @Test
    fun `SHA-256 ID is 64 character hex string`() {
        val id = SmsBroadcastReceiver.generateId("CBE", 1000L, "Test message")
        assertEquals(64, id.length)
        assertTrue(id.matches(Regex("[0-9a-f]{64}")))
    }

    // ── Amount & Direction Formatting ─────────────────────────────────────

    @Test
    fun `extracts formatted ETB amount correctly`() {
        assertEquals("ETB 1,500.00", SmsBroadcastReceiver.extractAmount("You received ETB 1500.00 from John."))
        assertEquals("ETB 2,000.50", SmsBroadcastReceiver.extractAmount("Account credited Birr 2,000.50."))
        assertEquals("ETB 500.00", SmsBroadcastReceiver.extractAmount("Paid Br. 500.00 for goods."))
    }

    @Test
    fun `determines direction header correctly`() {
        assertEquals("From: Telebirr", SmsBroadcastReceiver.getDirectionHeader("Telebirr", "You received ETB 500 from Ali"))
        assertEquals("For: CBE", SmsBroadcastReceiver.getDirectionHeader("CBE", "You have debited ETB 200 to Merchant"))
        assertEquals("For: Telebirr", SmsBroadcastReceiver.getDirectionHeader("Telebirr", "Payment of ETB 100 sent to merchant"))
    }
}
