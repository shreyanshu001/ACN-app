import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'inventory_screen.dart';
import 'requirements_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ACN Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => InventoryScreen())),
              child: Text('Share Inventory'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => RequirementsScreen())),
              child: Text('Post Requirements'),
            ),
            ElevatedButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
