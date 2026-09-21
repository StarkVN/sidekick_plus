import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:google_fonts/google_fonts.dart';

const kFlutterBlue = Color(0xFF39CEFD);

ThemeData get darkTheme {
  return _customThemeBuilder(
    cardColor: const Color(0xFF2B2D2F),
    scaffoldBackgroundColor: const Color(0xFF1D1E1F),
    primaryColor: kFlutterBlue,
    accentColor: kFlutterBlue,
  );
}

ThemeData _customThemeBuilder({
  Color? cardColor,
  Color? scaffoldBackgroundColor,
  Color? primaryColor,
  Color? accentColor,
  Brightness brightness = Brightness.dark,
}) {
  ThemeData baseTheme;
  if (brightness == Brightness.dark) {
    baseTheme = ThemeData.dark();
  } else {
    baseTheme = ThemeData.light();
  }
  final textTheme = GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme);
  return ThemeData(
    textTheme: textTheme,
    brightness: brightness,
    primarySwatch: Colors.blue,
    cardColor: cardColor,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor ?? kFlutterBlue,
      brightness: brightness,
    ).copyWith(
      secondary: accentColor ?? kFlutterBlue,
    ),
    dividerColor: Colors.white10,
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey,
        backgroundColor: Colors.grey[850],
        side: BorderSide(
          color: Colors.grey[800] ?? Colors.grey,
        ),
      ),
    ),
    textButtonTheme: _textButtonThemeData,
    popupMenuTheme: PopupMenuThemeData(
      shape: _roundedShape,
    ),
    dialogTheme: DialogThemeData(
      shape: _roundedShape,
      backgroundColor: scaffoldBackgroundColor,
      titleTextStyle: textTheme.displayLarge,
      contentTextStyle: textTheme.bodyLarge,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.black54,
    ),
    chipTheme: ThemeData.dark().chipTheme.copyWith(
          backgroundColor: Colors.black12,
        ),
  ).copyWith(
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

ThemeData get lightTheme {
  final textTheme =
      GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme);
  return ThemeData(
    textTheme: textTheme,
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kFlutterBlue,
      brightness: Brightness.light,
    ),
    dividerColor: Colors.black12,
    scaffoldBackgroundColor: const Color(0xfffafafa),
    textButtonTheme: _textButtonThemeData,
    cardTheme: const CardThemeData(
      elevation: 3,
      shadowColor: Colors.black45,
    ),
    dialogTheme: DialogThemeData(
      shape: _roundedShape,
      titleTextStyle: textTheme.displaySmall,
      contentTextStyle: textTheme.bodyLarge,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Color(0xFFF0F6FA),
      iconTheme: IconThemeData(),
    ),
  ).copyWith(
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

TextButtonThemeData get _textButtonThemeData {
  return TextButtonThemeData(
    style: TextButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: const EdgeInsets.symmetric(horizontal: 20),
    ),
  );
}

RoundedRectangleBorder get _roundedShape {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10.0),
  );
}

bool isNumeric(String? s) {
  if (s == null) {
    return false;
  }
  return double.tryParse(s) != null;
}

double getWindowsBuild() {
  final osVer =
      Platform.operatingSystemVersion.replaceAll(RegExp(r'[^\w\s\.]+'), '');

  final splitOsVer = osVer.split(' ');

  final nums = splitOsVer.where((element) => isNumeric(element)).toList();
  return double.parse(nums.last);
}

Color platformBackgroundColor(BuildContext context) {
  final themeBrightness = Theme.of(context).brightness;
  final platformBrightness = MediaQuery.of(context).platformBrightness;
  final brightnessMatches = themeBrightness == platformBrightness;

  // Brightness matches doesn't work on Windows 10

  if (Platform.isWindows) {
    if (getWindowsBuild() >= 22000) {
      Window.setEffect(
          effect: WindowEffect.mica,
          color: Theme.of(context).cardColor.withAlpha(0),
          dark: Theme.of(context).brightness == Brightness.dark);
      return Colors.transparent;
    } else if (getWindowsBuild() >= 10240) {
      // Acrylic causes issues on W10
      Window.setEffect(
        effect: WindowEffect.aero,
        color: Theme.of(context).cardColor.withAlpha(200),
      );
      return Colors.transparent;
    }
    return Theme.of(context).cardColor;
  }

  if (brightnessMatches && Platform.isMacOS) {
    Window.setEffect(
      effect: WindowEffect.sidebar,
      color: Colors.transparent,
    );
    return Colors.transparent;
  } else {
    return Theme.of(context).cardColor;
  }
}
