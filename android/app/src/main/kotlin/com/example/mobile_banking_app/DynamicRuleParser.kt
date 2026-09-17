package com.example.mobile_banking_app

import java.text.NumberFormat
import java.util.Locale

object DynamicRuleParser {

    private fun formatEtb(amount: Double): String {
        val formatter = NumberFormat.getNumberInstance(Locale.US).apply {
            minimumFractionDigits = 2
            maximumFractionDigits = 2
        }
        return "ETB ${formatter.format(amount)}"
    }

    fun parse(bank: NativeBankDefinition, body: String): SmsBroadcastReceiver.NativeParsedSms? {
        if (body.isBlank()) return null
        val singleLine = body.replace("\n", " ").replace("\r", " ")
        val lowerMsg = singleLine.lowercase()

        // 1. Security filter
        if (!bank.securityFilterRegex.isNullOrBlank()) {
            try {
                if (Regex(bank.securityFilterRegex).containsMatchIn(singleLine)) {
                    return null
                }
            } catch (_: Exception) {}
        }

        // 2. Ignore filter
        if (!bank.ignoreFilterRegex.isNullOrBlank()) {
            try {
                if (Regex(bank.ignoreFilterRegex).containsMatchIn(singleLine)) {
                    return null
                }
            } catch (_: Exception) {}
        }

        // 3. Patterns evaluation
        for (pattern in bank.patterns) {
            if (pattern.triggerKeywords.isNotEmpty()) {
                val allMatch = pattern.triggerKeywords.all { lowerMsg.contains(it) }
                if (!allMatch) continue
            }

            if (pattern.regex.isBlank()) continue

            try {
                val regExp = Regex(pattern.regex)
                val match = regExp.find(singleLine) ?: continue

                // Extract Amount
                var amount = 0.0
                if (pattern.amountGroup > 0 && pattern.amountGroup < match.groupValues.size) {
                    val rawAmt = match.groupValues[pattern.amountGroup].replace(",", "").trim()
                    val cleanAmt = if (rawAmt.endsWith(".")) rawAmt.substring(0, rawAmt.length - 1) else rawAmt
                    amount = cleanAmt.toDoubleOrNull() ?: 0.0
                }
                if (amount <= 0.0) continue

                // Extract Counterparty
                var counterparty = pattern.counterpartyDefault ?: ""
                if (pattern.counterpartyGroup > 0 && pattern.counterpartyGroup < match.groupValues.size) {
                    val cp = match.groupValues[pattern.counterpartyGroup].trim()
                    if (cp.isNotEmpty()) {
                        counterparty = cp
                    }
                }
                if (counterparty.isEmpty()) {
                    counterparty = bank.bankName
                }

                // Extract Balance
                var balance = 0.0
                if (pattern.balanceGroup != null && pattern.balanceGroup > 0 && pattern.balanceGroup < match.groupValues.size) {
                    val rawBal = match.groupValues[pattern.balanceGroup].replace(",", "").trim()
                    val cleanBal = if (rawBal.endsWith(".")) rawBal.substring(0, rawBal.length - 1) else rawBal
                    balance = cleanBal.toDoubleOrNull() ?: 0.0
                }

                // Extract Reference ID
                var txRef: String? = null
                if (pattern.idGroup != null && pattern.idGroup > 0 && pattern.idGroup < match.groupValues.size) {
                    val rawId = match.groupValues[pattern.idGroup].trim()
                    if (rawId.isNotEmpty()) {
                        txRef = rawId
                    }
                }

                val isDebit = pattern.type.equals("expense", ignoreCase = true)
                val isLocked = pattern.patternType.equals("telebirrSanduq", ignoreCase = true) ||
                               pattern.patternType.equals("internalTransfer", ignoreCase = true)
                val lockedReason = if (pattern.patternType.equals("telebirrAirtime", ignoreCase = true)) {
                    "Airtime"
                } else if (pattern.patternType.equals("telebirrPackage", ignoreCase = true)) {
                    "Package"
                } else if (pattern.patternType.equals("telebirrSanduq", ignoreCase = true)) {
                    "Sanduq"
                } else null

                return SmsBroadcastReceiver.NativeParsedSms(
                    bankName = bank.bankName,
                    amount = amount,
                    formattedAmount = formatEtb(amount),
                    isDebit = isDebit,
                    counterparty = counterparty,
                    directionHeader = if (isDebit) "To: $counterparty" else "From: $counterparty",
                    title = if (isDebit) "Expense" else "Income",
                    isLocked = isLocked,
                    lockedReasonName = lockedReason,
                    txReference = txRef,
                    totalBalance = balance
                )
            } catch (_: Exception) {
                continue
            }
        }

        return null
    }
}
