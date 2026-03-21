import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/screens/auth/login_screen.dart';
import 'package:renobasic/screens/auth/homeowner_register_screen.dart';
import 'package:renobasic/screens/auth/contractor_register_screen.dart';
import 'package:renobasic/screens/auth/reset_password_screen.dart';
import 'package:renobasic/screens/auth/verify_email_screen.dart';
import 'package:renobasic/screens/homeowner/homeowner_dashboard_screen.dart';
import 'package:renobasic/screens/contractor/contractor_dashboard_screen.dart';
import 'package:renobasic/screens/homeowner/post_project_screen.dart';
import 'package:renobasic/screens/contractor/marketplace_screen.dart';
import 'package:renobasic/screens/contractor/buy_credits_screen.dart';
import 'package:renobasic/screens/profile/settings_screen.dart';
import 'package:renobasic/screens/contractor/project_detail_screen.dart';
import 'package:renobasic/screens/contractor/submit_bid_screen.dart';
import 'package:renobasic/screens/contractor/contractor_messages_screen.dart';
import 'package:renobasic/screens/homeowner/homeowner_messages_screen.dart';
import 'package:renobasic/screens/shared/chat_screen.dart';
import 'package:renobasic/screens/contractor/contractor_bids_screen.dart';
import 'package:renobasic/screens/homeowner/homeowner_bids_screen.dart';
import 'package:renobasic/screens/homeowner/homeowner_projects_screen.dart';
import 'package:renobasic/screens/shared/notifications_screen.dart';
import 'package:renobasic/screens/contractor/contractor_reviews_screen.dart';
import 'package:renobasic/screens/homeowner/homeowner_project_detail_screen.dart';
import 'package:renobasic/screens/contractor/contractor_analytics_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const RenoBasicsApp());
}

class RenoBasicsApp extends StatelessWidget {
  const RenoBasicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'RenoBasics',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF97316),
            primary: const Color(0xFFF97316),
          ),
          scaffoldBackgroundColor: Colors.grey[50],
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0.5,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        home: const AuthGate(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/project-detail':
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (_) => ContractorProjectDetailScreen(projectId: args['projectId']),
              );
            case '/submit-bid':
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (_) => SubmitBidScreen(
                  projectId: args['projectId'],
                  project: args['project'],
                  privateDetails: args['privateDetails'],
                ),
              );
            case '/chat':
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (_) => ChatScreen(
                  conversationId: args['conversationId'],
                  otherName: args['otherName'],
                  projectCategory: args['projectCategory'],
                  recipientUid: args['recipientUid'] as String? ?? '',
                ),
              );
            case '/homeowner-project-detail':
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (_) => HomeownerProjectDetailScreen(
                    projectId: args['projectId']),
              );
            default:
              return null;
          }
        },
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register-homeowner': (context) => const HomeownerRegisterScreen(),
          '/register-contractor': (context) => const ContractorRegisterScreen(),
          '/reset-password': (context) => const ResetPasswordScreen(),
          '/verify-email': (context) => const VerifyEmailScreen(),
          '/homeowner-dashboard': (context) => const HomeownerDashboardScreen(),
          '/contractor-dashboard': (context) => const ContractorDashboardScreen(),
          '/post-project': (context) => const PostProjectScreen(),
          '/marketplace': (context) => const MarketplaceScreen(),
          '/buy-credits': (context) => const BuyCreditsScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/contractor-messages': (context) => const ContractorMessagesScreen(),
          '/homeowner-messages': (context) => const HomeownerMessagesScreen(),
          '/contractor-bids': (context) => const ContractorBidsScreen(),
          '/homeowner-bids': (context) => const HomeownerBidsScreen(),
          '/homeowner-projects': (context) => const HomeownerProjectsScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/contractor-reviews': (context) => const ContractorReviewsScreen(),
          '/contractor-analytics': (context) => const ContractorAnalyticsScreen(),
        },
      ),
    );
  }
}

/// AuthGate: Routes user to the correct screen based on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFF97316)),
              SizedBox(height: 16),
              Text('Loading...', style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (!authProvider.isLoggedIn) {
      return const LoginScreen();
    }

    final user = authProvider.userProfile!;

    // Enforce email verification for non-admin users on app restart
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null && !firebaseUser.emailVerified && !user.isAdmin) {
      return const VerifyEmailScreen();
    }

    if (user.isContractor) {
      return const ContractorDashboardScreen();
    }
    return const HomeownerDashboardScreen();
  }
}
