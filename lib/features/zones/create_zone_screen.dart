import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../core/preset_zones.dart';
import '../../models/family_member.dart' as mm;
import '../../models/safe_zone.dart';
import '../../providers/family_provider.dart';
import '../../providers/zone_provider.dart';

/// Admin creates a safe zone — pick a location (map tap, current location,
/// or preset like AIIMS Delhi), set a radius, choose who it applies to.
class CreateZoneScreen extends ConsumerStatefulWidget {
  const CreateZoneScreen({super.key});

  @override
  ConsumerState<CreateZoneScreen> createState() => _CreateZoneScreenState();
}

class _CreateZoneScreenState extends ConsumerState<CreateZoneScreen> {
  final _nameController = TextEditingController(text: 'Ghar');
  ll.LatLng? _center;
  double _radius = 100;
  final Set<String> _appliesTo = {}; // empty = all members
  bool _saving = false;
  String? _error;
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _center = ll.LatLng(pos.latitude, pos.longitude);
      });
      _mapController.move(_center!, 16);
    } catch (e) {
      setState(() => _error = 'Location nahi mili: $e');
    }
  }

  void _usePreset(PresetZone p) {
    setState(() {
      _nameController.text = p.displayName;
      _center = ll.LatLng(p.center.lat, p.center.lng);
      _radius = p.suggestedRadiusMeters;
    });
    _mapController.move(_center!, 15);
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
      final familyId = ref.read(currentFamilyIdProvider).valueOrNull;
      if (familyId == null) throw StateError('No family');

      final zone = SafeZone(
        id: '', // repository assigns
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
          SizedBox(
            height: 260,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter:
                    _center ?? const ll.LatLng(28.6139, 77.2090), // Delhi
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
                    hintText: 'Ghar, AIIMS, School …',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Radius: ${_radius.toStringAsFixed(0)} m'),
                Slider(
                  value: _radius,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  label: '${_radius.toStringAsFixed(0)} m',
                  onChanged: (v) => setState(() => _radius = v),
                ),
                const SizedBox(height: 16),
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
