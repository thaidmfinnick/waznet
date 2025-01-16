import 'dart:convert';

import 'package:cecr_unwomen/features/home/view/component/modal/user_contribution_detail.dart';
import 'package:cecr_unwomen/features/home/view/contribution_screen.dart';
import 'package:cecr_unwomen/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
void notificationTapBackground(data) async {
  // handle action
  switch (data["type"]) {
      case "user_contribute_data":
        Map oneDayData = data["role_id"] == 3 ? {
          "kg_co2e_plastic_reduced": double.tryParse(data["kg_co2e_plastic_reduced"]) ?? 0,
          "kg_co2e_recycle_reduced": double.tryParse(data["kg_co2e_recycle_reduced"]) ?? 0,
          "kg_recycle_collected": double.tryParse(data["kg_recycle_collected"]) ?? 0,
          "date": data["date"]
        } : {
          "kg_co2e_reduced": double.tryParse(data["kg_co2e_reduced"]) ?? 0,
          "kg_collected": double.tryParse(data["kg_collected"]) ?? 0,
          "expense_reduced": double.tryParse(data["expense_reduced"]) ?? 0,
          "date": data["date"]
        };
        Navigator.push(Utils.globalContext!, MaterialPageRoute(
        builder: (context) => Material(
          child: UserContributionDetailScreen(
              oneDayData: oneDayData,
              userId: data["user_id"],
              name: data["name"],
              avatarUrl: data["avatar_url"].isEmpty ? null : data["avatar_url"],
              date: data["formatted_date"],
              roleIdUser: int.parse(data["role_id"])
              ),
            )
          )
        );
        break;

      case "remind_to_contribute":
        int roleId = int.parse(data["role_id"]);
        final homeScreenKey =  Utils.globalHomeKey;
        if (homeScreenKey.currentState == null) return;
        if (homeScreenKey.currentState!.needGetDataChart) return;
        homeScreenKey.currentState!.needGetDataChart = false;
        
        final bool? shouldCallApi = await Navigator.push(homeScreenKey.currentState!.context, MaterialPageRoute(builder: (context) => ContributionScreen(roleId: roleId)));
        if (!(shouldCallApi ?? false)) return;
        homeScreenKey.currentState!.needGetDataChart = true;
        homeScreenKey.currentState!.callApiGetOverallData();
        break;
      default:
        return;
  }
}
class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void>  onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
    final data = jsonDecode(notificationResponse.payload!);

    if (data["type"] == null) return;
    notificationTapBackground(data);
  }

  static Future<void>  onDidReceiveBackgroundNotificationResponse(NotificationResponse notificationResponse) async {
    // final data = jsonDecode(notificationResponse.payload!);

    // if (data["type"] == null) return;
    // notificationTapBackground(data);
  }

  static void init(){
    // android
    const AndroidInitializationSettings initializationSettingsAndroid =  AndroidInitializationSettings('@mipmap/waznet_icon');
    // ios
    const DarwinInitializationSettings initializationSettingsDarwin =  DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse
    );
  }

  static Future<void> showNotification(String title, String body, String? payload) async {
    NotificationDetails details = const NotificationDetails(
      android: AndroidNotificationDetails("channel_id", "channel_name", importance: Importance.high, priority: Priority.high),
      iOS: DarwinNotificationDetails()
    );

    await flutterLocalNotificationsPlugin.show((DateTime.now().millisecondsSinceEpoch / 10000).ceil(), title, body, details, payload: payload);
  }
}