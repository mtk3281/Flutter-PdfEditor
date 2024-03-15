import 'package:flutter/material.dart';

class RoundButtonWidget extends StatelessWidget {
  final VoidCallback onClicked;

  const RoundButtonWidget({
    required this.onClicked,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 48,
      right: 30,
      child: FloatingActionButton(
        onPressed: onClicked,
        child: Icon(Icons.file_open_outlined),
        backgroundColor: Color.fromARGB(255, 67, 138, 192),
        shape: CircleBorder(),
      ),
    );
  }
}
