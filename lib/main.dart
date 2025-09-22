import 'package:flutter/material.dart';
import 'screens/bird_classification_screen.dart';

void main() {
  runApp(const TwigApp());
}

class TwigApp extends StatelessWidget {
  const TwigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twig',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const BirdClassificationScreen(),
    );
  }
}
