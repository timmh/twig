import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ImageAttribution {
  final String source;
  final String? author;
  final String? license;
  final String? licenseUrl;
  final String? sourceUrl;

  ImageAttribution({
    required this.source,
    this.author,
    this.license,
    this.licenseUrl,
    this.sourceUrl,
  });
}

class ImageResult {
  final String? imageUrl;
  final ImageAttribution? attribution;

  ImageResult({
    this.imageUrl,
    this.attribution,
  });
}

class ImageService {
  static const String _unsplashAccessKey = 'demo'; // In production, use a real API key

  /// Get image URL for a species or sound type
  static Future<String?> getImageUrl(String speciesName, String? scientificName) async {
    final result = await getImageWithAttribution(speciesName, scientificName);
    return result.imageUrl;
  }

  /// Get image with attribution for a species or sound type
  static Future<ImageResult> getImageWithAttribution(String speciesName, String? scientificName) async {
    try {
      // For biological species with scientific names, try specialized sources
      if (scientificName != null && scientificName.isNotEmpty) {
        return await _getBiologicalSpeciesImage(speciesName, scientificName);
      } else {
        // For non-biological sounds, generate appropriate imagery
        return _getNonBiologicalImage(speciesName);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting image for $speciesName: $e');
      }
      return ImageResult();
    }
  }

  /// Get image for biological species (birds, insects, etc.)
  static Future<ImageResult> _getBiologicalSpeciesImage(String commonName, String scientificName) async {
    // Try multiple sources in order of preference

    // 1. Try Wikimedia Commons (most comprehensive, free)
    final wikiImage = await _getWikimediaImage(scientificName, commonName);
    if (wikiImage != null) return wikiImage;

    // 2. Try iNaturalist (good for many species)
    final iNatImage = await _getINaturalistImage(scientificName);
    if (iNatImage != null) return iNatImage;

    // 3. Try Unsplash as fallback (requires API key)
    final unsplashImage = await _getUnsplashImage(commonName);
    if (unsplashImage != null) return unsplashImage;

    // 4. Generate a placeholder
    return _generatePlaceholder(commonName, isSpecies: true);
  }

  /// Get image for non-biological sounds
  static ImageResult _getNonBiologicalImage(String soundType) {
    final cleanName = soundType.replaceAll('_', ' ').replaceAll('(', '').replaceAll(')', '');

    // Map common sound types to appropriate icons/colors
    final soundTypeIcons = {
      'keyboard': '🎹',
      'guitar': '🎸',
      'drum': '🥁',
      'piano': '🎹',
      'violin': '🎻',
      'trumpet': '🎺',
      'car': '🚗',
      'engine': '🚗',
      'water': '💧',
      'rain': '🌧️',
      'wind': '💨',
      'fire': '🔥',
      'door': '🚪',
      'bell': '🔔',
      'phone': '📞',
      'alarm': '⏰',
      'machinery': '⚙️',
      'tool': '🔧',
    };

    String icon = '🔊'; // Default sound icon
    String color = '2196F3'; // Default blue

    // Find matching icon
    for (final entry in soundTypeIcons.entries) {
      if (cleanName.toLowerCase().contains(entry.key)) {
        icon = entry.value;
        break;
      }
    }

    // Use different colors for different categories
    if (cleanName.toLowerCase().contains('music') ||
        cleanName.toLowerCase().contains('instrument')) {
      color = '9C27B0'; // Purple for music
    } else if (cleanName.toLowerCase().contains('vehicle') ||
               cleanName.toLowerCase().contains('car') ||
               cleanName.toLowerCase().contains('engine')) {
      color = 'FF5722'; // Red-orange for vehicles
    } else if (cleanName.toLowerCase().contains('nature') ||
               cleanName.toLowerCase().contains('water') ||
               cleanName.toLowerCase().contains('wind')) {
      color = '4CAF50'; // Green for nature
    }

    final encodedName = Uri.encodeComponent(cleanName);
    final encodedIcon = Uri.encodeComponent(icon);

    final imageUrl = 'https://via.placeholder.com/400x300/$color/FFFFFF?text=$encodedIcon%20$encodedName';

    return ImageResult(
      imageUrl: imageUrl,
      attribution: ImageAttribution(
        source: 'Placeholder.com',
        license: 'Public Domain',
        licenseUrl: 'https://placeholder.com',
      ),
    );
  }

  /// Try to get image from Wikimedia Commons
  static Future<ImageResult> _getWikimediaImage(String scientificName, String commonName) async {
    try {
      // First try to get a Wikipedia page for the species
      final wikipediaUrl = await _getWikipediaPageUrl(scientificName);
      if (wikipediaUrl != null) {
        // Extract images from the Wikipedia page
        final imageResult = await _getWikipediaPageImage(wikipediaUrl);
        if (imageResult.imageUrl != null) return imageResult;
      }

      // Fallback: Search Wikimedia Commons directly
      return await _searchWikimediaCommons(scientificName);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Wikimedia image: $e');
      }
      return ImageResult();
    }
  }

  /// Try to get image from iNaturalist
  static Future<ImageResult> _getINaturalistImage(String scientificName) async {
    try {
      // This would query iNaturalist API in production
      // For now, return empty result to fall back to other sources
      return ImageResult();
    } catch (e) {
      return ImageResult();
    }
  }

  /// Try to get image from Unsplash
  static Future<ImageResult> _getUnsplashImage(String searchTerm) async {
    try {
      // This would query Unsplash API with a real access key
      // For demo purposes, we'll skip this and fall back to placeholder
      return ImageResult();
    } catch (e) {
      return ImageResult();
    }
  }

  /// Generate a colored placeholder with species name
  static ImageResult _generatePlaceholder(String name, {bool isSpecies = false}) {
    final encodedName = Uri.encodeComponent(name);
    final color = isSpecies ? '4CAF50' : '2196F3'; // Green for species, blue for sounds
    final icon = isSpecies ? '🦅' : '🔊';
    final encodedIcon = Uri.encodeComponent(icon);

    final imageUrl = 'https://via.placeholder.com/400x300/$color/FFFFFF?text=$encodedIcon%20$encodedName';

    return ImageResult(
      imageUrl: imageUrl,
      attribution: ImageAttribution(
        source: 'Placeholder.com',
        license: 'Public Domain',
        licenseUrl: 'https://placeholder.com',
      ),
    );
  }

  /// Get Wikipedia page URL for a species
  static Future<String?> _getWikipediaPageUrl(String scientificName) async {
    try {
      final encodedName = Uri.encodeComponent(scientificName);
      final url = 'https://en.wikipedia.org/api/rest_v1/page/summary/$encodedName';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['type'] == 'standard' && data['content_urls'] != null) {
          return data['content_urls']['desktop']['page'];
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Wikipedia URL for $scientificName: $e');
      }
    }
    return null;
  }

  /// Get main image from Wikipedia page
  static Future<ImageResult> _getWikipediaPageImage(String pageUrl) async {
    try {
      // Extract page title from URL
      final uri = Uri.parse(pageUrl);
      final pageTitle = uri.pathSegments.last;

      // Get page info with main image
      final apiUrl = 'https://en.wikipedia.org/w/api.php?action=query&format=json&formatversion=2&prop=pageimages&piprop=original&titles=${Uri.encodeComponent(pageTitle)}';

      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pages = data['query']['pages'];
        if (pages != null && pages.isNotEmpty) {
          final page = pages[0];
          if (page['original'] != null) {
            return ImageResult(
              imageUrl: page['original']['source'],
              attribution: ImageAttribution(
                source: 'Wikipedia',
                license: 'CC BY-SA 3.0',
                licenseUrl: 'https://creativecommons.org/licenses/by-sa/3.0/',
                sourceUrl: pageUrl,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Wikipedia page image: $e');
      }
    }
    return ImageResult();
  }

  /// Search Wikimedia Commons for species images
  static Future<ImageResult> _searchWikimediaCommons(String scientificName) async {
    try {
      final encodedName = Uri.encodeComponent(scientificName);
      final searchUrl = 'https://commons.wikimedia.org/w/api.php?action=query&format=json&list=search&srsearch=$encodedName&srnamespace=6&srlimit=5';

      final response = await http.get(Uri.parse(searchUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final searchResults = data['query']['search'];

        if (searchResults != null && searchResults.isNotEmpty) {
          // Try to get the first suitable image
          for (final result in searchResults) {
            final title = result['title'];
            if (title != null && (title.toLowerCase().contains('.jpg') || title.toLowerCase().contains('.png'))) {
              final imageResult = await _getCommonsImageUrl(title);
              if (imageResult.imageUrl != null) return imageResult;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error searching Wikimedia Commons: $e');
      }
    }
    return ImageResult();
  }

  /// Get actual image URL from Commons file title
  static Future<ImageResult> _getCommonsImageUrl(String fileTitle) async {
    try {
      final encodedTitle = Uri.encodeComponent(fileTitle);
      final apiUrl = 'https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo&iiprop=url&titles=$encodedTitle';

      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pages = data['query']['pages'];

        if (pages != null) {
          for (final pageId in pages.keys) {
            final page = pages[pageId];
            if (page['imageinfo'] != null && page['imageinfo'].isNotEmpty) {
              return ImageResult(
                imageUrl: page['imageinfo'][0]['url'],
                attribution: ImageAttribution(
                  source: 'Wikimedia Commons',
                  license: 'CC BY-SA 4.0',
                  licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
                  sourceUrl: 'https://commons.wikimedia.org/wiki/$fileTitle',
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Commons image URL: $e');
      }
    }
    return ImageResult();
  }

  /// Get Wikipedia article first section text
  static Future<String?> getWikipediaText(String scientificName) async {
    try {
      final encodedName = Uri.encodeComponent(scientificName);
      final url = 'https://en.wikipedia.org/api/rest_v1/page/summary/$encodedName';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['type'] == 'standard' && data['extract'] != null) {
          return data['extract'];
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting Wikipedia text for $scientificName: $e');
      }
    }
    return null;
  }

  /// Check if a species name appears to be a bird
  static bool isLikelyBird(String? scientificName, String commonName) {
    if (scientificName == null || scientificName.isEmpty) return false;

    // Common bird genera
    final birdGenera = {
      'Turdus', 'Corvus', 'Parus', 'Falco', 'Buteo', 'Accipiter', 'Strix', 'Bubo',
      'Picus', 'Dendrocopos', 'Hirundo', 'Delichon', 'Anas', 'Ardea', 'Passer',
      'Fringilla', 'Carduelis', 'Erithacus', 'Phylloscopus', 'Sylvia', 'Motacilla',
      'Anthus', 'Lanius', 'Emberiza', 'Alauda', 'Garrulus', 'Pica', 'Sturnus',
      'Columba', 'Streptopelia', 'Cuculus', 'Upupa', 'Alcedo', 'Merops', 'Coracias',
      'Charadrius', 'Vanellus', 'Larus', 'Sterna', 'Circus', 'Milvus', 'Aquila',
      'Haliaeetus', 'Pandion', 'Otus', 'Asio', 'Tyto', 'Picidae', 'Alaudidae'
    };

    final genus = scientificName.split(' ').first;
    return birdGenera.contains(genus) ||
           commonName.toLowerCase().contains('bird') ||
           commonName.toLowerCase().contains('owl') ||
           commonName.toLowerCase().contains('eagle') ||
           commonName.toLowerCase().contains('hawk') ||
           commonName.toLowerCase().contains('dove') ||
           commonName.toLowerCase().contains('sparrow') ||
           commonName.toLowerCase().contains('finch') ||
           commonName.toLowerCase().contains('warbler') ||
           commonName.toLowerCase().contains('thrush') ||
           commonName.toLowerCase().contains('kingfisher') ||
           commonName.toLowerCase().contains('woodpecker') ||
           commonName.toLowerCase().contains('hummingbird');
  }

  /// Get appropriate emoji/icon for a species type
  static String getSpeciesIcon(String? scientificName, String commonName) {
    if (isLikelyBird(scientificName, commonName)) {
      return '🦅';
    } else if (scientificName != null && scientificName.isNotEmpty) {
      // Other biological species
      if (commonName.toLowerCase().contains('frog') ||
          commonName.toLowerCase().contains('toad')) {
        return '🐸';
      } else if (commonName.toLowerCase().contains('insect') ||
                 commonName.toLowerCase().contains('cricket') ||
                 commonName.toLowerCase().contains('cicada')) {
        return '🦗';
      } else if (commonName.toLowerCase().contains('mammal') ||
                 commonName.toLowerCase().contains('whale') ||
                 commonName.toLowerCase().contains('dolphin')) {
        return '🐋';
      } else {
        return '🦎'; // Generic animal
      }
    } else {
      return '🔊'; // Sound
    }
  }
}