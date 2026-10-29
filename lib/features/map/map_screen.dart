import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../models/family_member.dart';
import '../../providers/family_provider.dart';
import '../../providers/presence_provider.dart';

/// OpenStreetMap-backed live map. Shows each family member at their last
/// known position with a labelled pin + how long ago that fix was reported.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(familyMembersProvider).valueOrNull ?? const [];
    final presence =
        ref.watch(familyPresenceProvider).valueOrNull ?? const {};

    // Build marker list from members + their presence doc.
    final markers = <Marker>[];
    for (final m in members) {
      final loc = presence[m.id];
      if (loc == null) continue;
      markers.add(
        Marker(
          point: ll.LatLng(loc.position.lat, loc.position.lng),
          width: 120,
          height: 70,
          alignment: Alignment.topCenter,
          child: _MemberPin(member: m, location: loc),
        ),
      );
    }

    // Centre the camera on the first available member (admin usually), else
    // on Delhi so the map isn't an empty gray square the first time.
    final centre = markers.isNotEmpty
        ? markers.first.point
        : const ll.LatLng(28.6139, 77.2090);

    return Scaffold(
      body: FlutterMap(
        options: MapOptions(
          initialCenter: centre,
          initialZoom: markers.isNotEmpty ? 14 : 11,
          minZoom: 3,
          maxZoom: 18,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.sylvie.sylvie',
          ),
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
