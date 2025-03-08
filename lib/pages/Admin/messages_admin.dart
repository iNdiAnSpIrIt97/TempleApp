import 'package:flutter/material.dart';

class MessagesAdmin extends StatelessWidget {
  const MessagesAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Customer Messages")),
      body: Center(
        child: const Text("Message Management Page",
            style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
