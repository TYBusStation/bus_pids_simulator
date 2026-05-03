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

  // 元件內部的追蹤旗標
  bool _isAutoTracking = true;

  @override
  void initState() {
    super.initState();
    // 監聽滾動，若使用者手動操作則停止自動追蹤
    _scrollController.addListener(() {
      if (_scrollController.position.isScrollingNotifier.value) {
        // 判斷是否為使用者手動觸發 (drag)
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
    // 如果處於自動追蹤模式，且分析數據有更新，則自動滾動
    if (_isAutoTracking && widget.analysis != oldWidget.analysis) {
      _internalScroll();
    }
  }

  // 外部調用（地圖按鈕觸發）
  void scrollToCurrent() {
    setState(() => _isAutoTracking = true); // 點擊按鈕恢復自動追蹤
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
        // 若 context 不在畫面上，執行預估滾動
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
      height: 35, // 壓縮高度
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
          // 當前位置卡片
          if (nextIdx != -1 && index == nextIdx) {
            return Row(
              key: _nowCardKey,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNowCard(),
                // 與下一站的線段
                if (nextIdx < widget.stations.length)
                  _buildDistanceLine(
                    widget.analysis?.distToNextStation?.toDouble() ?? 0,
                  ),
              ],
            );
          }

          // 處理站點索引：在 Now 之後的站點 index 要減 1
          int sIdx = (nextIdx != -1 && index > nextIdx) ? index - 1 : index;
          final station = widget.stations[sIdx];

          // 距離邏輯
          double? dist;
          if (nextIdx != -1 && index == nextIdx - 1) {
            // 上一站 -> 現在位置 的距離
            dist = widget.analysis?.distToPrevStation?.toDouble();
          } else if (sIdx < widget.stations.length - 1) {
            // 一般站間距離
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
            style: const TextStyle(color: Colors.white, fontSize: 9), // 全改為白色
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: Colors.white38, // 全改為白色
          ),
        ],
      ),
    );
  }
}
