import 'package:flutter/material.dart';

class MemoryScreen extends StatelessWidget {
  const MemoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Trips'),
      ),
      body: ListView(
        children: const [
          // TODO: Render saved trips from local DB
        ],
      ),
    );
  }
}
