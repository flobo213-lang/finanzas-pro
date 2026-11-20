import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MaterialApp(home: TestScreen()));
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String status = "Conectando a Firestore...";

  @override
  void initState() {
    super.initState();
    _testFirestore();
  }

  Future<void> _testFirestore() async {
    try {
      final testRef =
          FirebaseFirestore.instance.collection('_test').doc('check');

      // Escribir la tasa con 4 decimales
      await testRef.set({
        'tasa_prueba': 916.6477,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Leer de vuelta
      final snapshot = await testRef.get();
      final data = snapshot.data();

      setState(() {
        status = "✅ Conectado.\nTasa guardada: ${data?['tasa_prueba']}";
      });
    } catch (e) {
      setState(() {
        status = "❌ Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Test Firestore Dev")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}
