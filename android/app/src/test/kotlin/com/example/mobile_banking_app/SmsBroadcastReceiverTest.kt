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
    fun `matches Nib Bank sender`() {
        assertEquals("Nib Bank", SmsBroadcastReceiver.matchBankSender("NIB"))
        assertEquals("Nib Bank", SmsBroadcastReceiver.matchBankSender("NIB BANK"))
        assertEquals("Nib Bank", SmsBroadcastReceiver.matchBankSender("NIBBANK"))
        assertEquals("Nib Bank", SmsBroadcastReceiver.matchBankSender("nib"))
    }

    @Test
    fun `matches Bunna Bank sender`() {
        assertEquals("Bunna Bank", SmsBroadcastReceiver.matchBankSender("BUNNA"))
        assertEquals("Bunna Bank", SmsBroadcastReceiver.matchBankSender("BUNNA BANK"))
        assertEquals("Bunna Bank", SmsBroadcastReceiver.matchBankSender("Bunna Bank"))
        assertEquals("Bunna Bank", SmsBroadcastReceiver.matchBankSender("BUNA"))
        assertEquals("Bunna Bank", SmsBroadcastReceiver.matchBankSender("Buna Bank"))
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
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Your OTP : 940026"))
        assertTrue(SmsBroadcastReceiver.isSecurityOrAuthMessage(
            "Dear Customer, You have logged in into your BOA Online Banking access on 28/07/2023 10:14:00."))
    }

    @Test
    fun `detects marketing and greetings in isIgnoredMessage`() {
        assertTrue(SmsBroadcastReceiver.isIgnoredMessage(
            "We Wish You A Happy Ethiopian New Year. Thank you for Choosing Us.\nAwash Bank"))
        assertTrue(SmsBroadcastReceiver.isIgnoredMessage(
            "Borrow up to 50,000 ETB without collateral with Telebirr Sanduq"))
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
        assertFalse(parsed.isLocked)
        assertEquals("Airtime", parsed.lockedReasonName)
        assertEquals("DHJ9WSTUPZ", parsed.txReference)
        assertEquals(485.32, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses Telebirr Airtime with full 251 phone number`() {
        val msg = "Dear KALEB \nYou have recharged ETB 50.00 airtime for 251972665987 on 04/04/2024 14:26:46. Your transaction number is BD45KRON6P. Your current balance is ETB 39.69."
        val parsed = SmsBroadcastReceiver.parseBankingSms("Telebirr", msg)

        assertNotNull(parsed)
        assertEquals(50.0, parsed!!.amount, 0.001)
        assertEquals("251972665987", parsed.counterparty)
        assertEquals("To: 251972665987", parsed.directionHeader)
        assertFalse(parsed.isLocked)
        assertEquals("Airtime", parsed.lockedReasonName)
        assertEquals(39.69, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses Telebirr Package subscription with unlocked Package pattern`() {
        val msg = "Dear KALEB\n You have paid ETB 50.00 for package subscription to 972665987 on 20/04/2024 07:10:41. Your transaction number is BDK7PQVAMX. Your current balance is ETB 24.61."
        val parsed = SmsBroadcastReceiver.parseBankingSms("Telebirr", msg)

        assertNotNull(parsed)
        assertEquals(50.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals("972665987", parsed.counterparty)
        assertFalse(parsed.isLocked)
        assertEquals("Package", parsed.lockedReasonName)
        assertEquals(24.61, parsed.totalBalance, 0.001)
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
        assertEquals(13.60, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses Telebirr standard transfer with unlocked pattern and cleaned counterparty`() {
        val msg = "Dear KALEB \nYou have transferred ETB 100.00 to NAHOM ABRAHAM(251921607264) on 24/04/2024 18:58:01. Your transaction number is BDO6RA9LCM."
        val parsed = SmsBroadcastReceiver.parseBankingSms("Telebirr", msg)

        assertNotNull(parsed)
        assertEquals(100.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals("NAHOM ABRAHAM", parsed.counterparty)
        assertFalse(parsed.isLocked)
        assertNull(parsed.lockedReasonName)
    }

    @Test
    fun `parses Telebirr incoming transfer and strips masked phone and reference code`() {
        val msg = "Dear Kaleb \nYou have received ETB 1.00 from kaleb teklemariyam(2519****9104) 101813 on 30/08/2026 21:29:13. Your transaction number is DHU9AZIHIL. Your current E-Money Account balance is ETB 4.32.\nThank you for using telebirr\nEthio telecom"
        val parsed = SmsBroadcastReceiver.parseBankingSms("Telebirr", msg)

        assertNotNull(parsed)
        assertEquals(1.0, parsed!!.amount, 0.001)
        assertFalse(parsed.isDebit)
        assertEquals("kaleb teklemariyam", parsed.counterparty)
        assertEquals("DHU9AZIHIL", parsed.txReference)
        assertEquals(4.32, parsed.totalBalance, 0.001)
        assertFalse(parsed.isLocked)
    }

    @Test
    fun `parses CBE credit with total balance`() {
        val msg = "Dear Customer, your account 1000*** has been credited with ETB 500.00 from JOHN DOE on 12/03/2024. Your Current Balance is ETB 5,784.66. Ref: FT123456"
        val parsed = SmsBroadcastReceiver.parseBankingSms("CBE", msg)

        assertNotNull(parsed)
        assertEquals(500.0, parsed!!.amount, 0.001)
        assertFalse(parsed.isDebit)
        assertEquals(5784.66, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses CBE received transfer with counterparty in parentheses`() {
        val msg = "Dear Dawit Habtemu Tewendie You have received ETB 2,000.00 from account 1********9698 (Fewaz Seid Ahmed) to your account 1*********2555 on 04/09/2026 at 20:30:15. Your Current Balance is ETB 10,000.00. Thank you for Banking with CBE! https://apps.cbe.com.et:100/?id=FT26248CBE1234"
        val parsed = SmsBroadcastReceiver.parseBankingSms("CBE", msg)

        assertNotNull(parsed)
        assertEquals(2000.0, parsed!!.amount, 0.001)
        assertFalse(parsed.isDebit)
        assertEquals("Fewaz Seid Ahmed", parsed.counterparty)
        assertEquals(10000.0, parsed.totalBalance, 0.001)
        assertEquals("FT26248CBE1234", parsed.txReference)
    }

    @Test
    fun `parses CBE debit transaction pattern`() {
        val msg = "Dear Dawit Habtemu Tewendie A debit transaction of ETB 200.0. has occurred on your account 1*********2555 on 03/09/2026 at 18:20:10. Your Current Balance is ETB 8,000.00. Thank you for Banking with CBE!"
        val parsed = SmsBroadcastReceiver.parseBankingSms("CBE", msg)

        assertNotNull(parsed)
        assertEquals(200.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals("ATM or Other", parsed.counterparty)
        assertEquals(8000.0, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses BOA credit with total balance`() {
        val msg = "Dear customer, your account has been credited with ETB 1,000.00 by ALMAZ on 15-May-2024. Available Balance is ETB 12,345.67. trx=TRX9988"
        val parsed = SmsBroadcastReceiver.parseBankingSms("BOA", msg)

        assertNotNull(parsed)
        assertEquals(1000.0, parsed!!.amount, 0.001)
        assertFalse(parsed.isDebit)
        assertEquals(12345.67, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses BOA branch credit with Avail bal and counterparty`() {
        val msg = "Dear Customer, A/C No. 8*****27 has been credited By BINALF FANTAHUN EMIRU with ETB 6,000.00 on 19/08/2023 @ALAMURA BRANCH. Info: Transfer-payment. Avail. bal: ETB 6,034.33. Join our telegram channel for latest updates https://t.me/BoAEth\n     Bank of Abyssinia. for further enquires please call us Toll free (24/7) on 8397."
        val parsed = SmsBroadcastReceiver.parseBankingSms("BOA", msg)

        assertNotNull(parsed)
        assertEquals(6000.0, parsed!!.amount, 0.001)
        assertFalse(parsed.isDebit)
        assertEquals("BINALF FANTAHUN EMIRU", parsed.counterparty)
        assertEquals(6034.33, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses BOA e-banking department credit with Telebirr`() {
        val msg = "Dear Customer, A/C No. 8*****27 has been credited By A/R TELE BIRRwith ETB 700.00 on 05/08/2023 @E-BANKING DEPARTMENT. Info: Telebirr to BoA Account-20230805155052. Avail. bal: ETB 3,692.33."
        val parsed = SmsBroadcastReceiver.parseBankingSms("BOA", msg)

        assertNotNull(parsed)
        assertEquals(700.0, parsed!!.amount, 0.001)
        assertFalse(parsed.isDebit)
        assertEquals("A/R TELE BIRR", parsed.counterparty)
        assertEquals("20230805155052", parsed.txReference)
        assertEquals(3692.33, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses Ahadu Bank debit with total balance`() {
        val msg = "Dear customer, your Ahadu account has been debited ETB 250.00 on 10/01/2024. Current balance is ETB 8,900.50. Ref: AH7766"
        val parsed = SmsBroadcastReceiver.parseBankingSms("Ahadu Bank", msg)

        assertNotNull(parsed)
        assertEquals(250.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals(8900.50, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses Dashen Bank transfer with total balance`() {
        val msg = "Dear customer, you have transferred ETB 300.00 on 05/02/2024. Current balance is ETB 4,321.00."
        val parsed = SmsBroadcastReceiver.parseBankingSms("Dashen Bank", msg)

        assertNotNull(parsed)
        assertEquals(300.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals(4321.00, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses Dashen Bank Super App transfer to telebirr`() {
        val msg = """Dear Getasew, you have successfully transferred ETB 50.00 from your account  5822**011 to Getasew Adane Ambaw tele birr account +251945557122 on 2026-08-14 at 08:52:25 with transaction reference 822LTWS2622600WJ.  The service charge is 
ETB 5, VAT (15%) ETB 0.75 and DRRF (5%) ETB 0.25. Your current balance is ETB 6,999.44.

Download receipt:  = https://receipts.dashenbanksc.com/receipt/822LTWS2622600WJ.
Share us your feedback:  https://forms.gle/mbzfguGEdytV5GKj6
Contact us on: 6333
Thank you for using Dashen Super app"""
        val parsed = SmsBroadcastReceiver.parseBankingSms("Dashen Bank", msg)

        assertNotNull(parsed)
        assertEquals(50.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals("822LTWS2622600WJ", parsed.txReference)
        assertEquals("Getasew Adane Ambaw", parsed.counterparty)
        assertEquals(6999.44, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses Dashen Bank account to account transfer`() {
        val msg = """Dear GETASEW ADANE AMBAW, you have successfully transferred ETB 50,000.00 from your account number 5822**011 to BIRUK WORKU NEMTA's account number  5822**011 on 2026-08-12 at 02:07:46 with transaction reference: 822WDTS262240002. The service 
charge is ETB 0.00, VAT (15%) ETB 0.00 and DRRF (5%) 
ETB 0.00. Your current balance is ETB 6,055.44.

Download receipt: = https://receipts.dashenbanksc.com/receipt/822WDTS262240002.
Share us your feedback: https://forms.gle/mbzfguGEdytV5GKj6 Contact us on: 6333.
Thank you for using Dashen Super app"""
        val parsed = SmsBroadcastReceiver.parseBankingSms("Dashen Bank", msg)

        assertNotNull(parsed)
        assertEquals(50000.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals("822WDTS262240002", parsed.txReference)
        assertEquals("BIRUK WORKU NEMTA", parsed.counterparty)
        assertEquals(6055.44, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses standard Dashen debit alert`() {
        val msg = """Dear Customer, your account '5822**011' is debited with ETB 50,000.00 on 12/08/2026 at 02:07:46 PM. Your current balance is ETB 6,055.44.
Dashen Bank - Always one step ahead!"""
        val parsed = SmsBroadcastReceiver.parseBankingSms("Dashen Bank", msg)

        assertNotNull(parsed)
        assertEquals(50000.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals(6055.44, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses CBE Birr with total balance`() {
        val msg = "You have transferred 200.00 Br. to 0911223344 on 01/01/2024. Txn ID is TXN8877. Your current balance is 1,500.25 Br."
        val parsed = SmsBroadcastReceiver.parseBankingSms("CBE Birr", msg)

        assertNotNull(parsed)
        assertEquals(200.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals(1500.25, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses CBE Birr outgoing sent transfer as expense with recipient`() {
        val msg = "Dear NAHOM, you have sent 28.00Br. to NATNAEL ABEBE on 31/08/26 20:45,Txn ID DHV51MWWIJ1. Your CBE Birr account balance is 63.30Br.Thank you! For invoice https://cbepay1.cbe.com.et/aureceipt?TID=DHV51MWWIJ1&PH=251921607264 For your feedback please click the link https://shorturl.at/gy3A0"
        val parsed = SmsBroadcastReceiver.parseBankingSms("CBE Birr", msg)

        assertNotNull(parsed)
        assertEquals(28.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals("NATNAEL ABEBE", parsed.counterparty)
        assertEquals("DHV51MWWIJ1", parsed.txReference)
        assertEquals(63.30, parsed.totalBalance, 0.001)
    }

    @Test
    fun `drops non-transaction SMS fragments without showing notification`() {
        val msg = "To download your payment information please click this link: https://transactioninfo.ethiotelecom.et/receipt/DHJ9WSTUPZ\nFor any support and information related to telebirr service"
        val parsed = SmsBroadcastReceiver.parseBankingSms("Telebirr", msg)

        assertNull("Non-transaction fragment must return null", parsed)
    }

    @Test
    fun `Nib Bank parsing returns null while disabled pending authentic samples`() {
        val msg = "Dear Customer, your A/C 440xxxx1122 has been credited with ETB 6,000.00 by BIRUK ASSEFA on 10/08/2026. Available Balance: ETB 18,500.00. Ref: NIB112233."
        val parsed = SmsBroadcastReceiver.parseBankingSms("Nib Bank", msg)
        assertNull("Nib Bank parsing must return null to route to notifications table", parsed)
    }

    @Test
    fun `parses Bunna Bank deposit via IPS`() {
        val msg = "Dear Customer\nA Deposit of 40,000.00 ETB has been made to your account 426*******611 BY IPS /INCOMMING/ABYSETAA/ABYSETAAFT26155FLQKV on 04-06-2026 15:27:53, your current balance is 40,000.00 ETB. Thank you.\nBunna Bank"
        val parsed = SmsBroadcastReceiver.parseBankingSms("Bunna Bank", msg)

        assertNotNull(parsed)
        assertEquals(40000.0, parsed!!.amount, 0.001)
        assertFalse(parsed.isDebit)
        assertEquals("IPS (ABYSETAA)", parsed.counterparty)
        assertEquals("ABYSETAAFT26155FLQKV", parsed.txReference)
        assertEquals(40000.0, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses Bunna Bank withdrawal to company`() {
        val msg = "Dear Customer\nA Withdrawal of 40,000.00 ETB has been made from your account 426*******611 on 04-06-2026 15:39:51 by TO DMK TECHNOLOGY PLC '' UNDER FORMATION'', your current balance is 100.00 ETB. Thank you.\nBunna Bank"
        val parsed = SmsBroadcastReceiver.parseBankingSms("Bunna Bank", msg)

        assertNotNull(parsed)
        assertEquals(40000.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals("DMK TECHNOLOGY PLC '' UNDER FORMATION''", parsed.counterparty)
        assertEquals(100.0, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses Bunna Bank Telebirr transfer`() {
        val msg = "Dear Customer\nA Withdrawal of 56.00 ETB has been made from your account 426*******611 on 08-07-2026 23:20:14 by TELEBIRR TRANSFER, your current balance is 44.00 ETB. Thank you.\nBunna Bank"
        val parsed = SmsBroadcastReceiver.parseBankingSms("Bunna Bank", msg)

        assertNotNull(parsed)
        assertEquals(56.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals("Telebirr Transfer", parsed.counterparty)
        assertEquals(44.0, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses Bunna Bank digital advice withdrawal`() {
        val msg = "Dear Customer\nA Withdrawal of 2,012.00 ETB has been made from your account 426*******611 on 08-08-2026 16:01:11 by IPS OUT GOING, your current balance is 38,032.00 ETB. \nPlease Download Your Digital Advice Here: \nhttps://online.bunnabanksc.com/receipt/#/lW1L+BNvCOFS8CfWjw1yyBy/f1C4pprSuQijjdsezfw=\nPlease Rate Your Satisfaction Level Here: \nhttps://online.bunnabanksc.com/receipt/#/feedback/lW1L+BNvCOFS8CfWjw1yyBy/f1C4pprSuQijjdsezfw=\nThank you.\nBunna Bank"
        val parsed = SmsBroadcastReceiver.parseBankingSms("Bunna Bank", msg)

        assertNotNull(parsed)
        assertEquals(2012.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals("IPS Outgoing", parsed.counterparty)
        assertEquals(38032.0, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses Bunna Bank 1 ETB Telebirr deposit`() {
        val msg = "Dear Customer\nA Deposit of 1.00 ETB has been made to your account 426***611 BY TELEBIRR RECEIVABLE ACCOUNT TELEINCOME on 06-09-2026 15:55:28, your current balance is 219.47 ETB. Thank you.\nBunna Bank"
        val parsed = SmsBroadcastReceiver.parseBankingSms("Bunna Bank", msg)

        assertNotNull(parsed)
        assertEquals(1.0, parsed!!.amount, 0.001)
        assertFalse(parsed.isDebit)
        assertEquals("TELEBIRR RECEIVABLE ACCOUNT TELEINCOME", parsed.counterparty)
        assertEquals(219.47, parsed.totalBalance, 0.001)
    }

    // ── Awash Bank Tests ──────────────────────────────────────────────────

    @Test
    fun `parses Awash Bank outbound CBE transfer with ref and balance`() {
        val msg = "Ref: 819285215216: Dear AMANUEL  ADEME , you have transfered 4000.00 to DAGMAWI GETACHEW DIGAFE in CBE .New balance is 985.92 as at 2023-08-12: 21:52.Transaction cost, 20.00.Thank You! Awash Bank"
        val parsed = SmsBroadcastReceiver.parseBankingSms("Awash Bank", msg)

        assertNotNull(parsed)
        assertEquals(4000.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals("DAGMAWI GETACHEW DIGAFE", parsed.counterparty)
        assertEquals("819285215216", parsed.txReference)
        assertEquals(985.92, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses Awash Bank mobile money transfer to telebirr`() {
        val msg = "Ref: 811859163727:  Dear AMANUEL  ADEME , your mobile money transfer of 2800.00 to telebirr account 251928983855  is being processed. For any complaint or enquiry, please call 8980. Thank you! Awash Bank."
        val parsed = SmsBroadcastReceiver.parseBankingSms("Awash Bank", msg)

        assertNotNull(parsed)
        assertEquals(2800.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals("Telebirr (251928983855)", parsed.counterparty)
        assertEquals("811859163727", parsed.txReference)
    }

    @Test
    fun `parses Awash Bank third-party transfer to user account`() {
        val msg = "Dear AMANUEL ADEMU DESALEW, AMANUEL  ADEME  has transferred 1400.00 birr to your ABYSSINIA account from Awash Bank. Thank you."
        val parsed = SmsBroadcastReceiver.parseBankingSms("Awash Bank", msg)

        assertNotNull(parsed)
        assertEquals(1400.0, parsed!!.amount, 0.001)
        assertFalse(parsed.isDebit)
        assertEquals("AMANUEL  ADEME", parsed.counterparty)
    }

    @Test
    fun `parses Awash Bank inbound credit with ref`() {
        val msg = "Ref: 85376317729 : Dear AMANUEL ADEME DESALEO, your account has been credited with 3000.00 from DAWIT TESFAYE. New balance is 3085.92 as at 2023-08-21: 17:07. Thank you! Awash Bank."
        val parsed = SmsBroadcastReceiver.parseBankingSms("Awash Bank", msg)

        assertNotNull(parsed)
        assertEquals(3000.0, parsed!!.amount, 0.001)
        assertFalse(parsed.isDebit)
        assertEquals("DAWIT TESFAYE", parsed.counterparty)
        assertEquals("85376317729", parsed.txReference)
        assertEquals(3085.92, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses Awash Bank inbound transfer processing`() {
        val msg = "Dear AMANUEL ADEME DESALEW, a transfer of 200.00 birr from EYOSIAS MEKBIB to your DASHEN account is being processed. Thank you. Awash Bank"
        val parsed = SmsBroadcastReceiver.parseBankingSms("Awash Bank", msg)

        assertNotNull(parsed)
        assertEquals(200.0, parsed!!.amount, 0.001)
        assertFalse(parsed.isDebit)
        assertEquals("EYOSIAS MEKBIB", parsed.counterparty)
    }

    @Test
    fun `parses Awash Bank school fee payment`() {
        val msg = "Ref: 6Z8JHZF4YUGE : Dear AMANUEL  ADEME , school fee payment  of 12088.00 to BITS EDUCATION AND CONSLTING PLC for AMANUEL ADEME DESALEO has been paid successfully. Transaction Cost ETB 0.00. Thank You! Awash Bank"
        val parsed = SmsBroadcastReceiver.parseBankingSms("Awash Bank", msg)

        assertNotNull(parsed)
        assertEquals(12088.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals("BITS EDUCATION AND CONSLTING PLC", parsed.counterparty)
        assertEquals("6Z8JHZF4YUGE", parsed.txReference)
        assertEquals("School Fee", parsed.lockedReasonName)
        assertFalse(parsed.isLocked)
    }

    @Test
    fun `parses Awash Bank inbound telebirr received`() {
        val msg = "Dear Customer, You have received 550.00 from Telebirr, service number 251928983855, on your account 01320xxxxx1300 by Ref: KNMLDN4YT74W, and your new balance is 609.34 as at 2022-12-27: 17:23. For any complaints or enquiries, please call 8980. Thank you! Awash Bank"
        val parsed = SmsBroadcastReceiver.parseBankingSms("Awash Bank", msg)

        assertNotNull(parsed)
        assertEquals(550.0, parsed!!.amount, 0.001)
        assertFalse(parsed.isDebit)
        assertEquals("Telebirr (251928983855)", parsed.counterparty)
        assertEquals("KNMLDN4YT74W", parsed.txReference)
        assertEquals(609.34, parsed.totalBalance, 0.001)
    }

    @Test
    fun `parses Awash Bank account debited with negative amount`() {
        val msg = "Dear Customer, your Account 01425xxxxxx3201 has been Debited with ETB -30500.00 on 2026-07-09 12:44:06. Your balance now is ETB 510269.25. For any complaint or enquiry, please call 8980. Thank You. Awash Bank."
        val parsed = SmsBroadcastReceiver.parseBankingSms("Awash Bank", msg)

        assertNotNull(parsed)
        assertEquals(30500.0, parsed!!.amount, 0.001)
        assertTrue(parsed.isDebit)
        assertEquals(510269.25, parsed.totalBalance, 0.001)
    }
}
