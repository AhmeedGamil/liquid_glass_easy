import 'package:flutter/material.dart';

// =============================================================
// Aurora's catalogue. Invented records, invented artists — the seed on
// each one is what its artwork and its page's light are generated from,
// so changing a seed string changes the colour of a whole screen.
// =============================================================

class Track {
  const Track(this.title, this.length, {this.plays = ''});

  final String title;

  /// Displayed run time, `m:ss`.
  final String length;

  /// Play count, shown on an album's most-played rows.
  final String plays;
}

class Album {
  const Album({
    required this.title,
    required this.artist,
    required this.seed,
    required this.year,
    required this.blurb,
    required this.tracks,
  });

  final String title;
  final String artist;

  /// The one string that decides this record's colours everywhere.
  final String seed;

  final String year;
  final String blurb;
  final List<Track> tracks;

  String get runtime => '${tracks.length} tracks · ${tracks.length * 4} min';
}

const Album kSableHours = Album(
  title: 'Sable Hours',
  artist: 'Neya Kohl',
  seed: 'sable-hours',
  year: '2025',
  blurb: 'Recorded across four nights in a disused signal station, mostly in '
      'one take, mostly after midnight.',
  tracks: <Track>[
    Track('Low Tide Radio', '4:12', plays: '1.2M'),
    Track('Sable Hours', '3:48', plays: '980k'),
    Track('Harbour Lights', '5:02', plays: '744k'),
    Track('Nothing Moves Here', '3:21'),
    Track('Salt and Static', '6:15'),
    Track('Last Signal', '4:44'),
  ],
);

const Album kGlassHarbour = Album(
  title: 'Glass Harbour',
  artist: 'Ilsen Vey',
  seed: 'glass-harbour',
  year: '2024',
  blurb: 'Eight pieces for piano and tape hiss, written on a ferry that ran '
      'the same crossing twice a day.',
  tracks: <Track>[
    Track('Crossing I', '2:58', plays: '2.4M'),
    Track('Glass Harbour', '4:31', plays: '1.9M'),
    Track('Wake', '3:12'),
    Track('Crossing II', '5:40'),
    Track('Ferrymen', '4:03'),
  ],
);

const Album kLanternWeather = Album(
  title: 'Lantern Weather',
  artist: 'Marta Aune',
  seed: 'lantern-weather',
  year: '2025',
  blurb: 'Field recordings from a winter that never quite arrived.',
  tracks: <Track>[
    Track('Thaw', '3:33', plays: '640k'),
    Track('Lantern Weather', '4:55', plays: '520k'),
    Track('Ninety Kilometres', '3:07'),
    Track('Blue Hour', '6:22'),
  ],
);

const Album kNorthOfSignal = Album(
  title: 'North of Signal',
  artist: 'Håkon Rist',
  seed: 'north-of-signal',
  year: '2023',
  blurb: 'Modular synthesis, no overdubs, one microphone in the room.',
  tracks: <Track>[
    Track('Beacon', '5:18', plays: '3.1M'),
    Track('North of Signal', '4:02', plays: '2.2M'),
    Track('Drift Ice', '7:41'),
    Track('Return Path', '3:29'),
  ],
);

const Album kPaperCities = Album(
  title: 'Paper Cities',
  artist: 'Odile Renn',
  seed: 'paper-cities',
  year: '2026',
  blurb: 'A record about maps of places that were never built.',
  tracks: <Track>[
    Track('Grid', '3:44', plays: '410k'),
    Track('Paper Cities', '4:20', plays: '388k'),
    Track('Unbuilt', '5:11'),
    Track('Atlas, Folded', '4:37'),
  ],
);

const Album kSlowAurora = Album(
  title: 'Slow Aurora',
  artist: 'Kai Lindqvist',
  seed: 'slow-aurora',
  year: '2025',
  blurb: 'Six long pieces meant to be played at the volume of a room.',
  tracks: <Track>[
    Track('First Light', '8:02', plays: '1.6M'),
    Track('Slow Aurora', '6:14', plays: '1.1M'),
    Track('Green Line', '5:26'),
    Track('Descent', '9:03'),
  ],
);

const List<Album> kAlbums = <Album>[
  kSableHours,
  kGlassHarbour,
  kLanternWeather,
  kNorthOfSignal,
  kPaperCities,
  kSlowAurora,
];

/// The record the mini player and the player page are parked on.
const Album kNowPlaying = kSableHours;

class Mix {
  const Mix(this.title, this.subtitle, this.seed, this.icon);

  final String title;
  final String subtitle;
  final String seed;
  final IconData icon;
}

const List<Mix> kMixes = <Mix>[
  Mix('Night Drive', '42 tracks · 2 hr 10', 'mix-night',
      Icons.dark_mode_rounded),
  Mix('Deep Focus', '68 tracks · 3 hr 40', 'mix-focus',
      Icons.center_focus_weak_rounded),
  Mix('Warm Static', '31 tracks · 1 hr 55', 'mix-static',
      Icons.graphic_eq_rounded),
  Mix('First Light', '24 tracks · 1 hr 20', 'mix-first',
      Icons.wb_twilight_rounded),
];

class Genre {
  const Genre(this.name, this.seed, this.icon);

  final String name;
  final String seed;
  final IconData icon;
}

const List<Genre> kGenres = <Genre>[
  Genre('Ambient', 'g-ambient', Icons.blur_on_rounded),
  Genre('Modular', 'g-modular', Icons.tune_rounded),
  Genre('Piano', 'g-piano', Icons.piano_rounded),
  Genre('Field', 'g-field', Icons.terrain_rounded),
  Genre('Choral', 'g-choral', Icons.groups_rounded),
  Genre('Late Night', 'g-late', Icons.nights_stay_rounded),
];

/// Search suggestions — the chips under an empty field.
const List<String> kSuggestions = <String>[
  'Neya Kohl',
  'Ambient piano',
  'Slow Aurora',
  'Tape hiss',
  'Ilsen Vey',
  'Night drive',
];
