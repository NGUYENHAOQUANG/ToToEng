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

  Future<bool> _requestExactAlarmPermission(BuildContext context) async {
    final status = await Permission.scheduleExactAlarm.status;

    if (status.isGranted) return true;
    if (status.isDenied) {
      final result = await Permission.scheduleExactAlarm.request();
      return result.isGranted;
    }
    return false;
  }

  // THÔNG BÁO STREAK (20:00) - GIỮ NGUYÊN
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
        'Vào học và hoàn thành 1 bài học 5 phút để duy trì chuỗi $streak ngày của bạn!',
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
            content: Text(
              'ngày mai tôi sẽ nhắc bạn vào học nếu gần hết thời gian duy trì chuỗi nha cho khỏi quên!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // THÔNG BÁO CÁ NHÂN (do user chọn)
  Future<void> schedulePersonalReminder(BuildContext context) async {
    final hasPermission = await _requestExactAlarmPermission(context);
    if (!hasPermission) return;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = userDoc.data() ?? {};
      final enabled = data['personalReminderEnabled'] ?? false;
      final hour = data['personalReminderHour'] ?? 8;
      final minute = data['personalReminderMinute'] ?? 0;

      if (!enabled) {
        await _notifications.cancel(1);
        return;
      }

      await _notifications.zonedSchedule(
        1,
        'Học hôm nay chưa?',
        'tới giời học rồi bro chiến thôi!',
        _nextInstanceOfTime(hour, minute),
        // _nextInstance20Hours(),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'personal_reminder',
            'Personal Study Reminder',
            channelDescription: 'Nhắc nhở học tập cá nhân',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      print("Lỗi schedulePersonalReminder: $e");
    }
  }

  // Tính giờ tiếp theo (dùng chung)
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // TEST: Thông báo streak sau 1 phút
  tz.TZDateTime _nextInstance20Hours() {
    final now = tz.TZDateTime.now(tz.local);
    final testTime = now.add(const Duration(minutes: 1));
    print("TEST: Thông báo streak lúc: $testTime");
    return testTime;
  }

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

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
