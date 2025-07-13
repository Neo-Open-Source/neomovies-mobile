import 'package:flutter/material.dart';
import 'package:neomovies_mobile/presentation/providers/auth_provider.dart';
import 'package:neomovies_mobile/presentation/screens/auth/profile_screen.dart';
import 'package:neomovies_mobile/presentation/screens/favorites/favorites_screen.dart';
import 'package:neomovies_mobile/presentation/screens/search/search_screen.dart';
import 'package:neomovies_mobile/presentation/screens/home/home_screen.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Check auth status when the main screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).checkAuthStatus();
    });
  }

  // Pages for each tab
  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    SearchScreen(),
    FavoritesScreen(),
    Center(child: Text('Downloads Page')),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: colorScheme.surfaceContainerHighest,
          indicatorColor: colorScheme.surfaceContainerHighest.withOpacity(0.6),
          iconTheme: MaterialStateProperty.resolveWith<IconThemeData>((states) {
            if (states.contains(MaterialState.selected)) {
              return IconThemeData(color: colorScheme.onSurface);
            }
            return IconThemeData(color: colorScheme.onSurfaceVariant);
          }),
          labelTextStyle: MaterialStateProperty.resolveWith<TextStyle>((states) {
            if (states.contains(MaterialState.selected)) {
              return TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              );
            }
            return TextStyle(
              color: colorScheme.onSurfaceVariant,
            );
          }),
        ),
        child: NavigationBar(
          onDestinationSelected: _onItemTapped,
          selectedIndex: _selectedIndex,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.search),
              selectedIcon: Icon(Icons.search),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'Favorites',
            ),
            NavigationDestination(
              icon: Icon(Icons.download_outlined),
              selectedIcon: Icon(Icons.download),
              label: 'Downloads',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_2_outlined),
              selectedIcon: Icon(Icons.person_2),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
