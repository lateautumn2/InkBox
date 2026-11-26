import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/l10n/l10n_helpers.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/inkbox_theme.dart';
import 'core/theme/theme_controller.dart';
import 'data/platform/platform_bridge.dart';
import 'data/providers/app_providers.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  runApp(const ProviderScope(child: InkBoxApp()));
}

class InkBoxApp extends ConsumerStatefulWidget {
  const InkBoxApp({super.key});

  @override
  ConsumerState<InkBoxApp> createState() => _InkBoxAppState();
}

class _InkBoxAppState extends ConsumerState<InkBoxApp> {
  StreamSubscription<PlatformEvent>? _openFileSub;

  @override
  void initState() {
    super.initState();
    _listenIncomingOpenFiles();
  }

  void _listenIncomingOpenFiles() {
    try {
      _openFileSub = ref.read(platformBridgeProvider).events.listen((ev) async {
        if (ev.type == 'open_file') {
          final path = ev.payload['path'] as String?;
          if (path != null && path.isNotEmpty) {
            try {
              final outcome = await ref
                  .read(importServiceProvider)
                  .importLocalPathDetailed(path);
              if (outcome.id != null) {
                if (outcome.kind == 'comic') {
                  appRouter.push('/manga/${outcome.id}');
                } else {
                  appRouter.push('/reader/book/${outcome.id}');
                }
              }
            } catch (_) {}
          }
        }
      });
    } catch (_) {
      // Safe fallback in isolated widget tests without native event channel
    }
  }

  @override
  void dispose() {
    _openFileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightTheme = InkBoxTheme.light(
          uiStyle: appearance.uiStyle,
          dynamicSeedColor:
              appearance.useDynamicColor ? lightDynamic?.primary : null,
        );
        final darkTheme = InkBoxTheme.dark(
          uiStyle: appearance.uiStyle,
          oled: appearance.isOledDark,
          dynamicSeedColor:
              appearance.useDynamicColor ? darkDynamic?.primary : null,
        );

        return MaterialApp.router(
          onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appName,
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: appearance.themeMode,
          locale: appearance.resolvedLocale,
          localizationsDelegates: kInkBoxLocalizationsDelegates,
          supportedLocales: const [
            Locale('zh'),
            Locale('en'),
            Locale('ja'),
          ],
          localeResolutionCallback: (deviceLocale, supported) {
            if (deviceLocale == null) return const Locale('zh');
            for (final s in supported) {
              if (s.languageCode == deviceLocale.languageCode) return s;
            }
            return const Locale('en');
          },
          routerConfig: appRouter,
        );
      },
    );
  }
}
