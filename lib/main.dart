import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/requirements_screen.dart';
import 'screens/requirement_form_screen.dart';
import 'screens/requirement_matching.dart';
import 'screens/requirement_detail_screen.dart';
import 'screens/conversation_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/superadmin_login_screen.dart'; // Add this import
import 'services/auth_service.dart';
import 'services/loading_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    print("Environment variables loaded successfully");
  } catch (e) {
    print("Warning: Failed to load .env file: $e");
    // Continue execution, your code has fallbacks
  }

  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AuthService _authService = AuthService();

  // In MyApp build method
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => _authService,
        ),
        StreamProvider(
          create: (_) => _authService.authStateChanges,
          initialData: null,
        ),
        ChangeNotifierProvider(
          create: (_) => LoadingService(),
        ),
      ],
      child: MaterialApp(  // Removed ErrorBoundary wrapper
        title: 'ACN',
        theme: ThemeData(
          primarySwatch: Colors.green,
          primaryColor: Color(0xFF0D4C3A),
          appBarTheme: AppBarTheme(
            backgroundColor: Color(0xFF0D4C3A),
            foregroundColor: Colors.white,
          ),
        ),
        home: AuthWrapper(),  // Keep this
        onGenerateRoute: (settings) {
          if (settings.name == '/requirement_detail') {
            return MaterialPageRoute(
              builder: (context) => RequirementDetailScreen(
                requirementId: settings.arguments as String,
              ),
            );
          }
          if (settings.name == '/conversation') {
            return MaterialPageRoute(
              builder: (context) => ConversationScreen(),
            );
          }
          return null;
        },
        routes: {
          // Remove the '/' route since you're using home
          '/login': (context) => LoginScreen(),
          '/admin_dashboard': (context) => AdminDashboardScreen(),
          '/superadmin_login': (context) => SuperAdminLoginScreen(), // Add this if you create a dedicated screen
          '/edit_requirement': (context) => RequirementFormScreen(isEditing: true),
          '/profile': (context) => ProfileScreen(),
          '/requirements': (context) => RequirementsScreen(),
          '/requirement_form': (context) => RequirementFormScreen(),
          '/requirement_matching': (context) => RequirementMatchingScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);

    if (user == null) {
      return LoginScreen();
    }

    // Check if user is admin and redirect accordingly
    return FutureBuilder<bool>(
      future: Provider.of<AuthService>(context, listen: false).isUserAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // If user is superadmin (based on email), redirect to admin dashboard
        if (snapshot.data == true) {
          return AdminDashboardScreen();
        }
        
        // Regular users go to home screen
        return HomeScreen();
      },
    );
  }
}
