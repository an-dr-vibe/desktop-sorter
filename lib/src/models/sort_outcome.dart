enum SortOutcomeType {
  moved,
  trashed,
  kept,
  skipped,
  failed,
}

class SortOutcome {
  SortOutcome({
    required this.type,
    required this.file,
    required this.message,
  });

  final SortOutcomeType type;
  final String file;
  final String message;
}