import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);
      
      // Check if the user is a superadmin (Briqko)
      bool isSuperAdmin = userCredential.user!.email == 'briqko@gmail.com';
      
      // Create/Update user document in Firestore
      await _firestore
          .collection('agents')
          .doc(userCredential.user!.uid)
          .set({
        'email': userCredential.user!.email,
        'name': userCredential.user!.displayName,
        'photoURL': userCredential.user!.photoURL,
        'verified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'isSuperAdmin': isSuperAdmin,
      }, SetOptions(merge: true));
      
      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Check if user is admin
  Future<bool> isUserAdmin() async {
    if (currentUser == null) return false;
    
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('agents')
          .doc(currentUser!.uid)
          .get();
      
      return userDoc.exists && (userDoc.data() as Map<String, dynamic>)['isSuperAdmin'] == true;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }
}