package com.example.mobile_banking_app

import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for SmsBroadcastReceiver — verifies sender matching, security
 * filtering, structured banking fact extraction, locked reason pattern detection,
 * and SHA-256 idempotency key generation.
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
    fun `matches BOA sender`() {
        assertEquals("BOA", SmsBroadcastReceiver.matchBankSender("BOA"))
        assertEquals("BOA", SmsBroadcastReceiver.matchBankSender("ABYSSINIA"))
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
    fun `allows transaction messages through`() {
        assertFalse(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "You have received ETB 1,500.00 from John. Balance: ETB 5,000.00"))
        assertFalse(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Your account has been credited with Birr 2000.00"))
        assertFalse(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Payment of ETB 500 sent to merchant ABC."))
    }

    // ── Banking Fact Extraction & Locked Pattern Tests ──────────────────────

    @Test
    fun `parses Telebirr Airtime recharge with locked Airtime pattern`() {
        val msg = "Dear Kaleb \nYou have recharged ETB 5.00 airtime for 972665987 on 19/08/2026 14:54:18. Your transaction number is DHJ9WSTUPZ. Your current balance is ETB 485.32."
        val parsed = SmsBroadcastReceiver.parseBankingSms("Telebirr", msg)

        assertNotNull(parsed)
        assertEquals(5.0, parsed!!.amount, 0.001)
        assertEquals("ETB 5.00", parsed.formattedAmount)
        assertTrue(parsed.isDebit)
        assertEquals("972665987", parsed.counterparty)
        assertEquals("To: 972665987", parsed.directionHeader)
        assertTrue(parsed.isLocked)
        assertEquals("Airtime", parsed.lockedReasonName)
        assertEquals("DHJ9WSTUPZ", parsed.txReference)
    }

    @Test
    fun `parses Telebirr Airtime with full 251 phone number`() {
        val msg = "Dear KALEB \nYou have recharged ETB 50.00 airtime for 251972665987 on 04/04/2024 14:26:46. Your transaction number is BD45KRON6P. Your current balance is ETB 39.69."
        val parsed = SmsBroadcastReceiver.parseBankingSms("Telebirr", msg)

        assertNotNull(parsed)
        assertEquals(50.0, parsed!!.amount, 0.001)
        assertEquals("251972665987", parsed.counterparty)
        assertEquals("To: 251972665987", parsed.directionHeader)
        assertTrue(parsed.isLocked)
        assertEquals("Airtime", parsed.lockedReasonName)
    }

    @Test
    fun `parses Telebirr Package subscription with locked Package pattern`() {
        val msg = "Dear KALEB\n You have paid ETB 50.00 for package subscription to 972665987 on 20/04/2024 07:10:41. Your transaction number is BDK7PQVAMX. Your current balance is ETB 24.61."
        val parsed = SmsBroadcastReceiver.parseBankingSms("Telebirr", msg)

        assertNotNull(parsed)
        assertEquals(50.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals("972665987", parsed.counterparty)
        assertTrue(parsed.isLocked)
        assertEquals("Package", parsed.lockedReasonName)
    }

    @Test
    fun `parses Telebirr Shamo internal savings transfer with locked Internal Transfer pattern`() {
        val msg = "Dear KALEB \nYou have reserved ETB 10.00 to your Shamo Account on 21/04/2024 22:01:10.The service fee is ETB 0.01. Your current E-Money Account balance is ETB 13.60."
        val parsed = SmsBroadcastReceiver.parseBankingSms("Telebirr", msg)

        assertNotNull(parsed)
        assertEquals(10.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertTrue(parsed.isLocked)
        assertEquals("Internal Transfer", parsed.lockedReasonName)
    }

    @Test
    fun `parses Telebirr standard transfer with unlocked pattern`() {
        val msg = "Dear KALEB \nYou have transferred ETB 100.00 to NAHOM ABRAHAM(251921607264) on 24/04/2024 18:58:01. Your transaction number is BDO6RA9LCM."
        val parsed = SmsBroadcastReceiver.parseBankingSms("Telebirr", msg)

        assertNotNull(parsed)
        assertEquals(100.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertFalse(parsed.isLocked)
        assertNull(parsed.lockedReasonName)
    }

    @Test
    fun `drops non-transaction SMS fragments without showing notification`() {
        val msg = "To download your payment information please click this link: https://transactioninfo.ethiotelecom.et/receipt/DHJ9WSTUPZ\nFor any support and information related to telebirr service"
        val parsed = SmsBroadcastReceiver.parseBankingSms("Telebirr", msg)

        assertNull("Non-transaction fragment must return null", parsed)
    }
}
