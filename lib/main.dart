// FIREBASE PUSH REVISION: hosted API, FCM setup, safe logs, and notification-tap routing
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'core/config/api_config.dart';
import 'core/routes/app_router.dart';
import 'core/services/local_notifications_service.dart';
import 'core/services/notification_navigation_service.dart';
import 'core/services/push_token_service.dart';
import 'core/services/session_service.dart';
import 'core/state/theme_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'firebase_options.dart';

// Global theme controller.
final ThemeController themeController = ThemeController();

// Global navigator key used by notification/deep-link navigation.
final GlobalKey<NavigatorState> appNavigatorKey =
GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Android automatically displays FCM messages that contain a notification
  // payload while the app is backgrounded. Data-only messages do not, so
  // create a local notification for those messages here.
  //
  // We intentionally skip messages that already contain message.notification
  // to avoid showing the same notification twice.
  if (message.notification == null) {
    try {
      await LocalNotificationsService.init();

      final String title = (
          message.data['title'] ??
              'KuryentePay'
      )
          .toString()
          .trim();

      final String body = (
          message.data['body'] ??
              message.data['message'] ??
              'You have a new KuryentePay notification.'
      )
          .toString()
          .trim();

      final Map<String, dynamic> payload =
      Map<String, dynamic>.from(message.data);

      if (message.messageId != null) {
        payload['message_id'] = message.messageId;
      }

      final String notificationSource =
          message.messageId ??
              DateTime.now()
                  .microsecondsSinceEpoch
                  .toString();

      await LocalNotificationsService.showNotification(
        id: notificationSource.hashCode & 0x7fffffff,
        title: title.isEmpty ? 'KuryentePay' : title,
        body: body.isEmpty
            ? 'You have a new KuryentePay notification.'
            : body,
        payload: payload,
      );
    } catch (error) {
      debugPrint(
        'Unable to display background notification: '
            '${error.runtimeType}',
      );
    }
  }

  // Keep background logs minimal. Do not print full notification payloads.
  debugPrint(
    'FCM background message received: ${message.messageId ?? 'no-id'}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  // Initialise the hosted KuryentePay API configuration.
  await ApiConfig.init();

  // Prepare the Android notification channel used by KuryentePay alerts.
  await LocalNotificationsService.init();

  runApp(const IlecoPayApp());
}

class IlecoPayApp extends StatefulWidget {
  const IlecoPayApp({super.key});

  @override
  State<IlecoPayApp> createState() => _IlecoPayAppState();
}

class _IlecoPayAppState extends State<IlecoPayApp> {
  late Future<bool> _hasSession;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;

  bool _messagingConfigured = false;

  @override
  void initState() {
    super.initState();

    _hasSession = _checkSession();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_configureFirebaseMessaging());
    });
  }

  @override
  void dispose() {
    _foregroundSubscription?.cancel();
    _openedAppSubscription?.cancel();

    LocalNotificationsService.setTapHandler(null);

    super.dispose();
  }

  Future<bool> _checkSession() async {
    try {
      final user = await SessionService.loadUser();
      return user != null;
    } catch (error) {
      debugPrint(
        'Unable to restore the saved KuryentePay session: '
            '${error.runtimeType}',
      );
      return false;
    }
  }

  Future<void> _configureFirebaseMessaging() async {
    if (_messagingConfigured) {
      return;
    }

    _messagingConfigured = true;

    try {
      final FirebaseMessaging messaging =
          FirebaseMessaging.instance;

      final NotificationSettings settings =
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
        'FCM permission status: ${settings.authorizationStatus}',
      );

      LocalNotificationsService.setTapHandler(
        _handleLocalNotificationTap,
      );

      await _foregroundSubscription?.cancel();
      _foregroundSubscription =
          FirebaseMessaging.onMessage.listen(
                (RemoteMessage message) {
              unawaited(
                _showForegroundNotification(message),
              );
            },
            onError: (Object error) {
              debugPrint(
                'Foreground notification listener error: '
                    '${error.runtimeType}',
              );
            },
          );

      await _openedAppSubscription?.cancel();
      _openedAppSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(
            _handleRemoteNotificationTap,
            onError: (Object error) {
              debugPrint(
                'Notification-open listener error: '
                    '${error.runtimeType}',
              );
            },
          );

      final RemoteMessage? initialMessage =
      await messaging.getInitialMessage();

      if (initialMessage != null) {
        _handleRemoteNotificationTap(initialMessage);
      }

      // For remembered sessions, synchronise the current Firebase token
      // with KuryentePay and continue listening for token refreshes.
      await PushTokenService.start();

      final String? token = await messaging.getToken();

      debugPrint(
        token != null && token.isNotEmpty
            ? 'FCM device synchronisation is available.'
            : 'FCM token is not available yet.',
      );
    } catch (error) {
      // Notification setup should never prevent the billing app itself
      // from opening. Users can still view bills and use other features.
      debugPrint(
        'KuryentePay notification setup could not be completed: '
            '${error.runtimeType}',
      );
    }
  }

  Future<void> _showForegroundNotification(
      RemoteMessage message,
      ) async {
    final RemoteNotification? remoteNotification =
        message.notification;

    final String title = (
        remoteNotification?.title ??
            message.data['title'] ??
            'KuryentePay'
    )
        .toString()
        .trim();

    final String body = (
        remoteNotification?.body ??
            message.data['body'] ??
            message.data['message'] ??
            'You have a new KuryentePay notification.'
    )
        .toString()
        .trim();

    final Map<String, dynamic> payload =
    Map<String, dynamic>.from(message.data);

    if (message.messageId != null) {
      payload['message_id'] = message.messageId;
    }

    try {
      await LocalNotificationsService.showNotification(
        id: _notificationId(message),
        title: title.isEmpty ? 'KuryentePay' : title,
        body: body.isEmpty
            ? 'You have a new KuryentePay notification.'
            : body,
        payload: payload,
      );
    } catch (error) {
      debugPrint(
        'Unable to display foreground notification: '
            '${error.runtimeType}',
      );
    }
  }

  int _notificationId(RemoteMessage message) {
    final String source =
        message.messageId ??
            DateTime.now()
                .microsecondsSinceEpoch
                .toString();

    return source.hashCode & 0x7fffffff;
  }

  void _handleRemoteNotificationTap(
      RemoteMessage message,
      ) {
    debugPrint(
      'Remote notification opened: '
          '${message.messageId ?? 'no-id'}',
    );

    _handleNotificationPayload(
      Map<String, dynamic>.from(message.data),
    );
  }

  void _handleLocalNotificationTap(
      Map<String, dynamic>? payload,
      ) {
    debugPrint('Local notification opened.');

    _handleNotificationPayload(payload);
  }

  void _handleNotificationPayload(
      Map<String, dynamic>? payload,
      ) {
    final Map<String, dynamic> safePayload =
    payload == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(payload);

    NotificationNavigationService.openFromPayload(
      safePayload,
    );

    // Do not print full payload contents because notification data may
    // include billing/payment metadata.
    debugPrint('Notification navigation queued.');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'KuryentePay',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeController.mode,
          home: FutureBuilder<bool>(
            future: _hasSession,
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const _SplashLoading();
              }

              return snapshot.data == true
                  ? const MainShell()
                  : const LoginScreen();
            },
          ),
        );
      },
    );
  }
}

class _SplashLoading extends StatelessWidget {
  const _SplashLoading();

  // Visual-only session loader. Firebase, authentication, routing and payment
  // logic above this widget remain unchanged.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031125),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/kuryentepay_splash.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded,
                      size: 84, color: Color(0xFF36D9D0)),
                    SizedBox(height: 20),
                    Text('KuryentePay',
                      style: TextStyle(color: Colors.white,
                        fontSize: 30, fontWeight: FontWeight.w800)),
                  ],
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: SizedBox(
                  width: 92,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const LinearProgressIndicator(
                      color: Color(0xFF2DE7D1),
                      backgroundColor: Color(0x554CC0CB),
                      minHeight: 3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
