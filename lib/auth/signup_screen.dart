import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import './signin_screen.dart';
import '../screens/level_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<SignUpScreen> {
  static const Color greenPrimary = Color(0xFF4CAF50);

  final _fromKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String _errorMessage = '';

  Future<void> _signUp() async {
    if (!_fromKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      final uid = credential.user!.uid;
      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "email": _emailController.text.trim(),
        "xp": 0,
        "streak": 0,
        "language": "German",
        "lastActive": FieldValue.serverTimestamp(),
      });

      final levelSnapshot = await FirebaseFirestore.instance
          .collection("levels")
          .get();
      for (final doc in levelSnapshot.docs) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("levels")
            .doc(doc.id)
            .set({
              "isUnlocked": doc["levelNumber"] == 1,
              "levelNumber": doc["levelNumber"],
              "title": doc["title"],
            });
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LevelScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "An error occurred";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Đăng ký/Đăng nhập bằng Google
  Future<void> _signUpWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = '';
    });

    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut(); // <- Xóa phiên Google hiện tại
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        setState(() {
          _isGoogleLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final uid = userCredential.user!.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection("users").doc(uid).set({
          "email": userCredential.user!.email,
          "displayName": userCredential.user!.displayName,
          "photoURL": userCredential.user!.photoURL,
          "xp": 0,
          "streak": 0,
          "language": "Vietnamese",
          "lastActive": FieldValue.serverTimestamp(),
        });

        final levelSnapshot = await FirebaseFirestore.instance
            .collection("levels")
            .get();
        for (final doc in levelSnapshot.docs) {
          await FirebaseFirestore.instance
              .collection("users")
              .doc(uid)
              .collection("levels")
              .doc(doc.id)
              .set({
                "isUnlocked": doc["levelNumber"] == 1,
                "levelNumber": doc["levelNumber"],
                "title": doc["title"],
              });
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LevelScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Google sign up failed";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "An error occurred during Google sign up";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundGradient = LinearGradient(
      colors: [Color(0xFFE8F5E9), Colors.white],
    );
    const greyBorder = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: backgroundGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _fromKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: greenPrimary,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      cursorColor: Colors.grey,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        labelText: "Email",
                        border: greyBorder,
                        enabledBorder: greyBorder,
                        focusedBorder: greyBorder,
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (v) => v == null || !v.contains("@")
                          ? "Enter a valid email"
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Password field
                    TextFormField(
                      cursorColor: Colors.grey,
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        labelText: "Password",
                        border: greyBorder,
                        enabledBorder: greyBorder,
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (v) => v == null || v.length < 6
                          ? "Password must be at least 6 characters"
                          : null,
                    ),

                    const SizedBox(height: 20),

                    // Error message
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Sign Up button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: greenPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        onPressed: _isLoading ? null : _signUp,
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "SIGN UP",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Divider
                    Row(
                      children: const [
                        Expanded(child: Divider(thickness: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "OR",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(thickness: 1)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Google Sign Up button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isGoogleLoading ? null : _signUpWithGoogle,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Colors.grey),
                        ),
                        icon: _isGoogleLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Image.network(
                                'https://www.google.com/images/branding/googleg/1x/googleg_standard_color_128dp.png',
                                height: 24,
                              ),
                        label: const Text(
                          "Sign up with Google",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Sign In link
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignInScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Already have an account? Sign In",
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
