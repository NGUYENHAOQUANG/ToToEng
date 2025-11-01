import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Khởi tạo thông báo
  Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(settings);
  }

  // YÊU CẦU QUYỀN ĐẶT BÁO THỨC CHÍNH XÁC
  Future<bool> _requestExactAlarmPermission(BuildContext context) async {
    final status = await Permission.scheduleExactAlarm.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.scheduleExactAlarm.request();
      if (result.isGranted) return true;
    }

    return false;
  }

  // ĐẶT LỊCH THÔNG BÁO HÀNG NGÀY LÚC 20:00
  Future<void> scheduleDailyReminder(BuildContext context) async {
    final hasPermission = await _requestExactAlarmPermission(context);
    if (!hasPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Không thể đặt lịch nếu chưa cấp quyền báo thức!"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final streak = await _getCurrentStreak();

      await _notifications.zonedSchedule(
        0,
        'Đừng mất streak!',
        'Học 5 phút để duy trì chuỗi $streak ngày của bạn!',
        _nextInstance20Hours(),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'streak_reminder',
            'Streak Reminders',
            channelDescription: 'Nhắc nhở học tập để giữ streak',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đặt lịch nhắc nhở hàng ngày lúc 20:00!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đặt lịch: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // // TÍNH TOÁN THỜI GIAN 20:00 TIẾP THEO
  // tz.TZDateTime _nextInstance20Hours() {
  //   final now = tz.TZDateTime.now(tz.local);
  //   var scheduledDate = tz.TZDateTime(
  //     tz.local,
  //     now.year,
  //     now.month,
  //     now.day,
  //     20,
  //     0,
  //   );

  //   if (scheduledDate.isBefore(now)) {
  //     scheduledDate = scheduledDate.add(const Duration(days: 1));
  //   }
  //   return scheduledDate;
  // }
  tz.TZDateTime _nextInstance20Hours() {
    final now = tz.TZDateTime.now(tz.local);
    final testTime = now.add(const Duration(minutes: 1)); // 1 phút nữa
    print("TEST: Thông báo sẽ hiện lúc: $testTime");
    return testTime;
  }

  // LẤY STREAK HIỆN TẠI TỪ FIRESTORE
  Future<int> _getCurrentStreak() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return 0;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      return doc.data()?['streak'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // HỦY TẤT CẢ THÔNG BÁO
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
