import 'dart:convert';

/// Represents a locally stored authenticated user account on this device.
class StoredAccount {
  final String userId;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String? refreshToken;
  final DateTime lastActiveAt;
  final bool isActive;
  final String plan; // 'free', 'pro', 'premium'
  final DateTime? proUntil; // null means lifetime (if plan is pro/premium)
  final bool syncDeviceSms; // true = ingests phone SMS, false = cloud-only viewer
  final bool hasConfiguredSmsMode; // true once user has explicitly configured SMS mode on this device

  const StoredAccount({
    required this.userId,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.refreshToken,
    required this.lastActiveAt,
    this.isActive = false,
    this.plan = 'free',
    this.proUntil,
    this.syncDeviceSms = true,
    this.hasConfiguredSmsMode = false,
  });

  /// Whether this account has an active, unexpired Pro or Premium tier.
  bool get isPro {
    final cleanPlan = plan.toLowerCase().trim();
    final hasProTier = cleanPlan == 'pro' || cleanPlan == 'premium' || cleanPlan.contains('pro');
    final notExpired = proUntil == null || proUntil!.isAfter(DateTime.now());
    return hasProTier && notExpired;
  }

  StoredAccount copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? refreshToken,
    DateTime? lastActiveAt,
    bool? isActive,
    String? plan,
    DateTime? proUntil,
    bool? syncDeviceSms,
    bool? hasConfiguredSmsMode,
  }) {
    return StoredAccount(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      refreshToken: refreshToken ?? this.refreshToken,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isActive: isActive ?? this.isActive,
      plan: plan ?? this.plan,
      proUntil: proUntil ?? this.proUntil,
      syncDeviceSms: syncDeviceSms ?? this.syncDeviceSms,
      hasConfiguredSmsMode: hasConfiguredSmsMode ?? this.hasConfiguredSmsMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'refreshToken': refreshToken,
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'isActive': isActive,
      'plan': plan,
      'proUntil': proUntil?.toIso8601String(),
      'syncDeviceSms': syncDeviceSms,
      'hasConfiguredSmsMode': hasConfiguredSmsMode,
    };
  }

  factory StoredAccount.fromMap(Map<String, dynamic> map) {
    return StoredAccount(
      userId: map['userId'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String?,
      refreshToken: map['refreshToken'] as String?,
      lastActiveAt: map['lastActiveAt'] != null
          ? DateTime.tryParse(map['lastActiveAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isActive: map['isActive'] as bool? ?? false,
      plan: (map['plan'] as String?) ?? 'free',
      proUntil: map['proUntil'] != null
          ? DateTime.tryParse(map['proUntil'] as String)
          : null,
      syncDeviceSms: map['syncDeviceSms'] as bool? ?? true,
      hasConfiguredSmsMode: map['hasConfiguredSmsMode'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory StoredAccount.fromJson(String source) =>
      StoredAccount.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoredAccount &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}
