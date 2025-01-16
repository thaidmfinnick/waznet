import 'dart:convert';
import 'dart:io';

import 'package:cecr_unwomen/constants/color_constants.dart';
import 'package:cecr_unwomen/features/home/view/home_screen.dart';
import 'package:cecr_unwomen/secrets.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class Utils {
  static BuildContext? globalContext;
  static GlobalKey<HomeScreenState> globalHomeKey = GlobalKey<HomeScreenState>();

  static Future<String?> getFirebaseToken() async {
    final String? fcmToken = await FirebaseMessaging.instance.getToken();
    return fcmToken;
  }
  static String apiUrl = Secrets.apiUrl;
  static String parseContributionDate(String input, {String format = 'dd/MM/yyyy - HH:mm'}) {
    final DateTime? date = DateTime.tryParse(input);
    if (date == null) return "";
    final DateFormat formatter = DateFormat(format);
    final String formattedDate = formatter.format(date.add(const Duration(hours: 7)));
    return formattedDate;
  }

  static String? getContributorName(String? firstName, String? lastName) {
    final bool hasName = firstName != null && lastName != null;
    if (!hasName) return null;
    return "$firstName $lastName";
  }

  static Future<dynamic> showDialogWarningError(BuildContext context, bool isDark, String warningContent) {
    final Color colorInput = isDark ? const Color(0xFF25282A) : const Color(0xFFF2F4F7);
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: colorInput,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
              child: Container(
                width: 230,
                height: 130,
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Text(warningContent,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFF6F6F7) : const Color(0xFF101828),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text("Đóng",
                        style: TextStyle(color: ColorConstants().bgClickable, fontSize: 16, fontWeight: FontWeight.w600),),
                    ),
                  ],
                )
              )
            );
          }
        );
      }
    );
  }

  static void showDatePicker({
    required BuildContext context,
    required Function() onCancel,
    required Function() onSave,
    required void Function(DateTime) onDateTimeChanged,
    DateTime? initDate,
    CupertinoDatePickerMode mode = CupertinoDatePickerMode.date,
  }) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Material(
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12), topRight: Radius.circular(12)),
          child: Container(
              height: 300,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 3),
              color: const Color(0xffFFFFFF),
              child: Column(
                children: [
                  Container(
                    height: 5,
                    width: 45,
                    margin: const EdgeInsets.only(top: 6, bottom: 12),
                    decoration: BoxDecoration(
                        color: const Color(0xffC1C1C2),
                        borderRadius: BorderRadius.circular(100)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                          onTap: onCancel,
                          child: Text(
                            "Huỷ",
                            style: ColorConstants().fastStyle(
                                16, FontWeight.w500, const Color(0xff4CAF50)),
                          )),
                      Text(
                        "Chọn thời gian",
                        style: ColorConstants().fastStyle(
                            16, FontWeight.w700, const Color(0xff29292A)),
                      ),
                      InkWell(
                          onTap: onSave,
                          child: Text(
                            "Lưu",
                            style: ColorConstants().fastStyle(
                                16, FontWeight.w500, const Color(0xff4CAF50)),
                          ))
                    ],
                  ),
                  Flexible(
                    child: CupertinoDatePicker(
                      initialDateTime: initDate ?? DateTime.now(),
                      mode: mode,
                      use24hFormat: true,
                      onDateTimeChanged: onDateTimeChanged,
                      dateOrder: DatePickerDateOrder.dmy,
                    ),
                  )
                ],
              )),
        ),
      ),
    );
  }
  
  static openUrl(String? url) async{
    Uri uri = Uri.parse(url ?? "");
    if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  static Future checkUpdateApp(BuildContext context) async {
    try {
      SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
      if (kDebugMode) return;
      if (Platform.isAndroid){
        InAppUpdate.checkForUpdate().then((res) {
          if (res.flexibleUpdateAllowed) {
            InAppUpdate.startFlexibleUpdate();
          }
        });
      } else {
        String url = "https://itunes.apple.com/lookup?bundleId=vn.sparc.waznet";
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        String versionCurrent = packageInfo.version;
        if (sharedPreferences.getString("current_version") != versionCurrent) {
          sharedPreferences.setString("current_version", versionCurrent);
          sharedPreferences.setBool("show_update_dialog", true);
        }
        bool isShowDialogUpdate = sharedPreferences.getBool("show_update_dialog") ?? false;
        var res = await Dio().get(url);
        var versionCurrentStore = (jsonDecode(res.data))["results"][0]["version"];
        if (int.parse("${versionCurrentStore.split(".").join()}") > int.parse(versionCurrent.split(".").join()) && isShowDialogUpdate && context.mounted) {
          return showDialog(
            context: context,
            builder: (BuildContext c) {
              return CupertinoAlertDialog(
                title: const Text("Có bản cập nhật mới", style: TextStyle(fontWeight: FontWeight.w600, fontFamily: "Inter", fontSize: 18)),
                content: const Text("Vui lòng cập nhật ứng dụng để trải nghiệm thêm các tính năng mới", style: TextStyle(fontFamily: "Inter", fontSize: 14),),
                actions: <Widget>[
                  CupertinoDialogAction(
                    child: const Text(
                      "Cập nhật",
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueAccent, fontFamily: "Inter",),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Utils.openUrl("https://apps.apple.com/us/app/waznet/id6738925384");
                    },
                  ),
                  CupertinoDialogAction(
                    child: const Text(
                      "Không nhắc lại",
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueAccent, fontFamily: "Inter",),
                    ),
                    onPressed: () {
                      sharedPreferences.setBool("show_update_dialog", false);
                      Navigator.pop(context);
                    },
                  ),
                  CupertinoDialogAction(
                    child: const Text(
                      "Để sau",
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueAccent, fontFamily: "Inter",),
                    ),
                    onPressed: () => Navigator.pop(context),
                  )
                ]
              );
          });
        }
      }      
    } catch (e, t) { 
      print("_________________________________________________checkUpdateApp Error: $e \n $t");
    }
  }
}