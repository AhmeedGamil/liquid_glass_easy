import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../common.dart';
import '../data.dart';
import '../theme.dart';
import 'settings_page.dart';

// =============================================================
// You — the account page, and the only place in the app that stops to
// ask a question.
//
// The dialog at the bottom is `showLiquidGlassDialog`, and it is a real
// lens — the one place on this page that reads the backdrop. It can
// afford to: it is over a dimmed page, alone, and only while it is up.
// The card behind it wears the same rim without the glass.
// =============================================================

class ProfileTab extends AuroraTab {
  const ProfileTab();

  @override
  String get title => 'You';

  @override
  String get label => 'You';

  @override
  IconData get icon => Icons.person_rounded;

  @override
  AuroraPalette get palette => AuroraPalette.dusk;

  @override
  Widget content(BuildContext context) => const _ProfileContent();
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent();

  static const Color _accent = Color(0xFFC9A6FF);

  Future<void> _confirmSignOut(BuildContext context) async {
    final bool? out = await showLiquidGlassDialog<bool>(
      context: context,
      builder: (BuildContext context) => LiquidGlassDialog(
        width: 320,
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        style: auroraGlass(radius: 32, tint: const Color(0x24FFFFFF), blur: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.logout_rounded, size: 26, color: _accent),
            const SizedBox(height: 16),
            Text('Sign out of Aurora?', style: kTitle.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Your downloads stay on this device for 30 days.',
              textAlign: TextAlign.center,
              style: kBody,
            ),
            const SizedBox(height: 22),
            Row(
              children: <Widget>[
                Expanded(
                  child: LiquidGlassButton(
                    label: 'Stay',
                    height: 44,
                    foregroundColor: Colors.white,
                    style: auroraGlass(radius: 22, blur: 3, distortion: 0.07),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LiquidGlassButton(
                    label: 'Sign out',
                    height: 44,
                    foregroundColor: Colors.white,
                    style: auroraGlass(
                      radius: 22,
                      tint: const Color(0x5CFF4D6D),
                      blur: 3,
                      distortion: 0.07,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (out == true && context.mounted) {
      showAuroraToast(context, 'Signed out. See you tonight.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuroraList(
      children: <Widget>[
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            // The avatar is generated like every other picture here.
            CoverArt(seed: 'listener-avatar', size: 74, radius: 37),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Ahmed', style: kDisplay.copyWith(fontSize: 28)),
                  const SizedBox(height: 5),
                  Text('Listening since 2021 · 3,104 hours', style: kBody),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),

        // ── The year, in three numbers ───────────────────────
        GlassPanel(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('THIS YEAR', style: kEyebrow.copyWith(color: _accent)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const <Widget>[
                  StatColumn('412', 'Hours', accent: _accent),
                  StatColumn('88', 'Artists'),
                  StatColumn('19', 'Nights out'),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Most of it after eleven. Your top hour is 23:00, and your '
                'longest run was six records without a skip.',
                style: kBody,
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),
        const SectionHeader('Top artists',
            eyebrow: 'Played most', accent: _accent),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: kAlbums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int i) {
              final Album a = kAlbums[i];
              return SizedBox(
                width: 88,
                child: Column(
                  children: <Widget>[
                    CoverArt(seed: '${a.seed}-artist', size: 88, radius: 44),
                    const SizedBox(height: 9),
                    Text(a.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: kBody.copyWith(fontSize: 11.5)),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 26),
        _Row(
          icon: Icons.settings_rounded,
          label: 'Settings',
          detail: 'Playback, downloads, appearance',
          onTap: () => Navigator.of(context)
              .push(auroraRoute<void>(const SettingsPage())),
        ),
        const SizedBox(height: 10),
        const _Row(
          icon: Icons.download_rounded,
          label: 'Downloads',
          detail: '412 MB on this device',
        ),
        const SizedBox(height: 10),
        const _Row(
          icon: Icons.credit_card_rounded,
          label: 'Subscription',
          detail: 'Aurora Plus · renews 14 Sept',
        ),
        const SizedBox(height: 10),
        _Row(
          icon: Icons.logout_rounded,
          label: 'Sign out',
          detail: 'On this device only',
          onTap: () => _confirmSignOut(context),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.detail,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      onTap: onTap,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 19, color: const Color(0xB3EDECF5)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: kTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(detail, style: kBody.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: Colors.white.withValues(alpha: 0.3)),
        ],
      ),
    );
  }
}
