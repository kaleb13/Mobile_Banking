# Google Play Store Compliance & Submission Guide

This document contains the complete answers, justification texts, Data Safety declarations, and verification checklist for publishing **Shibre** to the Google Play Store under the **Personal Financial Management (PFM)** SMS exemption.

---

### 1. Declared Core Permissions
- `android.permission.READ_SMS` (Read inbound banking SMS)
- `android.permission.RECEIVE_SMS` (Real-time background transaction detection)
- `android.permission.POST_NOTIFICATIONS` (Transaction alerts & spending reports)
- `android.permission.USE_BIOMETRIC` (App lock authentication)

> [!NOTE]
> **Exact Alarm Policy (`SCHEDULE_EXACT_ALARM`)**:
> `SCHEDULE_EXACT_ALARM` has been removed from the manifest. Daily, weekly, and monthly spending digests now use power-efficient `setAndAllowWhileIdle` alarms. You do NOT need to request the high-risk Exact Alarm permission exemption in the Play Console.

---

### 2. Permissions Declaration Form Responses (Google Play Console)

#### A. Core Feature Category Selection
- **Select Option**: `Financial-based account management / tracking` (Personal Financial Management - PFM).

#### B. Core Functionality Description
```text
Shibre is a personal financial management (PFM) application designed specifically for the Ethiopian banking and mobile money ecosystem. Its core feature is to automatically detect, parse, and categorize inbound banking transaction SMS messages (from institutions such as CBE, Telebirr, Awash Bank, Dashen Bank, and Bank of Abyssinia) to compute real-time account balances, categorize expenses, and provide spending analytics.

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
  1. Show app launch and Page 3/4 of Onboarding (Terms & Privacy and the prominent SMS access card).
  2. Grant the SMS permission on the system dialog.
  3. Send or receive a test bank transaction SMS (or perform an historical inbox scan).
  4. Show the transaction automatically appearing in the dashboard/wallets list with updated balances and categorized spending.
  5. Show that OTPs and non-banking personal messages are ignored.

---

### 3. Play Console Data Safety Form

When completing the **Data Safety** section in Google Play Console:

| Section | Answer | Rationale |
| :--- | :--- | :--- |
| **Does your app collect or share any user data?** | **No** (if running 100% offline without cloud sync) | All SMS parsing and transaction records are stored locally in the private SQLite database. |
| **Is all user data encrypted in transit?** | **Yes** (or N/A) | Any network requests (OTA bank rule updates) are strictly HTTPS. |
| **Do you provide a way for users to request data deletion?** | **Yes** | Users can delete individual records, purge unhandled logs, or perform a full factory reset directly in Settings. |

---

### 4. Required Hosted Privacy Policy Clauses
Ensure your hosted Privacy Policy URL (e.g., `https://shibre.com/privacy`) contains the following excerpt:

> **SMS Financial Notifications**:
> Shibre requests `READ_SMS` and `RECEIVE_SMS` permissions solely to detect and track financial transactions from recognized banking and mobile money services. All SMS extraction and parsing occur exclusively within the local application sandbox on your device. Shibre does not collect, transmit, store, or share your personal SMS messages, contacts, or financial credentials with any external server.

---

### 5. Final Release Checklist Before Clicking "Send for Review"
- [ ] Ensure `https://shibre.com/privacy` is reachable via HTTPS.
- [ ] Verify `android/key.properties` points to your valid release keystore (`upload-keystore.jks`).
- [ ] Build release bundle using `flutter build appbundle --release`.
- [ ] Upload AAB to the **Closed Testing** or **Production** track.
- [ ] Upload the unlisted YouTube demonstration video URL in the Permissions Declaration form.
- [ ] Submit for review.
