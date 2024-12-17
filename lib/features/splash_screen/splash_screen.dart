import 'package:another_flutter_splash_screen/another_flutter_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:locallists/features/lists/homepage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: FlutterSplashScreen.scale(
      useImmersiveMode: true,
      gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode(context)
              ? [Colors.black, Colors.black]
              : [Colors.white, Colors.white]),
      childWidget: SizedBox(
        height: 200,
        width: 200,
        child: isDarkMode(context)
            ? Image.asset("assets/splashscreen/iconDark.png",
                width: 200, height: 200)
            : Image.asset("assets/splashscreen/icon.png",
                width: 200, height: 200),
      ),
      duration: const Duration(milliseconds: 2000),
      animationDuration: const Duration(milliseconds: 1500),
      onAnimationEnd: () => debugPrint("On Scale End"),
      nextScreen: const Homepage(),
    ));
  }
}
