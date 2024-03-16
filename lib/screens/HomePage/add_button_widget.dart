import 'package:flutter/material.dart';

class RoundButtonWidget extends StatelessWidget {
  final VoidCallback onClicked;

  const RoundButtonWidget({super.key, 
    required this.onClicked,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 48,
      right: 30,
      child: FloatingActionButton(
        onPressed: onClicked,
        backgroundColor: const Color.fromARGB(255, 67, 138, 192),
        shape: const CircleBorder(),
        child: const Icon(Icons.file_open_outlined),
      ),
    );
  }
}
