# Hierarchical Categorization, Special Reasons, Media Attachments & Interactive Circular Chart Architecture

## Overview
This refined implementation plan incorporates all explicit user design choices across the **Categorization Architecture**, **Special Reasons Framework**, **Transaction Notes & Media Attachment Framework**, and **Interactive Donut Chart Drilldown**.

---

## Architecture & Feature Breakdown

### 1. Categorization Schema & Naming Standards

```
Financial Reasons Architecture
├── Special Reasons (Standalone core system reasons with special logic & restored descriptions, NO subcategories)
│   ├── Loan: "Track loans, credit lines & debt repayments"
│   ├── Internal Transfer: "Transfer money between your accounts"
│   ├── Cash: "Cash wallet & manual cash expenses"
│   └── Bounce: "Bounced, reversed & failed transactions"
│
└── Top-Level Categories (Parent Categories hosting Subcategories)
    ├── Food 🍔 (Subcategories: Restaurants, Fast Food, Groceries, Bakery, Snacks)
    ├── Drink ☕ (Subcategories: Coffee, Boba, Bar & Alcohol, Soft Drinks, Juices)
    ├── Transportation 🚗 (Subcategories: Fuel & Gas, Taxi & Rideshare, Public Transit, Parking & Tolls, Vehicle Maintenance)
    ├── Housing 🏠 (Subcategories: Rent, Mortgage, Property Tax, Home Repairs, Furniture)
    ├── Utilities 💡 (Subcategories: Electricity, Water, Internet & Wifi, Gas, Garbage & Sewer)
    ├── Goods 🛍️ (Subcategories: Clothing & Apparel, Electronics, Household Supplies, Supermarket Goods, Gifts)
    ├── Entertainment 🎬 (Subcategories: Movies, Gaming, Streaming & Subscriptions, Events & Concerts, Hobbies)
    ├── Health & Personal Care 🩺 (Subcategories: Pharmacy & Medicine, Doctor & Hospital, Salon & Spa, Fitness & Gym)
    └── Education 📚 (Subcategories: Tuition, Books & Stationary, Online Courses)
```

- **Special Reasons**: Exactly the 4 core system reasons (*Bounce*, *Cash*, *Internal Transfer*, *Loan*). They retain their original descriptions and special app behavior. They do **not** have subcategories.
- **Top-Level Categories**: Clean, non-compound categories. Users have full freedom to add custom top-level categories and custom subcategories.

---

### 2. Transaction Notes & Media Attachment Framework
- **Attach Media Action Button**: Positioned on the right side of the `PERSONAL NOTE` section on `TransactionDetailScreen`.
- **Media Attachments Gallery**: Renders receipts (images), PDF invoices, or audio clips associated with a transaction.

---

### 3. Reason Selection Sheet Redesign (`ReasonSelectionSheet`)
- **No Header `X` Close Button**: Dismissed via swipe down / Android back.
- **Top Right Search Icon Button**: Tap expands a fully-rounded search bar (`BorderRadius.circular(30)`) smoothly across the top row. Tap close collapses search mode.
- **Restored Special Reason Descriptions**: Restored original descriptions for Loan, Cash, Internal Transfer, and Bounce.
- **Ultra-Compact Card Layout**: Tiles are compact with smaller icons (14px) and minimal padding so many items fit on screen.
- **Accordion Indicators**: Clean expand arrows (`chevron_right` / `keyboard_arrow_down`) and radio/check indicators.

---

### 4. Interactive Donut Chart & "Go Deeper" Drilldown (`AnalysisScreen`)
- **Special Reasons Behavior**: Special reasons (*Bounce*, *Cash*, *Internal Transfer*, *Loan*) **never show the "Go Deeper" button**, as they do not have subcategories.
- **Top-Level Categories Behavior**:
  - If a category **has subcategories**, the **"Go Deeper"** button is active (positive green).
  - If a category **has NO subcategories**, the **"Go Deeper"** button is rendered in a **disabled / grayed-out** state. Clicking it shows a tooltip: *"No subcategories found for this category"*.
- **Interactive Below List**:
  - The category/subcategory breakdown list below the donut ring is fully interactive.
  - In Level 2, the list updates to display subcategories of that category.
  - Tapping any row in the list highlights that category/subcategory, scales its arc on the donut chart, and updates the center metrics!
