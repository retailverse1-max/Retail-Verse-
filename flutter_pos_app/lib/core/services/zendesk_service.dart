import 'package:flutter/foundation.dart';
import 'package:zendesk_messaging/zendesk_messaging.dart';

class ZendeskService {
  // Replace this with your actual Channel Key from Zendesk Admin Center
  static const String channelKey = "YOUR_ZENDESK_CHANNEL_KEY"; 

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    try {
      if (channelKey == "YOUR_ZENDESK_CHANNEL_KEY") {
        debugPrint("Zendesk: Channel Key is missing. Please add it to enable Chat.");
        return;
      }
      await ZendeskMessaging.initialize(
        androidChannelKey: channelKey,
        iosChannelKey: channelKey,
      );
      _isInitialized = true;
      debugPrint("Zendesk: Initialized successfully.");
    } catch (e) {
      debugPrint("Zendesk: Initialization failed: $e");
    }
  }

  static Future<void> showChat() async {
    if (!_isInitialized) {
      debugPrint("Zendesk: Cannot show chat. SDK not initialized.");
      return;
    }
    try {
      await ZendeskMessaging.show();
    } catch (e) {
      debugPrint("Zendesk: Could not show chat: $e");
    }
  }

  static Future<void> setVisitorInfo({String? name, String? email}) async {
    try {
      // Zendesk messaging uses user IDs or tags
      // This varies by SDK version, basic info can be set if needed
    } catch (e) {
      debugPrint("Zendesk: Failed to set visitor info: $e");
    }
  }
}
