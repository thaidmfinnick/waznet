import 'package:bloc/bloc.dart';
import 'package:cecr_unwomen/features/firebase/bloc/firebase_event.dart';
import 'package:cecr_unwomen/features/firebase/bloc/firebase_state.dart';
import 'package:cecr_unwomen/features/firebase/repository/firebase_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseBloc extends Bloc<FirebaseEvent, FirebaseState>{
  FirebaseBloc() : super(const FirebaseState()) {
    on<TokenRefresh>(_onTokenRefresh);
    on<SetupFirebaseToken>(_setupFirebaseToken);
    on<ReceiveMessageForeground>(_onReceiveMessageForeground);
    on<OpenMessageBackground>(_onOpenMessageBackground);
    on<OpenMessageTerminated>(_onOpenMessageTerminated);
  }

  Future<void> _onTokenRefresh(TokenRefresh event, Emitter emit) async {
    await emit.onEach(FirebaseMessaging.instance.onTokenRefresh,
      onData: (String token) async {
        await FirebaseRepository.uploadFirebaseToken(token);
        emit(state.copyWith(FirebaseStatus.haveToken));
      },
      onError: (e, t) => emit(state.copyWith(FirebaseStatus.noToken))
    );
  }

  Future<void> _setupFirebaseToken(SetupFirebaseToken event, Emitter emit) async {
    await FirebaseMessaging.instance.requestPermission(sound: true, badge: true, alert: true, provisional: true);
    await FirebaseRepository.setupFirebaseToken();
    emit(state.copyWith(FirebaseStatus.haveToken));
  }

  Future<void> _onReceiveMessageForeground(ReceiveMessageForeground event, Emitter emit) async {
    await emit.onEach(FirebaseMessaging.onMessage,
      onData: (RemoteMessage message) async {
        if (message.notification == null) return;
        print('Message foreground also contained a notification: ${message.notification}');
      },
      onError: (e, t) => emit(state.copyWith(FirebaseStatus.noToken))
    );
  }

  Future<void> _onOpenMessageBackground(OpenMessageBackground event, Emitter emit) async {
    await emit.onEach(FirebaseMessaging.onMessageOpenedApp,
      onData: (RemoteMessage message) async {
        print('_onOpenMessageBackground:${message.notification?.body}');
        // emit(state.copyWith(FirebaseStatus.haveToken));
      },
      onError: (e, t) => emit(state.copyWith(FirebaseStatus.noToken))
    );
  }

  Future<void> _onOpenMessageTerminated(OpenMessageTerminated event, Emitter emit) async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) print('terminated noti:$initialMessage');
  }
}