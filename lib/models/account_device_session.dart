import 'package:intl/intl.dart';

/// Represents a physical hardware device session logged into a specific user account.
class AccountDeviceSession {
  final String deviceFingerprint;
  final String userId;
  final String deviceModel;
  final String platform;
  final bool isActive;
  final bool isCurrentDevice;
  final DateTime lastUsedAt;
  final DateTime? createdAt;

  const AccountDeviceSession({
    required this.deviceFingerprint,
    required this.userId,
    required this.deviceModel,
    required this.platform,
    required this.isActive,
    required this.isCurrentDevice,
    required this.lastUsedAt,
    this.createdAt,
  });

  /// Whether this device is currently online or was active in the last 5 minutes.
  bool get isOnline =>
      isCurrentDevice ||
      DateTime.now().toUtc().difference(lastUsedAt).inMinutes < 5;

  /// Whether this session is considered inactive (marked inactive or no activity in 30+ days).
  bool get isInactive =>
      !isCurrentDevice &&
      (!isActive || DateTime.now().toUtc().difference(lastUsedAt).inDays >= 30);

  /// Human-readable relative time string matching Telegram/Google style.
  String get formattedLastSeen {
    if (isCurrentDevice) return 'Active now';
    final now = DateTime.now().toUtc();
    final difference = now.difference(lastUsedAt);

    if (difference.inMinutes < 5) {
      return 'Active just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('HH:mm').format(lastUsedAt.toLocal())}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(lastUsedAt.toLocal());
    }
  }

  AccountDeviceSession copyWith({
    String? deviceFingerprint,
    String? userId,
    String? deviceModel,
    String? platform,
    bool? isActive,
    bool? isCurrentDevice,
    DateTime? lastUsedAt,
    DateTime? createdAt,
  }) {
    return AccountDeviceSession(
      deviceFingerprint: deviceFingerprint ?? this.deviceFingerprint,
      userId: userId ?? this.userId,
      deviceModel: deviceModel ?? this.deviceModel,
      platform: platform ?? this.platform,
      isActive: isActive ?? this.isActive,
      isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_fingerprint': deviceFingerprint,
      'user_id': userId,
      'device_model': deviceModel,
      'platform': platform,
      'is_active': isActive,
      'last_used_at': lastUsedAt.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory AccountDeviceSession.fromMap(
    Map<String, dynamic> map, {
    String? currentFingerprint,
    String? fallbackModel,
  }) {
    final fingerprint = map['device_fingerprint'] as String? ?? '';
    final model = (map['device_model'] as String?)?.isNotEmpty == true
        ? map['device_model'] as String
        : (fallbackModel ?? 'Unknown Device');

    final platformStr = map['platform'] as String? ??
        (model.toLowerCase().contains('iphone') || model.toLowerCase().contains('ipad')
            ? 'iOS'
            : model.toLowerCase().contains('desktop')
                ? 'Desktop'
                : 'Android');

    DateTime parsedLastUsed = DateTime.now().toUtc();
    if (map['last_used_at'] != null) {
      try {
        parsedLastUsed = DateTime.parse(map['last_used_at'] as String);
      } catch (_) {}
    }

    DateTime? parsedCreated;
    if (map['created_at'] != null) {
      try {
        parsedCreated = DateTime.parse(map['created_at'] as String);
      } catch (_) {}
    }

    final isCurrent = currentFingerprint != null &&
        currentFingerprint.isNotEmpty &&
        currentFingerprint == fingerprint;

    return AccountDeviceSession(
      deviceFingerprint: fingerprint,
      userId: map['user_id'] as String? ?? '',
      deviceModel: model,
      platform: platformStr,
      isActive: map['is_active'] as bool? ?? true,
      isCurrentDevice: isCurrent,
      lastUsedAt: parsedLastUsed,
      createdAt: parsedCreated,
    );
  }
}
