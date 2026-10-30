import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../core/preset_zones.dart';
import '../../data/geocoding_service.dart';
import '../../models/family_member.dart' as mm;
import '../../models/safe_zone.dart';
import '../../providers/family_provider.dart';
import '../../providers/zone_provider.dart';

/// Admin creates a safe zone. Pick a location one of four ways —
/// current GPS fix, a built-in preset (AIIMS Delhi), a free-text place
/// search powered by OpenStreetMap Nominatim, or a direct tap on the
/// map — then dial in a radius anywhere from 50 m up to 50 km using
/// either the preset chips, the slider, or a direct meters input.
class CreateZoneScreen extends ConsumerStatefulWidget {
  const CreateZoneScreen({super.key});

  @override
  ConsumerState<CreateZoneScreen> createState() => _CreateZoneScreenState();
}

class _CreateZoneScreenState extends ConsumerState<CreateZoneScreen> {
  static const _minRadius = 50.0;
  static const _maxRadius = 500000.0; // 500 km upper bound
  static const _radiusPresets = <double>[
    100,
    500,
    1000,
    5000,
    10000,
    50000,
    100000,
    250000,
    500000,
  ];

  final _nameController = TextEditingController(text: 'Ghar');
  final _searchController = TextEditingController();
  final _radiusController = TextEditingController(text: '100');
  Timer? _searchDebounce;

  ll.LatLng? _center;
  double _radius = 100;
  final Set<String> _appliesTo = {};
  bool _saving = false;
  String? _error;

  final MapController _mapController = MapController();
  final GeocodingService _geocoder = GeocodingService();
  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _radiusController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _searching = true);
      final results = await _geocoder.search(q);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  void _usePlace(PlaceSuggestion p) {
    final latLng = ll.LatLng(p.lat, p.lng);
    setState(() {
      _center = latLng;
      _suggestions = const [];
      _searchController.text = _shortName(p.displayName);
      _nameController.text = _firstSegment(p.displayName);
    });
    _mapController.move(latLng, 15);
  }

  Future<void> _useCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latLng = ll.LatLng(pos.latitude, pos.longitude);
      setState(() {
        _center = latLng;
        _searchController.clear();
        _suggestions = const [];
      });
      _mapController.move(latLng, 16);
    } catch (e) {
      setState(() => _error = 'Location nahi mili: $e');
    }
  }

  void _usePreset(PresetZone p) {
    final latLng = ll.LatLng(p.center.lat, p.center.lng);
    setState(() {
      _nameController.text = p.displayName;
      _center = latLng;
      _searchController.clear();
      _suggestions = const [];
      _setRadius(p.suggestedRadiusMeters);
    });
    _mapController.move(latLng, 15);
  }

  void _setRadius(double v) {
    final clamped = v.clamp(_minRadius, _maxRadius);
    setState(() {
      _radius = clamped;
      _radiusController.text = clamped.toStringAsFixed(0);
    });
  }

  void _onRadiusTextChanged(String s) {
    final parsed = double.tryParse(s);
    if (parsed == null) return;
    final clamped = parsed.clamp(_minRadius, _maxRadius);
    setState(() => _radius = clamped);
  }

  Future<void> _save() async {
    if (_center == null) {
      setState(() => _error = 'Pehle location pick kar');
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Zone ka naam daal');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final familyId = ref.read(activeGroupIdProvider);
      if (familyId == null) throw StateError('No active group');

      final zone = SafeZone(
        id: '',
        name: _nameController.text.trim(),
        center: mm.LatLng(_center!.latitude, _center!.longitude),
        radiusMeters: _radius,
        appliesTo: _appliesTo.toList(),
        createdAt: DateTime.now().toUtc(),
      );

      await ref.read(zoneRepositoryProvider).addZone(
            familyId: familyId,
            zone: zone,
          );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(familyMembersProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Create safe zone')),
      body: Column(
        children: [
          _buildSearchBar(context),
          SizedBox(
            height: 260,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        _center ?? const ll.LatLng(28.6139, 77.2090),
                    initialZoom: 12,
                    onTap: (_, p) => setState(() => _center = p),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.sylvie.sylvie',
                    ),
                    if (_center != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _center!,
                            radius: _radius,
                            useRadiusInMeter: true,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2),
                            borderColor: Theme.of(context).colorScheme.primary,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    if (_center != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _center!,
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.location_pin,
                              color: Theme.of(context).colorScheme.primary,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withOpacity(0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _center == null
                          ? 'Tap on map to pick a point'
                          : _radiusLabel(_radius),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.my_location, size: 18),
                      label: const Text('Current location'),
                      onPressed: _useCurrentLocation,
                    ),
                    for (final p in presetZones)
                      ActionChip(
                        avatar: const Icon(Icons.place, size: 18),
                        label: Text(p.displayName),
                        onPressed: () => _usePreset(p),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Zone ka naam',
                    hintText: 'Ghar, AIIMS, School, Dadi ka Dehradun ghar …',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                _buildRadiusInput(),
                const SizedBox(height: 20),
                const Text(
                  'Kis member ke liye?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Kuch bhi select nahi karoge toh zone sabke liye hoga.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ...members.map((m) => CheckboxListTile(
                      title: Text(m.name),
                      subtitle: Text(_relationLabel(m.relation)),
                      value: _appliesTo.contains(m.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _appliesTo.add(m.id);
                        } else {
                          _appliesTo.remove(m.id);
                        }
                      }),
                    )),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save zone'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _suggestions = const []);
                          },
                        ),
              hintText: 'Search place (e.g. Dehradun railway station)',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (_suggestions.isNotEmpty)
            Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (_, i) {
                    final s = _suggestions[i];
                    return ListTile(
                      leading: const Icon(Icons.place_outlined, size: 20),
                      title: Text(
                        _shortName(s.displayName),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      onTap: () => _usePlace(s),
                      dense: true,
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRadiusInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Radius: ${_radiusLabel(_radius)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _radiusController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  suffixText: 'm',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                onChanged: _onRadiusTextChanged,
                onSubmitted: (s) {
                  final parsed = double.tryParse(s);
                  if (parsed != null) _setRadius(parsed);
                },
              ),
            ),
          ],
        ),
        Slider(
          value: _radius.clamp(_minRadius, _maxRadius),
          min: _minRadius,
          max: _maxRadius,
          onChanged: _setRadius,
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final r in _radiusPresets)
              ActionChip(
                label: Text(_radiusLabel(r)),
                visualDensity: VisualDensity.compact,
                onPressed: () => _setRadius(r),
              ),
          ],
        ),
      ],
    );
  }

  static String _radiusLabel(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(meters % 1000 == 0 ? 0 : 1)} km';
  }

  static String _shortName(String displayName) {
    // Nominatim's display_name is a long comma-separated address. Keep
    // the first 2-3 segments so the UI stays compact.
    final parts = displayName.split(',').map((s) => s.trim()).toList();
    if (parts.length <= 3) return parts.join(', ');
    return parts.take(3).join(', ');
  }

  static String _firstSegment(String displayName) {
    final parts = displayName.split(',');
    return parts.isEmpty ? displayName : parts.first.trim();
  }

  static String _relationLabel(mm.Relation r) {
    switch (r) {
      case mm.Relation.self:
        return 'Self';
      case mm.Relation.mother:
        return 'Mummy';
      case mm.Relation.father:
        return 'Papa';
      case mm.Relation.sister:
        return 'Didi';
      case mm.Relation.brother:
        return 'Bhai';
      case mm.Relation.grandmother:
        return 'Dadi';
      case mm.Relation.grandfather:
        return 'Dada';
      case mm.Relation.other:
        return 'Other';
    }
  }
}
