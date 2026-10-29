import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../models/family_member.dart';
import '../../models/safe_zone.dart';
import '../../providers/family_provider.dart';
import '../../providers/presence_provider.dart';
import '../../providers/zone_provider.dart';

/// OpenStreetMap-backed live map. Shows each family member at their last
/// known position with a labelled pin + accuracy halo, plus every safe
/// zone as a tinted circle.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(familyMembersProvider).valueOrNull ?? const [];
    final presence =
        ref.watch(familyPresenceProvider).valueOrNull ?? const {};
    final zones = ref.watch(zonesProvider).valueOrNull ?? const [];

    // One pin per member that has reported presence.
    final markers = <Marker>[];
    final accuracyCircles = <CircleMarker>[];
    for (final m in members) {
      final loc = presence[m.id];
      if (loc == null) continue;
      final point = ll.LatLng(loc.position.lat, loc.position.lng);
      markers.add(
        Marker(
          point: point,
          width: 140,
          height: 72,
          alignment: Alignment.topCenter,
          child: _MemberPin(member: m, location: loc),
        ),
      );
      accuracyCircles.add(
        CircleMarker(
          point: point,
          radius: loc.accuracyMeters.clamp(5, 500),
          useRadiusInMeter: true,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          borderColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.4),
          borderStrokeWidth: 1,
        ),
      );
    }

    final zoneCircles = <CircleMarker>[];
    for (final z in zones) {
      if (!z.active) continue;
      zoneCircles.add(
        CircleMarker(
          point: ll.LatLng(z.center.lat, z.center.lng),
          radius: z.radiusMeters,
          useRadiusInMeter: true,
          color: Colors.green.withOpacity(0.1),
          borderColor: Colors.green.shade700,
          borderStrokeWidth: 2,
        ),
      );
    }

    final centre = markers.isNotEmpty
        ? markers.first.point
        : zoneCircles.isNotEmpty
            ? zoneCircles.first.point
            : const ll.LatLng(28.6139, 77.2090); // Delhi fallback

    return Scaffold(
      body: FlutterMap(
        options: MapOptions(
          initialCenter: centre,
          initialZoom: markers.isNotEmpty ? 15 : 11,
          minZoom: 3,
          maxZoom: 18,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.sylvie.sylvie',
          ),
          // Zones first so pins + accuracy circles render on top.
          CircleLayer(circles: [...zoneCircles, ...accuracyCircles]),
          MarkerLayer(markers: markers),
          if (markers.isEmpty)
            const Center(
              child: Card(
                margin: EdgeInsets.all(24),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Abhi tak kisi family member ki location nahi aayi.\n'
                    'Thoda rukh — pehli ping aane mein 10-20 sec lagte hain.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          _ZoneLegend(zones: zones),
        ],
      ),
    );
  }
}

class _MemberPin extends StatelessWidget {
  final FamilyMember member;
  final LastLocation location;
  const _MemberPin({required this.member, required this.location});

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().toUtc().difference(location.timestamp);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(blurRadius: 4, color: Colors.black26),
            ],
          ),
          child: Text(
            '${member.name} · ${_fmt(age)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 2),
        Icon(
          Icons.location_pin,
          color: Theme.of(context).colorScheme.primary,
          size: 36,
        ),
      ],
    );
  }

  static String _fmt(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return DateFormat('MMM d').format(DateTime.now().subtract(d));
  }
}

class _ZoneLegend extends StatelessWidget {
  final List<SafeZone> zones;
  const _ZoneLegend({required this.zones});

  @override
  Widget build(BuildContext context) {
    if (zones.isEmpty) return const SizedBox.shrink();
    return Positioned(
      bottom: 12,
      left: 12,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.3),
                  border: Border.all(color: Colors.green.shade700, width: 2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${zones.length} safe zone${zones.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
