import 'package:flutter/material.dart';
import 'package:mon_coloc/screens/auth/register_page.dart';
import 'package:mon_coloc/services/firebase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initialiserFirebase();
  runApp(const MonColocApp());
}

class MonColocApp extends StatelessWidget {
  const MonColocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mon Coloc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E6B4E),
        brightness: Brightness.light,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _inscriptionTerminee = false;

  @override
  Widget build(BuildContext context) {
    if (_inscriptionTerminee) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mon Coloc'),
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 80, color: Colors.green),
              SizedBox(height: 24),
              Text(
                'Inscription réussie !',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Bienvenue dans la communauté Mon Coloc.',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RegisterPage(
      onInscriptionTerminee: () {
        setState(() => _inscriptionTerminee = true);
      },
    );
  }
}