import 'package:callcenter_salon_mobil/screens/discover_page.dart';
import 'package:callcenter_salon_mobil/screens/user_panel_page.dart';
import 'package:flutter/material.dart';

/// Keşfet + Randevu aynı `/discover` ekranı (tek harita örneği); Hesabım ayrı.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// 0 = Keşfet, 1 = Randevu (aynı Discover içeriği), 2 = Hesabım
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: _index == 2,
            child: const DiscoverPage(includeBookingSlugRail: true),
          ),
          Offstage(
            offstage: _index != 2,
            child: const UserPanelPage(),
          ),
        ],
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: InkSplash.splashFactory,
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          backgroundColor: scheme.surface,
          selectedItemColor: scheme.primary,
          unselectedItemColor: scheme.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Keşfet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_note_outlined),
              activeIcon: Icon(Icons.event_note),
              label: 'Randevu',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_outlined),
              activeIcon: Icon(Icons.account_circle),
              label: 'Hesabım',
            ),
          ],
        ),
      ),
    );
  }
}
