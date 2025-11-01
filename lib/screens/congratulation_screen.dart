import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:totoeng/screens/level_screen.dart';
import 'package:totoeng/services/notification_service.dart';

class CongratulationScreen extends StatefulWidget {
  final int levelNumber;
  const CongratulationScreen({super.key, required this.levelNumber});

  @override
  State<CongratulationScreen> createState() => _CongratulationScreenState();
}

class _CongratulationScreenState extends State<CongratulationScreen> {
  static const Color greenPrimary = Color(0xFF4CAF50);

  bool _isLoading = true;
  int _streak = 1;

  @override
  void initState() {
    super.initState();
    _completeLevel();
  }

  void _completeLevel() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = FirebaseFirestore.instance.collection("users").doc(uid);
      final nextLevel = widget.levelNumber + 1;

      // Mở khóa level tiếp theo
      await userDoc.collection("levels").doc("level_$nextLevel").set({
        "isUnlocked": true,
      }, SetOptions(merge: true));

      // Lấy dữ liệu người dùng hiện tại
      final userSnapshot = await userDoc.get();
      final lastActive = userSnapshot["lastActive"] as Timestamp?;
      int streak = userSnapshot.data()?["streak"] ?? 0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Xử lý streak
      if (widget.levelNumber == 1) {
        streak = 1;
      } else {
        if (lastActive != null) {
          final lastDate = lastActive.toDate();
          final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
          final difference = today.difference(lastDay).inDays;

          if (difference == 1) {
            streak++;
          } else if (difference > 1) {
            streak = 1;
          }
          // Nếu difference == 0 → cùng ngày → giữ nguyên streak
        } else {
          streak = 1;
        }
      }

      // Cập nhật Firestore: XP, streak, lastActive
      await userDoc.set({
        "xp": FieldValue.increment(20),
        "streak": streak,
        "lastActive": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ĐÃ SỬA: Truyền context vào
      await NotificationService().scheduleDailyReminder(context);

      // Cập nhật UI
      setState(() {
        _isLoading = false;
        _streak = streak;
      });
    } catch (e) {
      print("Error in _completeLevel: $e");
      setState(() {
        _isLoading = false;
        _streak = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundGradient = LinearGradient(
      colors: [Color(0xFFE8F5E9), Colors.white],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: greenPrimary)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animation chúc mừng
                      Lottie.asset(
                        "assets/animation/congratulation1.json",
                        width: 250,
                        height: 250,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),

                      // Tiêu đề
                      const Text(
                        "Congratulations!",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: greenPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      const Text(
                        "You have completed the level!",
                        style: TextStyle(fontSize: 18, color: Colors.black87),
                      ),
                      const SizedBox(height: 20),

                      // Streak badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: Colors.orangeAccent,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Streak: $_streak days",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Nút quay lại
                      SizedBox(
                        width: 210,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LevelScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: greenPrimary,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 32,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                          child: const Text(
                            "Back to levels",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
