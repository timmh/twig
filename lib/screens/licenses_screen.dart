import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  String? _licenseText;

  @override
  void initState() {
    super.initState();
    _loadLicenseText();
  }

  Future<void> _loadLicenseText() async {
    try {
      final licenseText = await rootBundle.loadString('LICENSE');
      setState(() {
        _licenseText = licenseText;
      });
    } catch (e) {
      // If we can't load the license file, use a fallback
      setState(() {
        _licenseText = 'Apache License 2.0 - See LICENSE file in project root';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Licenses'),
        backgroundColor: const Color(0xFF549342),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Twig Application License
          _buildLicenseCard(
            title: 'Twig Application',
            description: 'Flutter-based bird classification app',
            license: 'Apache License 2.0',
            onTap: () => _showLicenseDialog(context, 'Twig Application License', _licenseText ?? 'License text not available'),
          ),

          const SizedBox(height: 16),

          // Perch Model License
          _buildLicenseCard(
            title: 'Google Research Perch Model',
            description: 'Bioacoustic classification model for bird species identification',
            license: 'Apache License 2.0',
            url: 'https://github.com/google-research/perch',
            onTap: () => _showLicenseDialog(
              context,
              'Google Research Perch Model License',
              '${_licenseText ?? 'License text not available'}\n\nCopyright 2024 Google Research\n\nModel and training code available at:\nhttps://github.com/google-research/perch',
            ),
          ),

          const SizedBox(height: 16),

          // eBird Taxonomy
          _buildLicenseCard(
            title: 'eBird Taxonomy',
            description: 'Bird species classification codes and taxonomic data',
            license: 'eBird Terms of Use',
            url: 'https://ebird.org/science/use-ebird-data/terms-of-use',
            onTap: () => _showLicenseDialog(
              context,
              'eBird Terms of Use',
              'eBird taxonomy and species classification data used in this application.\n\n'
              'Data provided by eBird (www.ebird.org), a project of the Cornell Lab of Ornithology.\n\n'
              'Use of eBird data is subject to the eBird Terms of Use:\n'
              'https://ebird.org/science/use-ebird-data/terms-of-use\n\n'
            ),
          ),

          const SizedBox(height: 16),

          // Enhanced Species Labels
          _buildLicenseCard(
            title: 'Species Names & Classification',
            description: 'Common and scientific names for bird species identification',
            license: 'Compiled from Public Domain Sources',
            url: 'https://www.catalogueoflife.org/about/colusage',
            onTap: () => _showLicenseDialog(
              context,
              'Species Names & Classification',
              'Species common names and scientific names compiled from various taxonomic sources including the Catalogue of Life:\n'
              'Bánki, O., Roskov, Y., Döring, M., Ower, G., Hernández Robles, D. R., et al. (2025). '
              'Catalogue of Life (Version 2025-09-11). Catalogue of Life Foundation, Amsterdam, Netherlands.\n\n'
            ),
          ),

          const SizedBox(height: 16),

          // Flutter Dependencies
          _buildLicenseCard(
            title: 'Flutter Dependencies',
            description: 'Third-party packages used in this application',
            license: 'Various Open Source Licenses',
            onTap: () => _showFlutterLicenses(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseCard({
    required String title,
    required String description,
    required String license,
    String? url,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF549342).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  license,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF549342),
                  ),
                ),
              ),
              if (url != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _launchUrl(url),
                  child: Text(
                    url,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showLicenseDialog(BuildContext context, String title, String licenseText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: SingleChildScrollView(
            child: Text(
              licenseText,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFlutterLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'Twig',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.pets,
        size: 48,
        color: Color(0xFF549342),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}