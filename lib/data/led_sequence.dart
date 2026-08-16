enum LedEntryShort {
  bottomLeft,
  bottomCenter,
  topLeft,
  topCenter,
  rightLeft,
  rightCenter,
  asLongSetting,
}

enum LedEntryLong {
  bottomLeftScroll,
  topLeftScroll,
  rightLeftScroll,
  rightScrollIn,
}

class LedSequence {
  String template;
  LedEntryShort entryShort;
  LedEntryLong entryLong;
  double scrollSpeed;
  int stayMs;
  double entrySpeed;
  int color;
  bool forceLongEntry;

  LedSequence({
    required this.template,
    this.entryShort = LedEntryShort.bottomLeft,
    this.entryLong = LedEntryLong.rightScrollIn,
    this.scrollSpeed = -1,
    this.stayMs = 800,
    this.entrySpeed = 500,
    this.color = -1,
    this.forceLongEntry = false,
  });

  Map<String, dynamic> toJson() => {
    'template': template,
    'entryShort': entryShort.name,
    'entryLong': entryLong.name,
    'scrollSpeed': scrollSpeed,
    'stayMs': stayMs,
    'entrySpeed': entrySpeed,
    'color': color,
    'forceLongEntry': forceLongEntry,
  };

  factory LedSequence.fromJson(Map<String, dynamic> json) => LedSequence(
    template: json['template'] ?? "",
    entryShort: LedEntryShort.values.firstWhere(
      (e) => e.name == json['entryShort'],
      orElse: () => LedEntryShort.bottomLeft,
    ),
    entryLong: LedEntryLong.values.firstWhere(
      (e) => e.name == json['entryLong'],
      orElse: () => LedEntryLong.rightScrollIn,
    ),
    scrollSpeed: (json['scrollSpeed'] as num).toDouble(),
    stayMs: json['stayMs'] as int,
    entrySpeed: (json['entrySpeed'] as num).toDouble(),
    color: json['color'] is int ? json['color'] : -1,
    forceLongEntry: json['forceLongEntry'] ?? false,
  );
}
