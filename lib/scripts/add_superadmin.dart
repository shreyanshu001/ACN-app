import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../firebase_options.dart';

// This script allows adding a superadmin via CLI
Future<void> main() async {
  // Initialize Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Get email from command line arguments or prompt
  String? email;
  if (stdin.hasTerminal) {
    stdout.write('Enter email of the user to make superadmin: ');
    email = stdin.readLineSync()?.trim();
  } else {
    exit(1);
  }

  if (email == null || email.isEmpty) {
    exit(1);
  }

  try {
    // Query Firestore to find the user with the given email
    final QuerySnapshot userQuery = await FirebaseFirestore.instance
        .collection('agents')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {
      exit(1);
    }

    // Update the user document to set isSuperAdmin to true
    await FirebaseFirestore.instance
        .collection('agents')
        .doc(userQuery.docs.first.id)
        .update({
      'isSuperAdmin': true,
    });
  } catch (e) {
    exit(1);
  }

  exit(0);
}
