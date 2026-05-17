import 'package:bus_pids_simulator/data/contact_item.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: List.generate(ContactItem.contactItems.length, (
                      index,
                    ) {
                      final item = ContactItem.contactItems[index];
                      return Column(
                        children: [
                          ListTile(
                            dense: true,
                            leading: FaIcon(
                              item.icon,
                              size: 24,
                              color: theme.colorScheme.primary,
                            ),
                            title: Text(
                              item.title,
                              style: theme.textTheme.titleMedium,
                            ),
                            trailing: OutlinedButton(
                              onPressed: () => _launchUrl(item.url),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              child: const Text("前往"),
                            ),
                            onTap: () => _launchUrl(item.url),
                          ),
                          if (index < ContactItem.contactItems.length - 1)
                            const Divider(indent: 20, endIndent: 20, height: 1),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  "Version 1.0.0 | © TYBusStation",
                  style: TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
