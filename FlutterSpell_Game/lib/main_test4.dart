import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MinimalProvider extends ChangeNotifier {}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MinimalProvider(),
      child: MaterialApp(
        title: 'Test',
        home: Scaffold(
          appBar: AppBar(title: const Text('Test App')),
          body: const Center(child: Text('Hello World')),
        ),
      ),
    );
  }
}
