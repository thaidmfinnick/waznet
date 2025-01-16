import 'package:cecr_unwomen/constants/color_constants.dart';
import 'package:cecr_unwomen/constants/extension/datetime_extension.dart';
import 'package:cecr_unwomen/features/authentication/authentication.dart';
import 'package:cecr_unwomen/features/authentication/models/user.dart';
import 'package:cecr_unwomen/features/firebase/firebase.dart';
import 'package:cecr_unwomen/features/home/view/component/card_statistic.dart';
import 'package:cecr_unwomen/features/home/view/component/header_widget.dart';
import 'package:cecr_unwomen/features/home/view/component/tab_bar_widget.dart';
import 'package:cecr_unwomen/features/home/view/contribution_screen.dart';
import 'package:cecr_unwomen/features/home/view/statistic_screen.dart';
import 'package:cecr_unwomen/features/user/view/user_info.dart';
import 'package:cecr_unwomen/temp_api.dart';
import 'package:cecr_unwomen/utils.dart';
import 'package:cecr_unwomen/widgets/circle_avatar.dart';
import 'package:cecr_unwomen/widgets/filter_time.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:syncfusion_flutter_charts/charts.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final ColorConstants colorCons = ColorConstants();
  final ScrollController _scrollControllerHome = ScrollController();
  bool isHouseholdTab = true;
  int _currentIndex = 0;
  final Map householdData = {};
  final Map scraperData = {};
  bool needGetDataChart = false;
  bool needGetDataAdmin = false;

  changeBar() {
    setState(() {
      isHouseholdTab = !isHouseholdTab;
    });
  }

  buildBarItem({required PhosphorIconData icon, required PhosphorIconData activeIcon, required String title}) {
    return SalomonBottomBarItem(
      icon: PhosphorIcon(icon, size: 24, color: const Color(0xFF808082)),
      title: Text(title),
      activeIcon: PhosphorIcon(activeIcon, size: 24, color: const Color(0xFF348A3A)),
      selectedColor: const Color(0xFF348A3A)
    );
  }

  @override
  void initState() {
    super.initState();
    Utils.checkUpdateApp(context);
    Utils.globalContext = context;
    final User? user = context.read<AuthenticationBloc>().state.user;
    if (user == null) return;
    isHouseholdTab = user.roleId != 3;
    callApiGetOverallData();
  }

  callApiGetOverallData() async {
    // TODO: move to bloc
    if (!mounted) return;
    final int roleId = context.read<AuthenticationBloc>().state.user!.roleId;
    final data  = await TempApi.getOverallData();

    if (!(data["success"] ?? false)) return;

    if (roleId == 2) {
      setState(() {
        householdData['statistic'] = data["data"];
      });
    } else if (roleId == 3) {
      setState(() {
        scraperData['statistic'] = data["data"];
      });
    } else if (roleId == 1) {
      setState(() {
        householdData['statistic'] = data["data"]["household_overall_data"];
        scraperData['statistic'] = data["data"]["scraper_overall_data"];
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _scrollControllerHome.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map allData = isHouseholdTab ? (householdData['statistic'] ?? {}) : (scraperData['statistic'] ?? {});
    final int roleId = context.watch<AuthenticationBloc>().state.user!.roleId;

     Widget buildChart() {
      switch (roleId) {
        case 2:
          return HouseholdChart(needGetData: needGetDataChart,);
        case 3: 
          return ScraperChart(needGetData: needGetDataChart,);
        default:
          return AdminChart(statistic: allData, isHouseholdTab: isHouseholdTab,);
      }
    }

    final Widget adminWidget = Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: [
          HeaderWidget(
            child: Builder(
              builder: (context) {
                final User? user = context.watch<AuthenticationBloc>().state.user;
                if (user == null) return const SizedBox();
      
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CustomCircleAvatar(
                          size: 40,
                          avatarUrl: user.avatarUrl,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${user.firstName} ${user.lastName}",
                                style: colorCons.fastStyle(
                                    16, FontWeight.w600, colorCons.primaryBlack1)),
                            const SizedBox(height: 2),
                            Text("Hôm nay bạn thế nào??",
                                style: colorCons.fastStyle(
                                    14, FontWeight.w400, colorCons.primaryBlack1))
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // InkWell(
                    //   onTap: () => Utils.showDialogWarningError(context, false, "Chức năng đang được phát triển"),
                    //   child: Container(
                    //     height: 40,
                    //     width: 40,
                    //     decoration: const BoxDecoration(
                    //       shape: BoxShape.circle,
                    //       color: Colors.white,
                    //     ),
                    //     child: PhosphorIcon(PhosphorIcons.regular.bell,
                    //         size: 24, color: colorCons.primaryBlack1),
                    //   ),
                    // ),
                  ],
                );
              }
            ),
          ),
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: () {
                setState(() {
                  needGetDataAdmin = !needGetDataAdmin;
                });
                return callApiGetOverallData();
              },
              child: SingleChildScrollView(
                controller: _scrollControllerHome,
                child: Column(
                  children: [
                    BarWidget(isHousehold: isHouseholdTab, changeBar: changeBar),
                    CardStatistic(
                      isHouseholdTab: isHouseholdTab, 
                      statistic: allData
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          buildChart(),
                          if (roleId == 1) 
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: StatisticScreen(
                              roleId: roleId, 
                              isHouseHoldTabAdminScreen: isHouseholdTab,
                              needGetDataAdmin: needGetDataAdmin,
                            ),
                          )
                        ],
                      ),
                    ),
                  ]
                ),
              ),
            ),
          )
        ],
      ),
    );


    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F5),
      floatingActionButton: roleId != 1 && _currentIndex == 0 ? FloatingActionButton(
        shape: const CircleBorder(),
        onPressed: () async {          
          needGetDataChart = true;
          final bool? shouldCallApi = await Navigator.push(context, MaterialPageRoute(builder: (context) => ContributionScreen(roleId: roleId)));
          needGetDataChart = false;
          if (!(shouldCallApi ?? false)) return;
          callApiGetOverallData();
        },
        backgroundColor: const Color(0xFF4CAF50),
        child: Icon(PhosphorIcons.regular.plus, size: 24, color: Colors.white),
      ) : null,
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        child: SalomonBottomBar(
          backgroundColor: Colors.white,
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          itemPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          items: [
            buildBarItem(
              activeIcon: PhosphorIcons.fill.house,
              icon: PhosphorIcons.regular.house, title: "Trang chủ"
            ),
            buildBarItem(
              activeIcon: PhosphorIcons.fill.chartBar,
              icon: PhosphorIcons.regular.chartBar, title: "Dữ liệu"
            ),
            buildBarItem(
              activeIcon: PhosphorIcons.fill.userCircle,
              icon: PhosphorIcons.regular.userCircle, title: "Tài khoản"
            ),
        ]),
      ),
      body: BlocProvider(
        lazy: false,
        create: (context) => FirebaseBloc()
          ..add(SetupFirebaseToken())
          ..add(TokenRefresh())
          ..add(OpenMessageBackground())
          ..add(OpenMessageTerminated())
          ..add(ReceiveMessageForeground()),
        child: _currentIndex == 0 ? adminWidget
          : _currentIndex == 1 ?
          StatisticScreen(
            roleId: roleId,
          )
          : const UserInfo(),
        ),
      );
    }
}

class CardInfoWidget extends StatelessWidget {
  const CardInfoWidget({super.key, required this.icon, required this.text, required this.number});
  final Widget icon;
  final String text;
  final String number;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -5,
            bottom: -20,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  colors: [Color(0xFFFFFCF0), Color(0xFFC8E6C9)], // Define your gradient colors here
                  tileMode: TileMode.clamp,
                  begin: Alignment.centerLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds);
              },
              child: icon
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: const TextStyle(
                        color: Color(0xFF666667),
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Text(number,
                    style: const TextStyle(
                        color: Color(0xFF29292A),
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}





class HouseholdChart extends StatefulWidget {
  final bool needGetData;
  const HouseholdChart({super.key, this.needGetData = false});

  @override
  State<HouseholdChart> createState() => _HouseholdChartState();
}

class _HouseholdChartState extends State<HouseholdChart> {
  TimeFilterOptions option = TimeFilterOptions.thisMonth;
  Map dataStatistic = {};
  late DateTime start;
  late DateTime end;
  
  @override
  void initState() {
    super.initState();
    callApiGetFilterOverallData();
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
      if (widget.needGetData != oldWidget.needGetData) {
        callApiGetFilterOverallData();
      }
  }


  callApiGetFilterOverallData({bool isCustomRange = false}) async {
    if (!mounted) return;
    if (!isCustomRange) {
      Map dateMap = TimeFilterHelper.getDateRange(option);
      start = dateMap["start_date"];
      end = dateMap["end_date"];
    }

    final data  = await TempApi.getFilterOverallData(
      start: start,
      end: end
    );

    if (!(data["success"] ?? false)) return;
    setState(() {
      dataStatistic = data["data"];
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorConstants colorCons = ColorConstants();
    List data = dataStatistic["sum_factors"] ?? [];
    List recycled = data.where((e) => (e["factor_name"] ?? "").contains("kilo")).map((e) {
      e.putIfAbsent("color", () {
        switch (e["factor_name"]) {
          case "one_kilo_plastic_recycled":
            return const Color(0xffA569BD);
          case "one_kilo_paper_recycled":
            return const Color(0xff58D68D);
          case "one_kilo_metal_garbage_recycled":
            return const Color(0xff5DADE2);
          case "one_kilo_organic_garbage_to_fertilizer":
            return const Color(0xffF1948A);
          default:
            return const Color(0xffF1948A);
        }
      });
      return e;
    }).toList();

    List rejected = data.where((e) => (e["factor_name"] ?? "").contains("rejected")).map((e) {
      e.putIfAbsent("color", () {
        switch (e["factor_name"]) {
          case "one_plastic_bag_rejected":
            return const Color(0xffA569BD);
          case "one_pet_bottle_rejected":
            return const Color(0xff64B5F6);
          case "one_plastic_cup_rejected":
            return const Color(0xffFFB74D);
          case "one_plastic_straw_rejected":
            return const Color(0xff81C784);
          default:
            return const Color(0xffF1948A);
        }
      });
      return e;
    }).toList();

    String convertGarbageCountToTitle(String key) {
      switch(key) {
        case "one_kilo_plastic_recycled":
          return "Nhựa";
        case "one_kilo_paper_recycled":
          return "Giấy";
        case "one_kilo_metal_garbage_recycled":
          return "Kim loại";
        case "one_kilo_organic_garbage_to_fertilizer":
          return "Hữu cơ";
        default: 
          return "";
      }
    }

    String convertRejectedCountToTitle(String key) {
      switch(key) {
        case "one_plastic_bag_rejected":
          return "Túi nhựa";
        case "one_pet_bottle_rejected":
          return "Chai nhựa";
        case "one_plastic_cup_rejected":
          return "Cốc dùng một lần";
        case "one_plastic_straw_rejected":
          return "Ống hút nhựa";
        default:
          return "";
      }
    }

    Widget label(String title, double value, Color color,) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 14,
              width: 14,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color
              ),
            ),
            const SizedBox(width: 6,),
            Expanded(
              child: Text(
                "$title (${value.toString()} kg)",
                style: colorCons.fastStyle(14, FontWeight.w400, const Color(0xff333334)),
              ),
            )
          ],
        ),
      );
    }

    Widget buildChartItem({bool isRecyled = true}) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isRecyled ? "Đóng góp tái chế rác thải" : "Đóng góp giảm thiểu đồ nhựa", 
                style: colorCons.fastStyle(14, FontWeight.w600, const Color(0xff666667)),
              ),
              InkWell(
                onTap: () {
                  showCupertinoModalPopup(
                    context: context, 
                    builder: (context) {
                      return TimeFilter(
                        option: option,
                        start: start,
                        end: end,
                        onSave: (e) {
                          setState(() {
                            option = e;
                          });
                          if (!TimeFilterHelper.isCustomOption(option)) {
                            callApiGetFilterOverallData();
                          }
                        },
                        onSaveCustomRange: (startDate, endDate) {
                          setState(() {
                            start = startDate;
                            end = endDate;
                          });
                          callApiGetFilterOverallData(isCustomRange: true);
                        },
                      );
                    }
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xffE3E3E5)
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.regular.calendarBlank, size: 20, color: const Color(0xff4D4D4E),),
                      Text(" ${TimeFilterHelper.getOptionsString(option)}",  style: colorCons.fastStyle(14, FontWeight.w500, const Color(0xff4D4D4E)),)
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12,),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xffFFFFFF),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: const Color(0xff18274B).withOpacity(0.12),spreadRadius: -2, blurRadius: 4, offset: const Offset(0, 2)),
                BoxShadow(color: const Color(0xff18274B).withOpacity(0.08),spreadRadius: -2, blurRadius: 4, offset: const Offset(0, 4))
              ]
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child:  Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sections: (isRecyled ? recycled : rejected).map((e) {
                        return PieChartSectionData(
                          radius: 20,
                          title: "",
                          value: e["quantity"] ?? 0,
                          color: e["color"] ?? const Color(0xffF1948A)
                        );
                      }).toList()
                    )
                  ),
                ),
                const SizedBox(width: 15,),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: (isRecyled ? recycled : rejected).map((e) {
                      return label(
                        (isRecyled ? convertGarbageCountToTitle(e["factor_name"] ?? "") : convertRejectedCountToTitle(e["factor_name"] ?? "")),
                        e["quantity"] ?? 0,
                        e["color"] ?? const Color(0xffF1948A)
                      );
                    }).toList()
                  ),
                )
              ],
            ),
          ),
        ],
      );
    }


    return  Column(
      children: [
        buildChartItem(),
        const SizedBox(height: 32,),
        buildChartItem(isRecyled: false)
      ]
    );
  }
}


class ScraperChart extends StatefulWidget {
  final bool needGetData;
  const ScraperChart({super.key, this.needGetData = false});

  @override
  State<ScraperChart> createState() => _ScraperChartState();
}

class _ScraperChartState extends State<ScraperChart> {
  TimeFilterOptions option = TimeFilterOptions.thisMonth;
  Map dataStatistic = {};
  late DateTime start;
  late DateTime end;
  
  @override
  void initState() {
    super.initState();
    callApiGetFilterOverallData();
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
      if (widget.needGetData != oldWidget.needGetData) {
        callApiGetFilterOverallData();
      }
  }


  callApiGetFilterOverallData({bool isCustomRange = false}) async {
    if (!mounted) return;
    if (!isCustomRange) {
      Map dateMap = TimeFilterHelper.getDateRange(option);
      start = dateMap["start_date"];
      end = dateMap["end_date"];
    }

    final data  = await TempApi.getFilterOverallData(
      start: start,
      end: end
    );

    if (!(data["success"] ?? false)) return;
    setState(() {
      dataStatistic = data["data"];
    });
  }


  @override
  Widget build(BuildContext context) {
    final ColorConstants colorCons = ColorConstants();
    List data = dataStatistic["sum_factors"] ?? [];
    List collected = data.where((e) => (e["factor_name"] ?? "").contains("collected")).map((e) {
      e.putIfAbsent("color", () {
        switch (e["factor_name"]) {
          case "one_kilo_plastic_collected":
            return const Color(0xffA569BD);
          case "one_kilo_paper_collected":
            return const Color(0xff58D68D);
          case "one_kilo_metal_garbage_collected":
            return const Color(0xff5DADE2);
          default:
            return const Color(0xffF1948A);
        }
      });
      return e;
    }).toList();


    String convertCollectedCountToTitle(String key) {
      switch(key) {
        case "one_kilo_plastic_collected":
          return "Nhựa";
        case "one_kilo_paper_collected":
          return "Giấy";
        case "one_kilo_metal_garbage_collected":
          return "Kim loại";
        default: 
          return "";
      }
    }

    Widget label(String title, double value, Color color,) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 14,
              width: 14,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color
              ),
            ),
            const SizedBox(width: 6,),
            Expanded(
              child: Text(
                "$title (${value.toString()} kg)",
                style: colorCons.fastStyle(14, FontWeight.w400, const Color(0xff333334)),
              ),
            )
          ],
        ),
      );
    }

    Widget buildChartItem() {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Khối lượng thu gom theo loại", 
                style: colorCons.fastStyle(14, FontWeight.w600, const Color(0xff666667)),
              ),
              InkWell(
                onTap: () {
                  showCupertinoModalPopup(
                    context: context, 
                    builder: (context) {
                      return TimeFilter(
                        option: option,
                        start: start,
                        end: end,
                        onSave: (e) {
                          setState(() {
                            option = e;
                          });
                          if (!TimeFilterHelper.isCustomOption(option)) {
                            callApiGetFilterOverallData();
                          }
                        },
                        onSaveCustomRange: (startDate,endDate) {
                          setState(() {
                            start = startDate;
                            end = endDate;
                          });
                          callApiGetFilterOverallData(isCustomRange: true);
                        },
                      );
                    }
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xffE3E3E5)
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.regular.calendarBlank, size: 20, color: const Color(0xff4D4D4E),),
                      Text(" ${TimeFilterHelper.getOptionsString(option)}",  style: colorCons.fastStyle(14, FontWeight.w500, const Color(0xff4D4D4E)),)
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12,),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xffFFFFFF),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: const Color(0xff18274B).withOpacity(0.12),spreadRadius: -2, blurRadius: 4, offset: const Offset(0, 2)),
                BoxShadow(color: const Color(0xff18274B).withOpacity(0.08),spreadRadius: -2, blurRadius: 4, offset: const Offset(0, 4))
              ]
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sections: collected.map((e) {
                        return PieChartSectionData(
                          radius: 25,
                          title: "",
                          value: e["quantity"] ?? 0,
                          color: e["color"] ?? const Color(0xffF1948A)
                        );
                      }).toList()
                    )
                  ),
                ),
                const SizedBox(width: 15,),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: collected.map((e) {
                      return label(
                        convertCollectedCountToTitle(e["factor_name"] ?? ""),
                        e["quantity"] ?? 0,
                        e["color"] ?? const Color(0xffF1948A)
                      );
                    }).toList()
                  ),
                )
              ],
            ),
          ),
        ],
      );
    }

    return buildChartItem();
  } 
}

class AdminChart extends StatelessWidget {
  final Map statistic;
  final bool isHouseholdTab;
  const AdminChart({super.key,required this.statistic, required this.isHouseholdTab});

  @override
  Widget build(BuildContext context) {
    final ColorConstants colorCons = ColorConstants();
    List data = statistic["total_kgco2e_seven_days"] ?? [];
    DateTime now = DateTime.now();
    Map<String, double> data7Days = {};
    for (int i = 0; i < 7; i++) {
      final DateTime date = now.subtract(Duration(days: i));  
      final value = data
        .where((e) => e["date"] != null && DateTime.parse(e["date"]).isSameDate(date))
        .map<double>((e) => e["total_kg_co2e"])
        .fold(0.0, (prev, curr) {
          return prev + curr;
        });
      
      data7Days.putIfAbsent(i == 0 ? " Hôm\nnay" : DateFormat("d/M").format(date), () => value);
    }  
    // reversed
    data7Days = Map.fromEntries( data7Days.entries.toList().reversed);

    Widget buildChartItem() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Giảm phát thải CO₂ trong 7 ngày qua", 
            style: colorCons.fastStyle(14, FontWeight.w600, const Color(0xff666667)),
          ),
          const SizedBox(height: 12,),
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: const Color(0xffFFFFFF),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: const Color(0xff18274B).withOpacity(0.12),spreadRadius: -2, blurRadius: 4, offset: const Offset(0, 2)),
                BoxShadow(color: const Color(0xff18274B).withOpacity(0.08),spreadRadius: -2, blurRadius: 4, offset: const Offset(0, 4))
              ]
            ),
            padding: const EdgeInsets.only(top: 10, right: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("  kgCO₂e", style: colorCons.fastStyle(12, FontWeight.w400, const Color(0xff808082)),),
                const SizedBox(height: 6,),
                Expanded(
                  child: SfCartesianChart(
                    enableAxisAnimation: true,
                    plotAreaBorderWidth: 0,
                    primaryXAxis: CategoryAxis(
                      majorGridLines: const MajorGridLines(width: 0),
                      majorTickLines: const MajorTickLines(size: 0, color: Color(0xffF4F4F5)),
                      labelStyle: colorCons.fastStyle(14,FontWeight.w400, const Color(0xff808082)),
                      axisLine: const AxisLine(color: Color(0xffE3E3E5), width: 1),
                      axisLabelFormatter: (axisLabelRenderArgs) {
                        return ChartAxisLabel(axisLabelRenderArgs.text, colorCons.fastStyle(14,FontWeight.w400, const Color(0xff808082)));
                      },
                    ),
                    primaryYAxis: NumericAxis(
                      majorGridLines: const MajorGridLines(dashArray: <double>[6, 4], color: Color(0x4dc1c1c2), width: 1),
                      labelStyle: colorCons.fastStyle(14,FontWeight.w400, const Color(0xff808082)),
                      axisLine: const AxisLine(width: 0),
                      majorTickLines: const MajorTickLines(size: 0),
                    ),
                    series: [
                      ColumnSeries<MapEntry<String, double>, String>(
                        dataLabelMapper: (data, _) => data.value.floor().toString(),
                        dataLabelSettings: DataLabelSettings(
                          isVisible: true,
                          labelAlignment: ChartDataLabelAlignment.outer,
                          textStyle: colorCons.fastStyle(12, FontWeight.w400, const Color(0xffC1C1C2))
                        ),                 
                        dataSource: data7Days.entries.toList(),
                        gradient: const LinearGradient(colors: [
                          Color(0xff4CAF50),
                          Color(0xffA5D6A7)
                        ]),
                        xValueMapper: (data, _) => data.key,
                        yValueMapper: (data, _) => data.value,
                        borderRadius: const BorderRadius.all(Radius.circular(14)),
                        width: 0.35, 
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    
   return buildChartItem();
  }
}