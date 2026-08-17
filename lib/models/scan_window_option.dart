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
        return 'Zero history. Starts importing from today without past messages.';
      case ScanWindowOption.sevenDays:
        return 'Imports the past 7 days of banking transactions.';
      case ScanWindowOption.thirtyDays:
        return 'Recommended. Imports the last 30 days for balanced analytics.';
      case ScanWindowOption.ninetyDays:
        return 'Imports the past 3 months for comprehensive history.';
      case ScanWindowOption.allTime:
        return 'Imports all banking SMS found on your device.';
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

  /// Parse from persisted key
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
        return ScanWindowOption.thirtyDays;
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
