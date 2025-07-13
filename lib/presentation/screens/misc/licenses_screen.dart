import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/licenses_provider.dart';
import '../../../data/models/library_license.dart';

class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LicensesProvider(),
      child: const _LicensesView(),
    );
  }
}

class _LicensesView extends StatelessWidget {
  const _LicensesView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LicensesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Licenses'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: provider.isLoading,
            builder: (context, isLoading, child) {
              return IconButton(
                icon: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                onPressed: isLoading ? null : () => provider.loadLicenses(forceRefresh: true),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<String?>(
        valueListenable: provider.error,
        builder: (context, error, child) {
          if (error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(error, textAlign: TextAlign.center),
              ),
            );
          }

          return ValueListenableBuilder<List<LibraryLicense>>(
            valueListenable: provider.licenses,
            builder: (context, licenses, child) {
              if (licenses.isEmpty && provider.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (licenses.isEmpty) {
                return const Center(child: Text('No licenses found.'));
              }
              return ListView.builder(
                itemCount: licenses.length,
                itemBuilder: (context, index) {
                  final license = licenses[index];
                  return ListTile(
                    title: Text('${license.name} (${license.version})'),
                    subtitle: Text('License: ${license.license}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (license.url.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.code), // GitHub icon or similar
                            tooltip: 'Source Code',
                            onPressed: () => _launchURL(license.url),
                          ),
                        IconButton(
                          icon: const Icon(Icons.description_outlined),
                          tooltip: 'View License',
                          onPressed: () => _showLicenseDialog(context, provider, license),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Optionally, show a snackbar or dialog on failure
    }
  }

  void _showLicenseDialog(BuildContext context, LicensesProvider provider, LibraryLicense license) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(license.name),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<String>(
            future: provider.fetchLicenseText(license),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Failed to load license: ${snapshot.error}');
              }
              return SingleChildScrollView(
                child: Text(snapshot.data ?? 'No license text available.'),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
