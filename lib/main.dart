import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/screens/auth/login_screen.dart';
import 'package:renobasic/screens/auth/homeowner_register_screen.dart';
import 'package:renobasic/screens/auth/contractor_register_screen.dart';
import 'package:renobasic/screens/auth/reset_password_screen.dart';
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
                ),
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
    if (user.isContractor) {
      return const ContractorDashboardScreen();
    }
    return const HomeownerDashboardScreen();
  }
}
