/// Defines the user-selectable historical scan window options for banking SMS ingestion.
enum ScanWindowOption {
  todayOnly,
  sevenDays,
  thirtyDays,
  ninetyDays,
  allTime;

  /// Number of lookback days relative to installation.
  /// 0 means today onward, -1 means all available history.
  int get days {
    switch (this) {
      case ScanWindowOption.todayOnly:
        return 0;
      case ScanWindowOption.sevenDays:
        return 7;
      case ScanWindowOption.thirtyDays:
        return 30;
      case ScanWindowOption.ninetyDays:
        return 90;
      case ScanWindowOption.allTime:
        return -1;
    }
  }

  /// Calculates the cutoff anchor date based on lookback days.
  DateTime get anchorDate {
    final now = DateTime.now();
    if (days == -1) return DateTime(2000, 1, 1);
    if (days == 0) return DateTime(now.year, now.month, now.day);
    return now.subtract(Duration(days: days));
  }

  /// Human-readable title
  String get title {
    switch (this) {
      case ScanWindowOption.todayOnly:
        return 'From Today Onward';
      case ScanWindowOption.sevenDays:
        return 'Last 7 Days (1 Week)';
      case ScanWindowOption.thirtyDays:
        return 'Last 30 Days (1 Month)';
      case ScanWindowOption.ninetyDays:
        return 'Last 90 Days (3 Months)';
      case ScanWindowOption.allTime:
        return 'All Available Messages';
    }
  }

  /// Detailed subtitle describing the option
  String get subtitle {
    switch (this) {
      case ScanWindowOption.todayOnly:
        return 'Starts fresh from today with zero past history.';
      case ScanWindowOption.sevenDays:
        return 'Imports the last 7 days of transactions.';
      case ScanWindowOption.thirtyDays:
        return 'Imports past 30 days of transactions.';
      case ScanWindowOption.ninetyDays:
        return 'Imports past 90 days. May take longer.';
      case ScanWindowOption.allTime:
        return 'Imports all device SMS. High processing load.';
    }
  }

  /// Compact badge label
  String get shortLabel {
    switch (this) {
      case ScanWindowOption.todayOnly:
        return 'Today';
      case ScanWindowOption.sevenDays:
        return '7 Days';
      case ScanWindowOption.thirtyDays:
        return '30 Days';
      case ScanWindowOption.ninetyDays:
        return '90 Days';
      case ScanWindowOption.allTime:
        return 'All-Time';
    }
  }

  /// Badge tag for UI selection cards
  String? get badgeLabel {
    switch (this) {
      case ScanWindowOption.todayOnly:
        return 'Lightest';
      case ScanWindowOption.sevenDays:
        return 'Recommended';
      case ScanWindowOption.thirtyDays:
        return null;
      case ScanWindowOption.ninetyDays:
        return 'Heavy Load';
      case ScanWindowOption.allTime:
        return 'Heavy Load';
    }
  }

  /// Whether this option represents a heavy scan on older/busy phones
  bool get isHeavyLoad =>
      this == ScanWindowOption.ninetyDays || this == ScanWindowOption.allTime;

  /// Parse from persisted key (defaults to recommended 7 days)
  static ScanWindowOption fromString(String? key) {
    switch (key) {
      case 'todayOnly':
        return ScanWindowOption.todayOnly;
      case 'sevenDays':
        return ScanWindowOption.sevenDays;
      case 'thirtyDays':
        return ScanWindowOption.thirtyDays;
      case 'ninetyDays':
        return ScanWindowOption.ninetyDays;
      case 'allTime':
        return ScanWindowOption.allTime;
      default:
        return ScanWindowOption.sevenDays;
    }
  }

  String get keyName => name;

  /// Computes the hard anchor cutoff date relative to an [installDate].
  DateTime computeAnchorDate(DateTime installDate) {
    if (this == ScanWindowOption.allTime) {
      return DateTime(2000, 1, 1);
    }
    if (this == ScanWindowOption.todayOnly) {
      // Beginning of install day (midnight)
      return DateTime(installDate.year, installDate.month, installDate.day);
    }
    return installDate.subtract(Duration(days: days));
  }
}
