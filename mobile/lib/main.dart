import 'package:cecr_unwomen/features/login/view/login_screen.dart';
import 'package:cecr_unwomen/features/home/view/home_screen.dart';
import 'package:cecr_unwomen/service/notification_service.dart';
import 'package:cecr_unwomen/utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/authentication/authentication.dart';
import 'firebase_options.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.init();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  // await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions();
  // da listen trong firebase bloc
  // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  //   // print('Message data: ${message.toMap()}');
  //   if (message.notification != null) {
  //     NotificationService.showNotification(message.notification!.title ?? "", message.notification!.body ?? "");
  //   }});

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      lazy: false,
      create: (context) => AuthenticationBloc()
        ..add(AuthSubscription())
        ..add(AutoLogin()),
      child: const MyApp()
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const BlocEntireApp(),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter'
      ),
      localizationsDelegates: const [
        // S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        // Locale('en'), // English
        Locale('vi'),
      ],
    );
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}


class BlocEntireApp extends StatelessWidget {
  const BlocEntireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        if (state.status == AuthenticationStatus.authorized) {
          return HomeScreen(key: Utils.globalHomeKey);
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
