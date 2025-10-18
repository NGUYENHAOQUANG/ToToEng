import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lottie/lottie.dart';
import 'package:totoeng/screens/screen_two.dart';

class ScreenOne extends StatefulWidget {
  final int levelNumber;
  const ScreenOne({super.key, required this.levelNumber});

  @override
  State<ScreenOne> createState() => _ScreenOneState();
}

class _ScreenOneState extends State<ScreenOne> {
  final FlutterTts flutterTts = FlutterTts();
  final player = AudioPlayer();
  late final OnDeviceTranslator translator;

  String word = '';
  String request = 'Choose the correct picture of the word!';
  List<Map<String, dynamic>> options = [];
  String selectedOption = '';

  static const Color greenPrimary = Color(0xFF4caf50);
  static const Color greenAccent = Color(0xFF81c784);

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    await _initTranslator();
    await _fetchTask();
  }

  Future<void> _initTranslator() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .get();

    final userLang = userDoc["language"] ?? "German";
    final targetLang = _mapLanguageToEnum(userLang);

    translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: targetLang,
    );
  }

  TranslateLanguage _mapLanguageToEnum(String language) {
    switch (language.toLowerCase()) {
      case "german":
        return TranslateLanguage.german;
      case "french":
        return TranslateLanguage.french;
      case "spanish":
        return TranslateLanguage.spanish;
      case "korean":
        return TranslateLanguage.korean;
      case "italian":
        return TranslateLanguage.italian;
      case "vietnamese":
        return TranslateLanguage.vietnamese;
      default:
        return TranslateLanguage.german;
    }
  }

  @override
  void dispose() {
    super.dispose();
    translator.close();
    player.dispose();
  }

  Future<void> _fetchTask() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("levels")
          .doc("level_${widget.levelNumber}")
          .collection("tasks")
          .doc("task_1")
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          String fetchedWord = data["word"] ?? "";
          List<dynamic> fetchedOptions = data["options"] ?? [];

          String translatedWord = await translator.translateText(request);

          List<Map<String, dynamic>> translatedOptions = fetchedOptions.map((
            option,
          ) {
            return {
              "text": option["text"],
              "image": option["image"],
              "isCorrect": option["isCorrect"],
            };
          }).toList();

          setState(() {
            request = translatedWord;
            word = fetchedWord;
            options = translatedOptions;
          });
        }
      }
    } catch (e) {
      throw ("Error fetching task: $e");
    }
  }

  void _speak(String text) async {
    // final targetLang = translator.targetLanguage;

    String ttsLang = "en";

    await flutterTts.setLanguage(ttsLang);
    await flutterTts.speak(text);
  }

  void handleSelection(String text) {
    setState(() {
      selectedOption = text;
    });
  }

  void _checkAnswer() {
    final option = options.firstWhere(
      (option) => option["text"] == selectedOption,
      orElse: () => {},
    );

    final bool isCorrect = option["isCorrect"] == true;
    _playFeedback(isCorrect);
  }

  void _playFeedback(bool isCorrect) {
    final soundAsset = isCorrect
        ? "assets/sound/success.mp3"
        : "assets/sound/fail.mp3";

    player.setAsset(soundAsset).then((_) => player.play());

    final animation = isCorrect ? "success" : "failure";

    _showResultBottomSheet(animation, isCorrect);
  }

  void _showResultBottomSheet(String animationType, bool isCorrect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          maxChildSize: 0.6,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadiusGeometry.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    animationType == "success"
                        ? "assets/animation/correct.json"
                        : "assets/animation/fail.json",
                    height: 200,
                  ),
                  const SizedBox(height: 20),
                  if (isCorrect)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ScreenTwo(levelNumber: widget.levelNumber),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: greenPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "CONTINUE",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
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
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: options.isEmpty
              ? Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.black87,
                              size: 28,
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(30),
                              ),
                              child: const LinearProgressIndicator(
                                value: 0.3,
                                backgroundColor: Colors.blueGrey,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  greenPrimary,
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => {_speak(word)},
                            icon: const Icon(
                              Icons.volume_up,
                              color: greenPrimary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              word,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      request,
                      style: TextStyle(fontSize: 20, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GridView.builder(
                          itemCount: options.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemBuilder: (context, index) {
                            final option = options[index];
                            final isSelected = option["text"] == selectedOption;
                            return GestureDetector(
                              onTap: () => handleSelection(option["text"]),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? greenPrimary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? greenPrimary
                                        : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: option["image"],
                                      placeholder: (_, __) =>
                                          const CircularProgressIndicator(),
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.error),
                                      height: 80,
                                      width: 80,
                                      fit: BoxFit.cover,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      option["text"],
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,

                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: selectedOption.isEmpty
                              ? null
                              : _checkAnswer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: greenPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "CHECK",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
