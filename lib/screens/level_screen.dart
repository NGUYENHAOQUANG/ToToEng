import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:totoeng/screens/leaderborad_screen.dart';
import 'package:totoeng/screens/profile_screen.dart';
import 'package:totoeng/screens/screen_one.dart';
import '../auth/signin_screen.dart';

class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key});

  static const Color greenPrimary = Color(0xFF4CAF50);
  static const Color greenAccent = Color(0xFF81C784);
  static const backgroundGradient = LinearGradient(
    colors: [Color(0xFFE8F5E9), Colors.white],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  int _currentIndex = 0;

  final List<String> _languages = [
    "German",
    "Spanish",
    "French",
    "Italian",
    "Korean",
  ];

  Future<void> _changeLanguage() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Lưu trước

    String? selectedLanguage = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text("Select a Language"),
          children: _languages.map((lang) {
            return SimpleDialogOption(
              child: Text(lang),
              onPressed: () {
                Navigator.pop(context, lang);
              },
            );
          }).toList(),
        );
      },
    );

    if (selectedLanguage != null) {
      await FirebaseFirestore.instance.collection("users").doc(userId).update({
        "language": selectedLanguage,
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            "Language changed to $selectedLanguage",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: LevelScreen.greenPrimary,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAndUpdateStreak();
  }

  Future<void> _checkAndUpdateStreak() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    final userSnapshot = await userRef.get();
    if (!userSnapshot.exists) return;

    final userData = userSnapshot.data()!;
    int currentStreak = userData['streak'] ?? 0;
    String? lastActiveDateStr = userData['lastActiveDate'];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastActiveDateStr != null) {
      final lastDate = DateTime.parse(lastActiveDateStr);
      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);

      final difference = today.difference(lastDay).inDays;

      if (difference == 0) {
        // đã vào hôm nay rồi → không làm gì
        return;
      } else if (difference == 1) {
        // giữ streak liên tục → +1
        currentStreak += 1;
      } else if (difference > 1) {
        // bị ngắt → reset về 1
        currentStreak = 1;
      }
    } else {
      // lần đầu tiên vào → bắt đầu streak = 1
      currentStreak = 1;
    }

    // cập nhật Firestore
    await userRef.update({
      'streak': currentStreak,
      'lastActiveDate': today.toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final levelIsQuery = FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("levels")
        .orderBy("levelNumber");

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LevelScreen.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    const Text(
                      "Language Tutor",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: LevelScreen.greenPrimary,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.settings,
                        color: LevelScreen.greenPrimary,
                      ),
                      onSelected: (value) async {
                        if (value == "language") {
                          await _changeLanguage();
                        } else if (value == "logout") {
                          await FirebaseAuth.instance.signOut();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignInScreen(),
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: "language",
                          child: ListTile(
                            leading: Icon(
                              Icons.language,
                              color: LevelScreen.greenPrimary,
                            ),
                            title: Text("Change Language"),
                          ),
                        ),
                        const PopupMenuItem(
                          value: "logout",
                          child: ListTile(
                            leading: Icon(
                              Icons.logout,
                              color: Colors.redAccent,
                            ),
                            title: Text("Logout"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StreamBuilder<DocumentSnapshot>(
                //lắng nghe dòng dữ liệu của firebase từ động cập nhật ui không cần setstate
                stream: FirebaseFirestore.instance
                    .collection("users")
                    .doc(userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final userData = snapshot.data!;
                  final email = userData["email"] ?? "user";
                  final name = email.split("@")[0];
                  final streak = userData["streak"] ?? 0;
                  final language = userData["language"] ?? "German";

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundImage: AssetImage("assets/Images/cool.png"),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Hello,$name!",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Learning $language",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF8A65), Color(0xFFFF7043)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.translate(
                                offset: const Offset(0, -2),
                                child: const Image(
                                  image: AssetImage("assets/Images/fire.gif"),
                                  height: 20,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "$streak",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                "days",
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: levelIsQuery.snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final levels = snapshot.data!.docs;

                      return SingleChildScrollView(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          children: levels.asMap().entries.map((entry) {
                            final index = entry.key;
                            final doc = entry.value;

                            final levelNumber = doc["levelNumber"] ?? index + 1;
                            final title = doc["title"] ?? "Level";
                            final bool isUnlocked =
                                doc["isUnlocked"] ?? (levelNumber == 1);
                            final bool isLeft = index % 2 == 0;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 28),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: isLeft
                                    ? MainAxisAlignment.start
                                    : MainAxisAlignment.end,
                                children: [
                                  if (isLeft)
                                    Lottie.asset(
                                      "assets/animation/animation$levelNumber.json",
                                      height: 80,
                                      width: 80,
                                    ),
                                  Column(
                                    children: [
                                      GestureDetector(
                                        onTap: isUnlocked
                                            ? () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => ScreenOne(
                                                      levelNumber: levelNumber,
                                                    ),
                                                  ),
                                                );
                                              }
                                            : null,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: isUnlocked
                                                ? const LinearGradient(
                                                    colors: [
                                                      LevelScreen.greenPrimary,
                                                      LevelScreen.greenAccent,
                                                    ],
                                                  )
                                                : const LinearGradient(
                                                    colors: [
                                                      Color(0xFF9E9E9E),
                                                      Color(0xFF757575),
                                                    ],
                                                  ),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.15,
                                                ),
                                                blurRadius: 12,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  isUnlocked
                                                      ? Icons.star
                                                      : Icons.lock,
                                                  color: Colors.white,
                                                  size: 28,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "$levelNumber",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!isLeft)
                                    Lottie.asset(
                                      "assets/animation/animation$levelNumber.json",
                                      height: 80,
                                      width: 80,
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 12,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.grey,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: SizedBox(
              width: 25,
              height: 25,
              child: Image.asset("assets/avatars/home.png"),
            ),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: SizedBox(
              width: 25,
              height: 25,
              child: Image.asset("assets/avatars/rank.png"),
            ),
            label: "Leaderboard",
          ),
          BottomNavigationBarItem(
            icon: SizedBox(
              width: 25,
              height: 25,
              child: Image.asset("assets/avatars/avatar.png"),
            ),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
