import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:neomovies_mobile/data/api/api_client.dart';
import 'package:neomovies_mobile/data/api/authenticated_http_client.dart';
import 'package:neomovies_mobile/data/models/movie.dart';
import 'package:neomovies_mobile/data/models/movie_preview.dart';
import 'package:neomovies_mobile/data/repositories/auth_repository.dart';
import 'package:neomovies_mobile/data/repositories/favorites_repository.dart';
import 'package:neomovies_mobile/data/repositories/movie_repository.dart';
import 'package:neomovies_mobile/data/repositories/reactions_repository.dart';
import 'package:neomovies_mobile/data/services/secure_storage_service.dart';
import 'package:neomovies_mobile/presentation/providers/auth_provider.dart';
import 'package:neomovies_mobile/presentation/providers/favorites_provider.dart';
import 'package:neomovies_mobile/presentation/providers/home_provider.dart';
import 'package:neomovies_mobile/presentation/providers/movie_detail_provider.dart';
import 'package:neomovies_mobile/presentation/providers/reactions_provider.dart';
import 'package:neomovies_mobile/presentation/screens/main_screen.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  // Ensure widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Hive for local caching
  await Hive.initFlutter();

  // Register Adapters
  Hive.registerAdapter(MovieAdapter());
  Hive.registerAdapter(MoviePreviewAdapter());

  runApp(
    MultiProvider(
      providers: [
        // Core Services & Clients
        Provider<FlutterSecureStorage>(create: (_) => const FlutterSecureStorage()),
        Provider<SecureStorageService>(
          create: (context) => SecureStorageService(context.read<FlutterSecureStorage>()),
        ),
        Provider<http.Client>(create: (_) => http.Client()),
        Provider<AuthenticatedHttpClient>(
          create: (context) => AuthenticatedHttpClient(
            context.read<SecureStorageService>(),
            context.read<http.Client>(),
          ),
        ),
        Provider<ApiClient>(
          create: (context) => ApiClient(context.read<AuthenticatedHttpClient>()),
        ),

        // Repositories
        Provider<MovieRepository>(
          create: (context) => MovieRepository(apiClient: context.read<ApiClient>()),
        ),
        Provider<AuthRepository>(
          create: (context) => AuthRepository(
            apiClient: context.read<ApiClient>(),
            storageService: context.read<SecureStorageService>(),
          ),
        ),
        Provider<FavoritesRepository>(
          create: (context) => FavoritesRepository(context.read<ApiClient>()),
        ),
        Provider<ReactionsRepository>(
          create: (context) => ReactionsRepository(context.read<ApiClient>()),
        ),

        // State Notifiers (Providers)
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(authRepository: context.read<AuthRepository>()),
        ),
        ChangeNotifierProvider<HomeProvider>(
          create: (context) => HomeProvider(movieRepository: context.read<MovieRepository>())..init(),
        ),
        ChangeNotifierProvider<MovieDetailProvider>(
          create: (context) => MovieDetailProvider(
            context.read<MovieRepository>(),
            context.read<ApiClient>(),
          ),
        ),
        ChangeNotifierProvider<ReactionsProvider>(
            create: (context) => ReactionsProvider(
                  context.read<ReactionsRepository>(),
                  context.read<AuthProvider>(),
                )),
        ChangeNotifierProxyProvider<AuthProvider, FavoritesProvider>(
          create: (context) => FavoritesProvider(
            context.read<FavoritesRepository>(),
            context.read<AuthProvider>(),
          ),
          update: (context, auth, previous) => previous!..update(auth),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final _defaultLightColorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
  static final _defaultDarkColorScheme = ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark);

  @override
  Widget build(BuildContext context) {
    // Use dynamic_color to get colors from the system
    return DynamicColorBuilder(
      builder: (lightColorScheme, darkColorScheme) {
        return MaterialApp(
          title: 'NeoMovies',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: lightColorScheme ?? _defaultLightColorScheme,
            useMaterial3: true,
            textTheme: GoogleFonts.manropeTextTheme(
              ThemeData(brightness: Brightness.light).textTheme,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme ?? _defaultDarkColorScheme,
            useMaterial3: true,
            textTheme: GoogleFonts.manropeTextTheme(
              ThemeData(brightness: Brightness.dark).textTheme,
            ),
          ),
          themeMode: ThemeMode.system,
          home: const MainScreen(),
        );
      },
    );
  }
}
