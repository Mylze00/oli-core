import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/theme_provider.dart';
import '../features/home/home_page.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDarkMode
          ? ThemeData.dark().copyWith(
              textTheme: ThemeData.dark().textTheme.apply(
                fontFamily: 'CreatoDisplay',
                fontWeightDelta: 0,
              ),
            )
          : ThemeData.light().copyWith(
              textTheme: ThemeData.light().textTheme.apply(
                fontFamily: 'CreatoDisplay',
                fontWeightDelta: 0,
              ),
            ),
      home: const HomePage(),
    );
  }
}
