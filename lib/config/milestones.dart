/// Win-streak milestones.
///
/// A milestone is reached when a player wins [at] games in a row. The tiers
/// mirror the values the game screen already uses for its streak badges,
/// dialog text and celebration audio.
///
/// NOTE: the game screen still holds its own hardcoded copies of these tiers
/// (badge emoji, win-dialog strings, audio mapping). That duplication is
/// deliberate and left alone — consolidating it would mean editing shipped
/// game logic. This list is additive and used only by the profile screen. If
/// the tiers ever change, both places must be updated.
library;

class Milestone {
  const Milestone({
    required this.id,
    required this.at,
    required this.icon,
    required this.title,
  });

  /// Stable identifier, safe to persist or key on.
  final String id;

  /// Consecutive wins required to reach this milestone.
  final int at;

  final String icon;
  final String title;
}

class Milestones {
  const Milestones._();

  /// Ordered highest-first so [highestFor] can return on the first match.
  static const all = <Milestone>[
    Milestone(
      id: 'world-champion',
      at: 20,
      icon: '🌍',
      title: 'World Champion',
    ),
    Milestone(id: 'unstoppable', at: 15, icon: '🚀', title: 'Unstoppable'),
    Milestone(id: 'flag-legend', at: 10, icon: '👑', title: 'Flag Legend'),
    Milestone(id: 'memory-master', at: 7, icon: '🧠', title: 'Memory Master'),
    Milestone(id: 'lightning-fast', at: 5, icon: '⚡', title: 'Lightning'),
    Milestone(id: 'on-fire', at: 3, icon: '🔥', title: 'Fire'),
  ];

  /// The highest milestone reached at [streak], or null when the first tier
  /// has not been hit yet.
  static Milestone? highestFor(int streak) {
    for (final milestone in all) {
      if (streak >= milestone.at) return milestone;
    }
    return null;
  }

  /// Wins needed for the very first milestone, used for the empty state.
  static int get firstTier => all.last.at;

  /// [streak] rounded DOWN to the milestone it reached, or 0 below the first
  /// tier. Naturally caps at the highest tier, so 23 and 55 both give 20.
  ///
  /// Every streak figure shown on the profile is passed through this, so the
  /// player only ever sees defined milestones (3, 5, 7, 10, 15, 20) and never
  /// a raw running total. The one exception is the progress bar, which must
  /// show the true count to move between milestones.
  static int snap(int streak) => highestFor(streak)?.at ?? 0;

  /// The next milestone strictly above [streak], or null once the highest tier
  /// has been reached.
  ///
  /// [all] is ordered highest-first, so the last entry still above [streak] is
  /// the nearest one — e.g. a streak of 10 (Flag Legend) returns Unstoppable
  /// at 15, not World Champion at 20.
  static Milestone? nextFor(int streak) {
    Milestone? next;
    for (final milestone in all) {
      if (milestone.at > streak) next = milestone;
    }
    return next;
  }
}
