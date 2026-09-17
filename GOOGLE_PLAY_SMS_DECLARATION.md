# Google Play Store SMS Permissions Declaration Guide

This document contains the required answers, justification text, and compliance checklist for submitting **Shibre** to the Google Play Store under the **Personal Financial Management (PFM)** SMS exemption.

---

### 1. Declared Core Permissions
- `android.permission.READ_SMS`
- `android.permission.RECEIVE_SMS`

---

### 2. Permissions Declaration Form Responses (Google Play Console)

#### A. Core Feature Category Selection
- **Select Option**: `Financial-based account management / tracking` (Personal Financial Management - PFM).

#### B. Core Functionality Description
```text
Shibre is a personal financial management (PFM) application designed for the Ethiopian banking and mobile money ecosystem. Its core feature is to automatically detect, parse, and categorize inbound banking transaction SMS messages (from institutions such as CBE, Telebirr, Awash Bank, Dashen Bank, and Bank of Abyssinia) to compute real-time account balances, categorize expenses, and provide spending analytics.

Without READ_SMS and RECEIVE_SMS, the application cannot provide its core value proposition, as Ethiopian banks do not provide consumer open-banking APIs or webhooks. All financial data is aggregated directly from official bank SMS notifications.
```

#### C. Privacy & Data Handling Statement
```text
1. 100% On-Device Processing: All SMS parsing, regex extraction, and financial transaction generation take place strictly on the user's physical device.
2. Zero SMS Upload: Raw SMS messages, sender phone numbers, and message contents are NEVER uploaded, transmitted, or synchronized with any remote server or third party.
3. Over-the-Air Rule Delivery: The application only downloads declarative regex rules and bank branding metadata from the backend. No user data flows outward.
4. Security Filtering: All sensitive messages (such as OTPs, 2FA codes, login verification codes, and password reset notifications) are strictly ignored and immediately dropped.
```

#### D. Demonstration Video Requirements
Google Play requires a public/unlisted YouTube video link demonstrating the feature.
- **Video Checklist**:
  1. Show app launch and the prominent in-app disclosure modal explaining why SMS permission is requested.
  2. Grant the SMS permission.
  3. Send or receive a test bank transaction SMS (or perform an historical inbox scan).
  4. Show the transaction automatically appearing in the dashboard/wallets list with updated balances and categorized spending.
  5. Show that OTPs/personal messages are ignored.

---

### 3. Required Privacy Policy Clauses
Ensure your hosted Privacy Policy URL contains the following excerpt:

> **SMS Financial Notifications**:
> Shibre requests `READ_SMS` and `RECEIVE_SMS` permissions solely to detect and track financial transactions from recognized banking and mobile money services. All SMS extraction and parsing occur exclusively within the local application sandbox on your device. Shibre does not collect, transmit, store, or share your personal SMS messages, contacts, or financial credentials with any external server.
