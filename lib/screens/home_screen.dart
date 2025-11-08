import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '../design_system/design_system.dart';
import '../components/home_screen/home_screen_my_folders.dart';
import '../components/home_screen/home_screen_recent_notes.dart';
import '../components/home_screen/home_screen_top_bar.dart';
import '../services/drift_note_service.dart';

class HomeScreen extends StatefulWidget {
  static const String kRouteName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  late AnimationController _heroController;
  late Animation<double> _heroFadeAnimation;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      duration: PinpointAnimations.slow,
      vsync: this,
    );
    _heroFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: PinpointAnimations.emphasizedDecelerate,
      ),
    );
    _heroController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 18) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GradientScaffold(
      appBar: GlassAppBar(
        scrollController: _scrollController,
        title: HomeScreenTopBar(
          onSearchChanged: (query) {
            setState(() {
              _searchQuery = query;
            });
          },
        ),
      ),
      body: Column(
        children: [
          // HERO SECTION - Bold greeting and stats
          FadeInDown(
            duration: PinpointAnimations.slow,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(PinpointSpacing.ml),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting with gradient text
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withValues(alpha: 0.7),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      _getGreeting(),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900, // BOLD
                        letterSpacing: -1.5, // Tighter
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: PinpointSpacing.xs),
                  // Subtitle
                  Text(
                    'What would you like to create today?',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.brightness == Brightness.dark
                          ? PinpointColors.darkTextSecondary
                          : PinpointColors.lightTextSecondary,
                    ),
                  ),
                  SizedBox(height: PinpointSpacing.ml),
                  // Quick stats
                  StreamBuilder<int>(
                    stream: DriftNoteService.watchAllNotesStream().map((notes) => notes.length),
                    builder: (context, snapshot) {
                      final noteCount = snapshot.data ?? 0;
                      return Row(
                        children: [
                          _buildStatCard(
                            context,
                            icon: Symbols.note_stack,
                            label: 'Notes',
                            value: '$noteCount',
                          ),
                          SizedBox(width: PinpointSpacing.ms),
                          _buildStatCard(
                            context,
                            icon: Symbols.check_circle,
                            label: 'Todos',
                            value: '—',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: PinpointSpacing.md),

          // Folders Section
          FadeInUp(
            duration: PinpointAnimations.slow,
            delay: const Duration(milliseconds: 100),
            child: const HomeScreenMyFolders(),
          ),

          SizedBox(height: PinpointSpacing.md),

          // Recent Notes Section
          FadeInUp(
            duration: PinpointAnimations.slow,
            delay: const Duration(milliseconds: 200),
            child: HomeScreenRecentNotes(
              searchQuery: _searchQuery,
              scrollController: _scrollController,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: BrutalistCard(
        variant: BrutalistCardVariant.layered,
        padding: EdgeInsets.all(PinpointSpacing.md),
        onTap: () {
          PinpointHaptics.light();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: colorScheme.primary,
                  size: 24,
                ),
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900, // BOLD
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: PinpointSpacing.xs),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.brightness == Brightness.dark
                    ? PinpointColors.darkTextSecondary
                    : PinpointColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
