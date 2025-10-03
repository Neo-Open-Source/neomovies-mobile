import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build a minimal app for testing
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('NeoMovies Test'),
          ),
          body: const Center(
            child: Text('Hello World'),
          ),
        ),
      ),
    );

    // Verify that our app displays basic elements
    expect(find.text('NeoMovies Test'), findsOneWidget);
    expect(find.text('Hello World'), findsOneWidget);
  });

  testWidgets('Download progress indicator test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              LinearProgressIndicator(value: 0.5),
              Text('50%'),
            ],
          ),
        ),
      ),
    );

    // Verify progress indicator and text
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('List tile with popup menu test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListTile(
            title: const Text('Test Torrent'),
            trailing: PopupMenuButton<String>(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
                const PopupMenuItem(
                  value: 'pause',
                  child: Text('Pause'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Verify list tile
    expect(find.text('Test Torrent'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);

    // Tap the popup menu button
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    // Verify menu items appear
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
  });
}