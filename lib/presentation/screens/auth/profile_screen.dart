import 'package:flutter/material.dart';
import 'package:neomovies_mobile/presentation/providers/auth_provider.dart';
import 'package:neomovies_mobile/presentation/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import '../misc/licenses_screen.dart' as licenses;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          switch (authProvider.state) {
            case AuthState.initial:
            case AuthState.loading:
              return const Center(child: CircularProgressIndicator());
            case AuthState.unauthenticated:
              return _buildUnauthenticatedView(context);
            case AuthState.authenticated:
              return _buildAuthenticatedView(context, authProvider);
            case AuthState.error:
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${authProvider.error}'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => authProvider.checkAuthStatus(),
                      child: const Text('Try again'),
                    )
                  ],
                ),
              );
          }
        },
      ),
    );
  }

  Widget _buildUnauthenticatedView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Please log in to continue'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('Login or Register'),
          ),
          const SizedBox(height: 40),
          TextButton(
            onPressed: () => _showLicensesScreen(context),
            child: const Text('Libraries licenses'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedView(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.user!;
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              child: Text(initial, style: Theme.of(context).textTheme.headlineMedium),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(user.name, style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _showLicensesScreen(context),
            child: const Text('Libraries licenses'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              authProvider.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            child: const Text('Logout'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _showDeleteConfirmationDialog(context, authProvider),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete account'),
          content: const Text('Are you sure you want to delete your account? This action is irreversible.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                authProvider.deleteAccount();
              },
            ),
          ],
        );
      },
    );
  }

  void _showLicensesScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const licenses.LicensesScreen(),
      ),
    );
  }
}