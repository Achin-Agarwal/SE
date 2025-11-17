import 'package:app/providers/image.dart';
import 'package:app/providers/navigation_provider.dart';
import 'package:app/providers/set.dart';
import 'package:app/screens/login.dart';
import 'package:app/screens/organizer/cart.dart';
import 'package:app/screens/organizer/bookings.dart';
import 'package:app/screens/organizer/home.dart';
import 'package:app/screens/organizer/search_screen.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/providers/username.dart';

class Dashboard extends ConsumerStatefulWidget {
  const Dashboard({super.key});

  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard> {
  DateTime? lastPressed;

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

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navIndexProvider);
    final size = MediaQuery.of(context).size;
    final screens = [
      const Home(),
      const SearchScreen(),
      const Cart(),
      const Bookings(),
    ];

    // Extract first name safely
    final fullName = ref.watch(usernameProvider);
    final firstName = fullName.contains(' ')
        ? fullName.split(' ').first
        : fullName;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final currentIndex = ref.read(navIndexProvider);
        if (currentIndex != 0 && ref.read(setIndexProvider) == 0) {
          ref.read(navIndexProvider.notifier).state = 0;
          return;
        } else {
          final currentSet = ref.read(setIndexProvider);
          if (currentSet == 1) {
            ref.read(navIndexProvider.notifier).state = 1;
            ref.read(setIndexProvider.notifier).state = 0;
            return;
          } else if (currentSet > 1 && currentSet < 4) {
            ref.read(navIndexProvider.notifier).state = 2;
            ref.read(setIndexProvider.notifier).state = 0;
            return;
          } else if (currentSet >= 4) {
            ref.read(navIndexProvider.notifier).state = 3;
            ref.read(setIndexProvider.notifier).state = 0;
            return;
          }
        }
        final now = DateTime.now();
        if (lastPressed == null ||
            now.difference(lastPressed!) > const Duration(seconds: 2)) {
          lastPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit')),
          );
          return;
        }
        Navigator.of(context).maybePop();
      },
      child: Scaffold(
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
                    onTap: () {
                      final imageUrl = ref.read(imageProvider);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            backgroundColor: Colors.black,
                            body: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Center(
                                child: Hero(
                                  tag: "profileImageZoom",
                                  child: InteractiveViewer(
                                    panEnabled: true,
                                    minScale: 1,
                                    maxScale: 4,
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 120,
                                              ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: "profileImageZoom",
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.pink[50],
                        child: ClipOval(
                          child: Image.network(
                            ref.watch(imageProvider),
                            fit: BoxFit.cover,
                            width: 44,
                            height: 44,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                  ),
                  SizedBox(width: size.width * 0.05),
                  Expanded(
                    child: Text(
                      "Hello, $firstName",
                      style: TextStyle(
                        fontSize: size.width * 0.055,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.pink),
                    onPressed: () => _logout(context),
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
          ],
          onTap: (index) => ref.read(navIndexProvider.notifier).state = index,
        ),
      ),
    );
  }
}
