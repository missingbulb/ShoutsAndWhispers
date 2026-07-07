import 'package:flutter/material.dart';

/// Full-screen setup instructions shown when Firebase isn't configured yet.
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shouts & Whispers — setup required',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.build_circle_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Setup required',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  SelectableText(message, textAlign: TextAlign.left),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
