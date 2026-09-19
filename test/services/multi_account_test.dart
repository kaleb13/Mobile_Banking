import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_banking_app/models/stored_account.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Account & StoredAccount Model Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('StoredAccount correctly serializes to and deserializes from JSON', () {
      final account = StoredAccount(
        userId: 'usr_001_abc',
        email: 'kaleb.worku@example.com',
        displayName: 'Kaleb Worku',
        avatarUrl: 'https://example.com/avatar.jpg',
        refreshToken: 'refresh_token_xyz_123',
        lastActiveAt: DateTime.utc(2026, 9, 18, 10, 0, 0),
        isActive: true,
      );

      final jsonStr = account.toJson();
      final decoded = StoredAccount.fromJson(jsonStr);

      expect(decoded.userId, 'usr_001_abc');
      expect(decoded.email, 'kaleb.worku@example.com');
      expect(decoded.displayName, 'Kaleb Worku');
      expect(decoded.avatarUrl, 'https://example.com/avatar.jpg');
      expect(decoded.refreshToken, 'refresh_token_xyz_123');
      expect(decoded.lastActiveAt, DateTime.utc(2026, 9, 18, 10, 0, 0));
      expect(decoded.isActive, isTrue);
    });

    test('StoredAccount copyWith preserves existing values unless overridden', () {
      final original = StoredAccount(
        userId: 'usr_002',
        email: 'business@shibre.app',
        displayName: 'Shibre Business',
        lastActiveAt: DateTime.utc(2026, 9, 18, 11, 0, 0),
        isActive: false,
      );

      final updated = original.copyWith(
        isActive: true,
        displayName: 'Shibre Enterprises',
        refreshToken: 'token_new_456',
      );

      expect(updated.userId, 'usr_002');
      expect(updated.email, 'business@shibre.app');
      expect(updated.displayName, 'Shibre Enterprises');
      expect(updated.isActive, isTrue);
      expect(updated.refreshToken, 'token_new_456');
    });

    test('StoredAccount handles pro and free plans correctly', () {
      final freeAccount = StoredAccount(
        userId: 'usr_free',
        email: 'free@shibre.app',
        displayName: 'Free User',
        plan: 'free',
        lastActiveAt: DateTime.utc(2026, 9, 18),
      );
      expect(freeAccount.isPro, isFalse);

      final proAccount = StoredAccount(
        userId: 'usr_pro',
        email: 'pro@shibre.app',
        displayName: 'Pro User',
        plan: 'pro',
        lastActiveAt: DateTime.utc(2026, 9, 18),
      );
      expect(proAccount.isPro, isTrue);

      final expiredPro = StoredAccount(
        userId: 'usr_expired',
        email: 'expired@shibre.app',
        displayName: 'Expired Pro User',
        plan: 'pro',
        proUntil: DateTime.now().subtract(const Duration(days: 1)),
        lastActiveAt: DateTime.utc(2026, 9, 18),
      );
      expect(expiredPro.isPro, isFalse);

      final premiumAccount = StoredAccount(
        userId: 'usr_premium',
        email: 'prem@shibre.app',
        displayName: 'Premium User',
        plan: 'premium',
        proUntil: DateTime.now().add(const Duration(days: 30)),
        lastActiveAt: DateTime.utc(2026, 9, 18),
      );
      expect(premiumAccount.isPro, isTrue);

      // Verify serialization roundtrip with plan & proUntil
      final jsonStr = premiumAccount.toJson();
      final restored = StoredAccount.fromJson(jsonStr);
      expect(restored.plan, 'premium');
      expect(restored.proUntil, isNotNull);
      expect(restored.isPro, isTrue);
    });

    test('Multi-Account list persists and retrieves correctly from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();

      final accounts = [
        StoredAccount(
          userId: 'usr_personal',
          email: 'kaleb.personal@gmail.com',
          displayName: 'Kaleb Personal',
          lastActiveAt: DateTime.now().toUtc(),
          isActive: true,
        ),
        StoredAccount(
          userId: 'usr_business',
          email: 'kaleb.business@gmail.com',
          displayName: 'Kaleb Business',
          lastActiveAt: DateTime.now().toUtc(),
          isActive: false,
        ),
      ];

      final encoded = jsonEncode(accounts.map((a) => a.toMap()).toList());
      await prefs.setString('shibre_multi_accounts_json', encoded);
      await prefs.setString('shibre_active_account_id', 'usr_personal');

      final loadedJson = prefs.getString('shibre_multi_accounts_json');
      final loadedActiveId = prefs.getString('shibre_active_account_id');

      expect(loadedActiveId, 'usr_personal');
      expect(loadedJson, isNotNull);

      final decodedList = (jsonDecode(loadedJson!) as List)
          .map((m) => StoredAccount.fromMap(m as Map<String, dynamic>))
          .toList();

      expect(decodedList.length, 2);
      expect(decodedList[0].userId, 'usr_personal');
      expect(decodedList[0].displayName, 'Kaleb Personal');
      expect(decodedList[1].userId, 'usr_business');
      expect(decodedList[1].displayName, 'Kaleb Business');
    });

    test('Database naming logic properly isolates user databases', () {
      String getDbName(String? userId) {
        final sanitized = userId?.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        return (sanitized == null || sanitized.isEmpty)
            ? 'finance_v3.db'
            : 'finance_$sanitized.db';
      }

      expect(getDbName(null), 'finance_v3.db');
      expect(getDbName(''), 'finance_v3.db');
      expect(getDbName('usr-123-abc'), 'finance_usr_123_abc.db');
      expect(getDbName('usr_business_456'), 'finance_usr_business_456.db');
    });
  });
}
