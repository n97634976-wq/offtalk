import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/sos_manager.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentPosition;
  final MapController _mapController = MapController();
  final List<Marker> _peerMarkers = [];

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _cachedTileCount = 0;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _checkCachedTiles();
    _listenForSOS();
  }

  void _listenForSOS() {
    SOSManager.instance.onSosReceived = (peerId, lat, lng) {
      if (mounted) {
        setState(() {
          _peerMarkers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 50,
              height: 50,
              child: const Icon(Icons.warning, color: Colors.red, size: 40),
            ),
          );
        });

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("🚨 SOS Alert!"),
            content: Text("$peerId triggered an SOS at ($lat, $lng)"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    };
  }

  Future<void> _checkCachedTiles() async {
    try {
      final store = const FMTCStore('mapStore');
      final stats = await store.stats.all;
      setState(() {
        _cachedTileCount = stats.tileCount;
      });
    } catch (_) {}
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _mapController.move(_currentPosition!, 15.0);
    });
  }

  /// Download map tiles for offline use around the current position
  Future<void> _downloadTilesForOffline() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location not available. Please wait...")),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final store = const FMTCStore('mapStore');

      // Download tiles in a 10 km radius around current position (zoom 5-16)
      final region = CircleRegion(
        _currentPosition!,
        10, // 10 km radius
      );

      final downloadable = region.toDownloadable(
        minZoom: 5,
        maxZoom: 16,
        options: TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.offtalk.app',
        ),
      );

      int totalTiles = 0;
      int downloadedTiles = 0;

      await for (final progress in store.download.startForeground(
        region: downloadable,
      )) {
        if (!mounted) break;
        totalTiles = progress.maxTiles;
        downloadedTiles = progress.attemptedTiles;
        setState(() {
          _downloadProgress = totalTiles > 0 ? downloadedTiles / totalTiles : 0;
        });
      }

      await _checkCachedTiles();

      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ Downloaded $downloadedTiles tiles for offline use!",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Download failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OffTalk Map & SOS'),
        actions: [
          // Cached tile count indicator
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: _cachedTileCount > 0
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _cachedTileCount > 0
                        ? Icons.cloud_done
                        : Icons.cloud_download,
                    size: 14,
                    color: _cachedTileCount > 0 ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_cachedTileCount tiles',
                    style: TextStyle(
                      fontSize: 11,
                      color: _cachedTileCount > 0 ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_currentPosition != null) {
                _mapController.move(_currentPosition!, 15.0);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(20.0, 78.0),
              initialZoom: 5.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.offtalk.app',
                tileProvider: const FMTCStore('mapStore').getTileProvider(),
              ),
              MarkerLayer(
                markers: [
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.person_pin_circle,
                          color: Colors.blue, size: 40),
                    ),
                  ..._peerMarkers,
                ],
              ),
            ],
          ),

          // Download progress overlay
          if (_isDownloading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.black87,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Downloading tiles for offline... ${(_downloadProgress * 100).toInt()}%",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFF00A884)),
                    ),
                  ],
                ),
              ),
            ),

          // Download button
          Positioned(
            bottom: 90,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'download_map',
              onPressed: _isDownloading ? null : _downloadTilesForOffline,
              backgroundColor: _isDownloading
                  ? Colors.grey
                  : const Color(0xFF00A884),
              icon: Icon(
                _isDownloading ? Icons.hourglass_top : Icons.download,
                color: Colors.white,
              ),
              label: Text(
                _isDownloading ? "Downloading..." : "Download Map",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),

          // SOS Button
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 8,
                ),
                onPressed: () async {
                  if (_currentPosition != null) {
                    await SOSManager.instance.triggerSOS(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("OffTalk SOS Broadcast Sent!"),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Location not available yet")),
                    );
                  }
                },
                icon: const Icon(Icons.emergency),
                label: const Text("TRIGGER SOS",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
