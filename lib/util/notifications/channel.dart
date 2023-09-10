import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:humhub/pages/web_view.dart';
import 'package:humhub/util/push_opener_controller.dart';
import 'package:humhub/util/router.dart';
import 'package:loggy/loggy.dart';

/// Used to group notifications by Android channels
///
/// How to use: subclass this abstract class and override onTap method. Then
/// pass instance of this subclass to [NotificationService.scheduleNotification]
/// which will take care of calling [onTap] on correct channel.
abstract class NotificationChannel {
  final String id;
  final String name;
  final String description;

  NotificationChannel(this.id, this.name, this.description);

  static final List<NotificationChannel> _knownChannels = [
    GeneralNotificationChannel(),
  ];

  static bool canAcceptTap(String? channelId) {
    final result = _knownChannels.any((element) => element.id == channelId);
    logDebug("canAcceptTap: $channelId");
    if (!result) {
      logError("Error on channelId: $channelId");
    }
    return result;
  }

  factory NotificationChannel.fromId(String? id) => _knownChannels.firstWhere(
        (channel) => id == channel.id,
      );

  Future<void> onTap(String? payload);

  @protected
  Future<void> navigate(String route, {Object? arguments}) async {
    logDebug('navigate: $route');
    if (navigatorKey.currentState?.mounted ?? false) {
      await navigatorKey.currentState?.pushNamed(
        route,
        arguments: arguments,
      );
    } else {
      queueRoute(
        route,
        arguments: arguments,
      );
    }
  }
}

class GeneralNotificationChannel extends NotificationChannel {
  GeneralNotificationChannel()
      : super(
          'general',
          'General app notifications',
          'These notifications don\'t belong to any other category.',
        );

  @override
  Future<void> onTap(String? payload) async {
    logInfo("onTap Before");
    if (payload != null) {
      logInfo("Here we do navigate to specific screen for channel");
    }
  }
}

class RedirectNotificationChannel extends NotificationChannel {
  static String? _redirectUrlFromInit;

  RedirectNotificationChannel()
      : super(
          'general',
          'General app notifications',
          'These notifications don\'t belong to any other category.',
        );

  /// If the WebView is not opened yet or the app is not running the onTap will wake up the app or redirect to the WebView.
  /// If app is already running in WebView mode then the state of [WebViewApp] will be updated with new url.
  @override
  Future<void> onTap(String? payload) async {
    logDebug('RedirectNotificationChannel onTap: $payload');
    logDebug('payload onTap IF: ${payload != null && navigatorKey.currentState != null}');
    if (payload != null && navigatorKey.currentState != null) {
      bool isNewRouteSameAsCurrent = false;
      navigatorKey.currentState!.popUntil((route) {
        if (route.settings.name == WebViewApp.path) {
          isNewRouteSameAsCurrent = true;
        }
        return true;
      });
      PushOpenerController opener = PushOpenerController(url: payload);
      await opener.initHumHub();
      if (isNewRouteSameAsCurrent) {
        WebViewGlobalController.value!
            .loadUrl(urlRequest: URLRequest(url: Uri.parse(opener.url), headers: opener.humhub.customHeaders));
        return;
      }
      navigatorKey.currentState!.pushNamed(WebViewApp.path, arguments: opener);
    } else {
      if (payload != null) {
        setPayloadForInit(payload);
      }
    }
  }

  static setPayloadForInit(String payload) {
    _redirectUrlFromInit = payload;
  }

  static String? usePayloadForInit() {
    String? payload = _redirectUrlFromInit;
    _redirectUrlFromInit = null;
    return payload;
  }
}
