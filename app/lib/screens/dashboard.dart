import 'package:app/providers/image.dart';
import 'package:app/providers/navigation_provider.dart';
import 'package:app/screens/login.dart';
import 'package:app/screens/organizer/cart.dart';
import 'package:app/screens/organizer/bookings.dart';
import 'package:app/screens/organizer/home.dart';
import 'package:app/screens/organizer/profile.dart';
import 'package:app/screens/organizer/search_screen.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/providers/username.dart';

class Dashboard extends ConsumerWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navIndexProvider);
    final size = MediaQuery.of(context).size;

    final screens = [
      const Home(),
      const SearchScreen(),
      const Cart(),
      const Bookings(),
      // const Profile(),
    ];

    String imageUrl = ref.watch(imageProvider);

    @override
    Future<void> _logout(BuildContext context) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Logged out successfully")));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: size.height * 0.01,
              horizontal: size.width * 0.04,
            ),
            margin: EdgeInsets.only(bottom: size.height * 0.01),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _logout(context),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.pink[50],
                    child: ClipOval(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: 44,
                        height: 44,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.person,
                              color: Colors.black54,
                              size: 28,
                            ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: size.width * 0.05),
                Text(
                  "Hello, ${ref.watch(usernameProvider)}",
                  style: TextStyle(
                    fontSize: size.width * 0.055,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: screens[currentIndex]),
        ],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: currentIndex,
        height: size.height * 0.06,
        color: Colors.white,
        buttonBackgroundColor: Colors.white,
        backgroundColor: Colors.white,
        animationDuration: const Duration(milliseconds: 300),
        items: <Widget>[
          Icon(Icons.home, size: size.height * 0.04, color: Colors.pink),
          Icon(Icons.search, size: size.height * 0.04, color: Colors.pink),
          Icon(
            Icons.shopping_cart,
            size: size.height * 0.04,
            color: Colors.pink,
          ),
          Icon(Icons.book, size: size.height * 0.04, color: Colors.pink),
          // Icon(Icons.person, size: size.height * 0.04, color: Colors.pink),
        ],
        onTap: (index) => ref.read(navIndexProvider.notifier).state = index,
      ),
    );
  }
}
