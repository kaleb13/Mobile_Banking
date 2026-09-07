import '../models/parsed_sms_result.dart';

/// Nib Bank Parser
/// 
/// Currently disabled pending authentic user SMS samples.
/// Returning null ensures any incoming or scanned SMS is routed directly to
/// unrecognized notifications, allowing users to send raw messages to the developer.
class NibParser {
  static const String senderName = "Nib Bank";

  /// Returns null while waiting for authentic transaction SMS patterns.
  static ParsedSmsResult? parse(String message, DateTime fallbackDate) {
    return null;
  }

  /// Owner name extraction disabled pending real SMS samples.
  static String? extractOwnerName(String message) => null;
}
