import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:geolocator/geolocator.dart';

import '../data/bus_station.dart';
import '../utils/route_engine.dart';

class MapBottomPanel extends StatefulWidget {
  final RouteAnalysisResult? analysis;
  final List<BusStation> stations;

  const MapBottomPanel({
    super.key,
    required this.analysis,
    required this.stations,
  });

  @override
  State<MapBottomPanel> createState() => MapBottomPanelState();
}

class MapBottomPanelState extends State<MapBottomPanel> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _nowCardKey = GlobalKey();

  bool _isAutoTracking = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.isScrollingNotifier.value) {
        if (_scrollController.position.userScrollDirection !=
            ScrollDirection.idle) {
          if (_isAutoTracking) {
            setState(() => _isAutoTracking = false);
          }
        }
      }
    });
  }

  @override
  void didUpdateWidget(MapBottomPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isAutoTracking && widget.analysis != oldWidget.analysis) {
      _internalScroll();
    }
  }

  void scrollToCurrent() {
    setState(() => _isAutoTracking = true);
    _internalScroll();
  }

  void _internalScroll() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _nowCardKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
      } else {
        int nextIdx = _getNextIdx();
        if (nextIdx != -1) {
          _scrollController.animateTo(
            nextIdx * 130.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  int _getNextIdx() {
    if (widget.analysis?.nextStation == null) return -1;
    return widget.stations.indexWhere(
          (s) => s.order == widget.analysis!.nextStation!.order,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stations.isEmpty) {
      return Container(
        height: 35,
        color: Colors.black.withOpacity(0.85),
        alignment: Alignment.center,
        child: const Text(
          "無站點資料",
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      );
    }

    int nextIdx = _getNextIdx();

    return Container(
      height: 35,
      color: Colors.black.withOpacity(0.85),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        cacheExtent: 5000,
        itemCount: (nextIdx != -1)
            ? widget.stations.length + 1
            : widget.stations.length,
        itemBuilder: (context, index) {
          if (nextIdx != -1 && index == nextIdx) {
            return Row(
              key: _nowCardKey,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNowCard(),
                if (nextIdx < widget.stations.length)
                  _buildDistanceLine(
                    widget.analysis?.distToNextStation?.toDouble() ?? 0,
                  ),
              ],
            );
          }

          int sIdx = (nextIdx != -1 && index > nextIdx) ? index - 1 : index;
          final station = widget.stations[sIdx];

          double? dist;
          if (nextIdx != -1 && index == nextIdx - 1) {
            dist = widget.analysis?.distToPrevStation?.toDouble();
          } else if (sIdx < widget.stations.length - 1) {
            dist = Geolocator.distanceBetween(
              station.position.latitude,
              station.position.longitude,
              widget.stations[sIdx + 1].position.latitude,
              widget.stations[sIdx + 1].position.longitude,
            );
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStationCard(station),
              if (dist != null) _buildDistanceLine(dist),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStationCard(BusStation station) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        "${station.order}. ${station.name}",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildNowCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blueAccent, width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.directions_bus, color: Colors.amberAccent, size: 14),
          SizedBox(width: 3),
          Text(
            "現在位置",
            style: TextStyle(
              color: Colors.amberAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceLine(double dist) {
    return SizedBox(
      width: 50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "${dist.toStringAsFixed(0)}m",
            style: const TextStyle(color: Colors.white, fontSize: 9),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: Colors.white38,
          ),
        ],
      ),
    );
  }
}
