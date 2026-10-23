/*
 * Quiet home screen for LTvLauncher (CleanTV build).
 *
 * A calm, remote-friendly home: a large app list on the left over the
 * wallpaper, a small clock top right, and quiet text links bottom right.
 * Distributed under the same license as the rest of the project (GPL-3.0).
 */

import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/date_time_widget.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class QuietHomeView extends StatelessWidget {
  const QuietHomeView({super.key});

  /// All visible apps from the launcher sections, in section order, without duplicates.
  List<App> _apps(AppsService service) {
    final seen = <String>{};
    final result = <App>[];
    for (final section in service.launcherSections) {
      if (section is! Category) continue;
      for (final app in section.applications) {
        if (app.hidden) continue;
        if (seen.add(app.packageName)) result.add(app);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.sizeOf(context).height;
    final double fontSize = (height * 0.065).clamp(22.0, 52.0);

    // Material ancestor so Text has no debug underline and focus/ink work normally.
    return Material(
      type: MaterialType.transparency,
      child: FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(height * 0.12, height * 0.08, height * 0.12, height * 0.08),
        child: Consumer<AppsService>(
          builder: (context, appsService, _) {
            if (!appsService.initialized) {
              return const Center(child: CircularProgressIndicator());
            }
            final apps = _apps(appsService);

            return Stack(
              children: [
                // App list (left)
                Positioned.fill(
                  right: height * 0.7,
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.white, Colors.transparent],
                      stops: [0.0, 0.82, 1.0],
                    ).createShader(rect),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.only(top: height * 0.12, bottom: height * 0.2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < apps.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: _QuietListItem(
                                key: ValueKey(apps[i].packageName),
                                app: apps[i],
                                fontSize: fontSize,
                                autofocus: i == 0,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (apps.isEmpty)
                  Positioned.fill(
                    right: height * 0.7,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "No apps to show",
                        style: TextStyle(fontSize: fontSize * 0.6, color: Colors.white70),
                      ),
                    ),
                  ),
                // Clock (top right)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Selector<SettingsService, String>(
                    selector: (_, settings) => settings.timeFormat,
                    builder: (context, timeFormat, _) => DateTimeWidget(
                      timeFormat,
                      animate: false,
                      textStyle: TextStyle(
                        fontSize: fontSize * 0.75,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withOpacity(0.85),
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                  ),
                ),
                // Quiet links (bottom right)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _QuietLink(
                        label: "All apps",
                        fontSize: fontSize * 0.42,
                        onPressed: () => context.read<LauncherState>().setAllAppsOpen(true),
                      ),
                      _QuietLink(
                        label: "Screensaver",
                        fontSize: fontSize * 0.42,
                        onPressed: () => context.read<AppsService>().startAmbientMode(),
                      ),
                      _QuietLink(
                        label: "Settings",
                        fontSize: fontSize * 0.42,
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const SettingsPanel(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      ),
    );
  }
}

class _QuietListItem extends StatefulWidget {
  final App app;
  final double fontSize;
  final bool autofocus;

  const _QuietListItem({
    super.key,
    required this.app,
    required this.fontSize,
    this.autofocus = false,
  });

  @override
  State<_QuietListItem> createState() => _QuietListItemState();
}

class _QuietListItemState extends State<_QuietListItem> {
  bool _focused = false;
  late final Future<ImageProvider?> _iconFuture;

  @override
  void initState() {
    super.initState();
    _iconFuture = _loadIcon();
  }

  Future<ImageProvider?> _loadIcon() async {
    final bytes = await context.read<AppsService>().getAppIcon(widget.app.packageName);
    if (bytes.isEmpty) return null;
    return MemoryImage(bytes);
  }

  void _launch() {
    context.read<AppsService>().launchApp(widget.app);
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = widget.fontSize * 1.05;

    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          _launch();
          return null;
        }),
      },
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: (hasFocus) {
          setState(() => _focused = hasFocus);
          if (hasFocus) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Scrollable.ensureVisible(
                context,
                alignment: 0.3,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
              );
            });
          }
        },
        child: GestureDetector(
          onTap: _launch,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(
              horizontal: widget.fontSize * 0.45,
              vertical: widget.fontSize * 0.12,
            ),
            decoration: BoxDecoration(
              color: _focused ? Colors.white.withOpacity(0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(widget.fontSize * 0.5),
              border: Border.all(
                color: _focused ? Colors.white.withOpacity(0.14) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: FutureBuilder<ImageProvider?>(
                    future: _iconFuture,
                    builder: (context, snapshot) {
                      final image = snapshot.data;
                      if (image == null) {
                        return Icon(Icons.apps, size: iconSize * 0.8, color: Colors.white54);
                      }
                      return Image(image: image, fit: BoxFit.contain);
                    },
                  ),
                ),
                SizedBox(width: widget.fontSize * 0.45),
                Flexible(
                  child: Text(
                    widget.app.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      height: 1.15,
                      fontWeight: _focused ? FontWeight.w500 : FontWeight.w300,
                      color: _focused ? Colors.white : Colors.white.withOpacity(0.7),
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 10)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietLink extends StatefulWidget {
  final String label;
  final double fontSize;
  final VoidCallback onPressed;

  const _QuietLink({
    required this.label,
    required this.fontSize,
    required this.onPressed,
  });

  @override
  State<_QuietLink> createState() => _QuietLinkState();
}

class _QuietLinkState extends State<_QuietLink> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onPressed();
          return null;
        }),
      },
      child: Focus(
        onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: EdgeInsets.symmetric(
              horizontal: widget.fontSize * 0.8,
              vertical: widget.fontSize * 0.35,
            ),
            decoration: BoxDecoration(
              color: _focused ? Colors.white.withOpacity(0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(widget.fontSize),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: _focused ? FontWeight.w500 : FontWeight.w300,
                color: _focused ? Colors.white : Colors.white.withOpacity(0.7),
                shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
