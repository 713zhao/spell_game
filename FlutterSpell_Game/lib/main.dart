import 'package:flutter/material.dart';

void main() {
  runApp(const SpellGameApp());
}

class SpellGameApp extends StatelessWidget {
  const SpellGameApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spell Academy',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SpellGameHome(),
    );
  }
}

class SpellGameHome extends StatefulWidget {
  const SpellGameHome({Key? key}) : super(key: key);

  @override
  State<SpellGameHome> createState() => _SpellGameHomeState();
}

class _SpellGameHomeState extends State<SpellGameHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spell Academy'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text('Game UI coming soon...'),
      ),
    );
  }
}
