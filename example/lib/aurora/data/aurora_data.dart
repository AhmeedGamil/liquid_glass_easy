import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Everything the app pretends to know about its user.
///
/// One file, all literals: a demo whose numbers drift on every hot reload
/// is impossible to design against, and a screenshot of it is a lie. The
/// two generated series below are pure functions of their index for the
/// same reason.

// ── Today ─────────────────────────────────────────────────────────

/// Minutes spent breathing today, and the goal that closes the ring.
const double kBreatheMinutes = 14;
const double kBreatheGoal = 20;

/// Hours slept last night, against the target.
const double kSleepHours = 7.2;
const double kSleepGoal = 8;

/// Mindful movement, in minutes.
const double kMoveMinutes = 42;
const double kMoveGoal = 45;

/// The headline number: a 0–100 blend of the three rings.
const double kCalmScore = 78;

/// Yesterday's, so the delta has something to point at.
const double kCalmScoreYesterday = 71;

const int kStreakDays = 12;
const double kRestingHeartRate = 58;

/// The greeting line, keyed to the hour the demo pretends it is.
const String kUserName = 'Sam';
const String kTodayLabel = 'WEDNESDAY · AUGUST 12';

// ── Series ────────────────────────────────────────────────────────

/// Calm score over the last two weeks. Hand-written: it has to *look*
/// like a life — a dip mid-week, a recovery, one bad night.
const List<double> kCalmSeries = [
  62,
  65,
  61,
  70,
  74,
  69,
  58,
  64,
  72,
  77,
  75,
  68,
  74,
  78,
];

/// Resting heart rate over the same window, in bpm.
const List<double> kHeartSeries = [
  63,
  62,
  64,
  61,
  60,
  61,
  65,
  63,
  60,
  59,
  58,
  60,
  59,
  58,
];

/// Mindful minutes per weekday, this week.
const List<double> kWeekMinutes = [22, 35, 18, 41, 27, 52, 34];
const List<String> kWeekLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// The daily target drawn across the bars.
const double kWeekTarget = 30;

/// Where this week's minutes actually went.
const List<({String label, double value})> kBreakdown = [
  (label: 'Breathwork', value: 96),
  (label: 'Sleep stories', value: 74),
  (label: 'Focus', value: 43),
  (label: 'Walks', value: 16),
];

/// Sleep depth, 7 nights × 24 hours, row-major and 0..1.
///
/// A closed form rather than a table: deep in the small hours, a dip
/// around 3am on the two nights that were bad, nothing during the day.
final List<double> kSleepHeat = List<double>.generate(7 * 24, (i) {
  final day = i ~/ 24;
  final hour = i % 24;
  // Distance from 3am, wrapped, so the night reads as one block.
  final fromNight = math.min((hour - 3).abs(), 24 - (hour - 3).abs());
  final depth = math.max(0.0, 1 - fromNight / 5.2);
  // Two restless nights, so the grid isn't a wallpaper pattern.
  final penalty = (day == 2 || day == 5) ? 0.45 : 1.0;
  final wobble = 0.9 + 0.1 * math.sin(day * 2.3 + hour * 0.7);
  return (depth * penalty * wobble).clamp(0.0, 1.0);
});

// ── Sessions ──────────────────────────────────────────────────────

enum SessionKind { breathe, sleep, focus }

extension SessionKindLabel on SessionKind {
  String get label => switch (this) {
        SessionKind.breathe => 'Breathe',
        SessionKind.sleep => 'Sleep',
        SessionKind.focus => 'Focus',
      };

  IconData get icon => switch (this) {
        SessionKind.breathe => Icons.air_rounded,
        SessionKind.sleep => Icons.bedtime_rounded,
        SessionKind.focus => Icons.center_focus_strong_rounded,
      };
}

@immutable
class AuroraSession {
  final String title;
  final String subtitle;
  final SessionKind kind;
  final int minutes;

  /// Which `palette.series` slot paints this session — the color follows
  /// the session, not the theme, so it survives an accent change.
  final int slot;

  /// The breathing pattern, in seconds: inhale, hold, exhale, rest.
  final List<int> pattern;

  const AuroraSession({
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.minutes,
    required this.slot,
    this.pattern = const [4, 2, 6, 0],
  });
}

const List<AuroraSession> kSessions = [
  AuroraSession(
    title: 'Box breathing',
    subtitle: 'Steady the nerves before something hard',
    kind: SessionKind.breathe,
    minutes: 3,
    slot: 0,
    pattern: [4, 4, 4, 4],
  ),
  AuroraSession(
    title: 'Long exhale',
    subtitle: 'The one that actually slows a racing heart',
    kind: SessionKind.breathe,
    minutes: 5,
    slot: 1,
    pattern: [4, 0, 8, 0],
  ),
  AuroraSession(
    title: 'Rain on a tin roof',
    subtitle: 'Sleep story · 42 min',
    kind: SessionKind.sleep,
    minutes: 42,
    slot: 3,
    pattern: [5, 0, 7, 0],
  ),
  AuroraSession(
    title: 'Deep work drone',
    subtitle: 'Low, wide, and free of melody',
    kind: SessionKind.focus,
    minutes: 25,
    slot: 2,
    pattern: [4, 2, 6, 0],
  ),
  AuroraSession(
    title: 'Wind down',
    subtitle: 'Unclench the jaw, then the shoulders',
    kind: SessionKind.sleep,
    minutes: 12,
    slot: 3,
    pattern: [4, 2, 8, 2],
  ),
  AuroraSession(
    title: 'Morning light',
    subtitle: 'Wake the body without the jolt',
    kind: SessionKind.breathe,
    minutes: 6,
    slot: 0,
    pattern: [5, 1, 5, 1],
  ),
];

/// The one the home page pushes you toward.
final AuroraSession kFeaturedSession = kSessions[1];

// ── Coach ─────────────────────────────────────────────────────────

@immutable
class CoachMessage {
  final String text;
  final bool fromCoach;
  final String time;

  const CoachMessage(this.text, {required this.fromCoach, this.time = ''});
}

const List<CoachMessage> kCoachHistory = [
  CoachMessage(
    'Morning. You slept 7h 12m — about forty minutes short of your usual, '
    'and you woke twice around 3am.',
    fromCoach: true,
    time: '08:04',
  ),
  CoachMessage(
    "yeah, went to bed late again",
    fromCoach: false,
    time: '08:11',
  ),
  CoachMessage(
    'That tracks. Your calm score still climbed to 78, which is the highest '
    "it's been this month — the breathwork is doing more work than the "
    'sleep is.',
    fromCoach: true,
    time: '08:11',
  ),
];

/// Tappable openers under the thread.
const List<String> kQuickReplies = [
  'How did I sleep?',
  'I feel wired',
  'Plan my evening',
];

/// Canned answers, picked in order. A demo that says the same thing to
/// every message reads as broken within two taps.
const List<String> kCoachReplies = [
  'Two restless nights this week, both after 1am screens. Everything else '
      'held steady — your resting heart rate is down 5 bpm since the 1st.',
  "Wired usually means the exhale is too short. Try Long exhale for five "
      'minutes; it moves people out of that state faster than anything else '
      'in the library.',
  'Wind down at 21:30, lights low by 22:00, and Rain on a tin roof after '
      "that. You're 12 days into the streak — protect it.",
  "Noted. I'll check in tomorrow morning once the night's data lands.",
];
