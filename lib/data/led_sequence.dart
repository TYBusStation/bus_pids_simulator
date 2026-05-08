enum LedEntryShort {
  bottomLeft,
  bottomCenter,
  topLeft,
  topCenter,
  rightLeft,
  rightCenter,
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

  LedSequence({
    required this.template,
    this.entryShort = LedEntryShort.bottomLeft,
    this.entryLong = LedEntryLong.bottomLeftScroll,
    this.scrollSpeed = 400.0,
    this.stayMs = 800,
    this.entrySpeed = 500,
  });

  Map<String, dynamic> toJson() => {
    'template': template,
    'entryShort': entryShort.name,
    'entryLong': entryLong.name,
    'scrollSpeed': scrollSpeed,
    'stayMs': stayMs,
    'entrySpeed': entrySpeed,
  };

  factory LedSequence.fromJson(Map<String, dynamic> json) => LedSequence(
    template: json['template'],
    entryShort: LedEntryShort.values.firstWhere(
      (e) => e.name == json['entryShort'],
      orElse: () => LedEntryShort.bottomLeft,
    ),
    entryLong: LedEntryLong.values.firstWhere(
      (e) => e.name == json['entryLong'],
      orElse: () => LedEntryLong.bottomLeftScroll,
    ),
    scrollSpeed: (json['scrollSpeed'] as num).toDouble(),
    stayMs: json['stayMs'] as int,
    entrySpeed: (json['entrySpeed'] as num).toDouble(),
  );
}
