import 'dart:convert';

import 'package:http/http.dart' as http;

/// Suggestion returned from a place search.
class PlaceSuggestion {
  final String displayName;
  final double lat;
  final double lng;

  const PlaceSuggestion({
    required this.displayName,
    required this.lat,
    required this.lng,
  });
}

/// Free place-name → coordinates lookup via OpenStreetMap's Nominatim
/// service. No API key required. We respect the service's identification
/// policy by sending a descriptive User-Agent.
///
/// Nominatim asks consumers to cap use at ~1 req/sec — the search field
/// debounces at 400 ms so UX stays within that budget naturally.
class GeocodingService {
  static const _endpoint = 'https://nominatim.openstreetmap.org/search';
  static const _userAgent = 'Sylvie/0.1 (com.sylvie.sylvie)';

  final http.Client _client;
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<PlaceSuggestion>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];

    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'q': q,
      'format': 'json',
      'limit': '7',
      'countrycodes': 'in', // bias toward India for the family use case
      'addressdetails': '0',
    });

    try {
      final resp = await _client.get(uri, headers: {'User-Agent': _userAgent});
      if (resp.statusCode != 200) return const [];
      final body = jsonDecode(resp.body) as List;
      return body
          .map((e) => PlaceSuggestion(
                displayName: (e as Map)['display_name'] as String,
                lat: double.parse(e['lat'] as String),
                lng: double.parse(e['lon'] as String),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
