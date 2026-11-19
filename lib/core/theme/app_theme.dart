// KuryentePay theme: unified navy, teal, restrained gold, and existing Manrope typography.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ============================================================
  // KuryentePay brand colors (legacy constant names retained for compatibility)
  // ============================================================
  // Public brand constants may be reused by future shared widgets.
  static const Color brandBlue = Color(0xFF087F79); // Legacy identifier: KuryentePay teal
  static const Color brandBlueDeep = Color(0xFF075F5B); // Legacy identifier: deep teal
  static const Color brandNavy = Color(0xFF102F3E);
  static const Color brandSky = Color(0xFF59C7B7); // Legacy identifier: light teal
  static const Color brandGold = Color(0xFFF6D483);
  static const Color brandGoldDark = Color(0xFF9D741A);

  // ============================================================
  // LIGHT MODE
  // ============================================================
  static const Color _lBackground = Color(0xFFF4F7FA);
  static const Color _lSurface = Color(0xFFFFFFFF);
  static const Color _lSurfaceSoft = Color(0xFFF8FAFA);
  static const Color _lBorder = Color(0xFFDCE6EA);

  static const Color _lPrimary = brandBlue;
  static const Color _lPrimaryContainer = Color(0xFFDDF4EF);
  static const Color _lSecondary = brandGold;
  static const Color _lSecondaryContainer = Color(0xFFFFF3D6);
  static const Color _lTertiary = brandSky;
  static const Color _lTertiaryContainer = Color(0xFFE2F6F1);

  static const Color _lText = Color(0xFF173347);
  static const Color _lMuted = Color(0xFF526A75);
  static const Color _lMutedSoft = Color(0xFF738990);

  // ============================================================
  // DARK MODE
  // ============================================================
  static const Color _dBackground = Color(0xFF0B1E28);
  static const Color _dSurface = Color(0xFF122F3A);
  static const Color _dSurfaceSoft = Color(0xFF173A44);
  static const Color _dSurfaceStrong = Color(0xFF1C4550);
  static const Color _dBorder = Color(0xFF315760);

  static const Color _dPrimary = Color(0xFF8CE5D5);
  static const Color _dPrimaryContainer = Color(0xFF194B49);
  static const Color _dSecondary = Color(0xFFF6D483);
  static const Color _dSecondaryContainer = Color(0xFF514421);
  static const Color _dTertiary = Color(0xFF77D6C6);
  static const Color _dTertiaryContainer = Color(0xFF1C4945);

  static const Color _dText = Color(0xFFF4FAFA);
  static const Color _dMuted = Color(0xFFCCDFE0);
  static const Color _dMutedSoft = Color(0xFF9EB9BA);

  // ============================================================
  // SEMANTIC COLORS
  // ============================================================
  static const Color successLight = Color(0xFF178A58);
  static const Color warningLight = Color(0xFFC98A19);
  static const Color infoLight = Color(0xFF087F79);
  static const Color accentBlueLight = brandBlue;

  static const Color successDark = Color(0xFF6ED5A4);
  static const Color warningDark = Color(0xFFF0C567);
  static const Color infoDark = Color(0xFF8CE5D5);
  static const Color accentBlueDark = Color(0xFF8CE5D5); // Legacy identifier

  static const Color danger = Color(0xFFD94A55);
  static const Color _danger = danger;

  // ============================================================
  // TYPOGRAPHY
  // ============================================================
  static TextTheme _buildTextTheme(
      TextTheme base, {
        required Color text,
        required Color muted,
      }) {
    return GoogleFonts.manropeTextTheme(base).copyWith(
      headlineSmall: GoogleFonts.manrope(
        color: text,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.10,
        letterSpacing: -0.7,
      ),
      titleLarge: GoogleFonts.manrope(
        color: text,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.25,
      ),
      titleMedium: GoogleFonts.manrope(
        color: text,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.20,
      ),
      titleSmall: GoogleFonts.manrope(
        color: text,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.20,
      ),
      bodyLarge: GoogleFonts.manrope(
        color: text,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.40,
      ),
      bodyMedium: GoogleFonts.manrope(
        color: text,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.40,
      ),
      bodySmall: GoogleFonts.manrope(
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      labelLarge: GoogleFonts.manrope(
        color: text,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
      labelMedium: GoogleFonts.manrope(
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      labelSmall: GoogleFonts.manrope(
        color: muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
    );
  }

  // ============================================================
  // SHARED COMPONENT THEMES
  // ============================================================
  static InputDecorationTheme _buildInputDecorationTheme({
    required Color fillColor,
    required Color borderColor,
    required Color focusColor,
    required Color textColor,
    required Color mutedColor,
  }) {
    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: color,
          width: width,
        ),
      );
    }

    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      hintStyle: GoogleFonts.manrope(
        color: mutedColor,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      labelStyle: GoogleFonts.manrope(
        color: mutedColor,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      floatingLabelStyle: GoogleFonts.manrope(
        color: focusColor,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
      helperStyle: GoogleFonts.manrope(
        color: mutedColor,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      helperMaxLines: 2,
      errorStyle: GoogleFonts.manrope(
        color: _danger,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        height: 1.25,
      ),
      errorMaxLines: 2,
      prefixIconColor: mutedColor,
      suffixIconColor: mutedColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: border(borderColor),
      enabledBorder: border(borderColor),
      disabledBorder: border(
        borderColor.withValues(alpha: 0.62),
      ),
      focusedBorder: border(focusColor, width: 1.7),
      errorBorder: border(_danger),
      focusedErrorBorder: border(_danger, width: 1.7),
    );
  }

  static FilledButtonThemeData _buildFilledButtonTheme({
    required Color background,
    required Color foreground,
  }) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(alpha: 0.36),
        disabledForegroundColor: foreground.withValues(alpha: 0.72),
        elevation: 0,
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme({
    required Color background,
    required Color foreground,
  }) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(alpha: 0.36),
        disabledForegroundColor: foreground.withValues(alpha: 0.72),
        elevation: 0,
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme({
    required Color foreground,
    required Color borderColor,
  }) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(
          color: borderColor,
          width: 1.15,
        ),
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme({
    required Color foreground,
  }) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        textStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }

  static ChipThemeData _buildChipTheme({
    required Color backgroundColor,
    required Color selectedColor,
    required Color disabledColor,
    required Color borderColor,
    required Color labelColor,
    required Color selectedLabelColor,
  }) {
    return ChipThemeData(
      backgroundColor: backgroundColor,
      selectedColor: selectedColor,
      disabledColor: disabledColor,
      side: BorderSide(color: borderColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      labelStyle: GoogleFonts.manrope(
        color: labelColor,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      secondaryLabelStyle: GoogleFonts.manrope(
        color: selectedLabelColor,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
    );
  }

  // ============================================================
  // LIGHT THEME
  // ============================================================
  static ThemeData light() {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    final TextTheme textTheme = _buildTextTheme(
      base.textTheme,
      text: _lText,
      muted: _lMuted,
    );

    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _lPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: _lPrimary,
      onPrimary: Colors.white,
      primaryContainer: _lPrimaryContainer,
      onPrimaryContainer: brandBlueDeep,
      secondary: _lSecondary,
      onSecondary: brandNavy,
      secondaryContainer: _lSecondaryContainer,
      onSecondaryContainer: const Color(0xFF5C4300),
      tertiary: _lTertiary,
      onTertiary: brandNavy,
      tertiaryContainer: _lTertiaryContainer,
      onTertiaryContainer: brandNavy,
      error: _danger,
      onError: Colors.white,
      surface: _lSurface,
      onSurface: _lText,
      onSurfaceVariant: _lMuted,
      outline: _lBorder,
      outlineVariant: _lBorder,
      surfaceTint: Colors.transparent,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _lBackground,
      canvasColor: _lBackground,
      cardColor: _lSurface,
      dividerColor: _lBorder,
      shadowColor: brandNavy.withValues(alpha: 0.10),
      focusColor: _lPrimary.withValues(alpha: 0.12),
      disabledColor: _lMutedSoft.withValues(alpha: 0.46),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: const IconThemeData(
        color: _lMuted,
        size: 22,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: _lPrimary,
        selectionColor: _lPrimary.withValues(alpha: 0.18),
        selectionHandleColor: _lPrimary,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: _lBackground,
        foregroundColor: _lText,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(
          color: _lText,
          size: 22,
        ),
        actionsIconTheme: const IconThemeData(
          color: _lText,
          size: 22,
        ),
        titleTextStyle: GoogleFonts.manrope(
          color: _lText,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.25,
        ),
      ),
      cardTheme: CardThemeData(
        color: _lSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: brandNavy.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(
            color: _lBorder,
            width: 1,
          ),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: _lSurface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: _buildInputDecorationTheme(
        fillColor: _lSurfaceSoft,
        borderColor: _lBorder,
        focusColor: _lPrimary,
        textColor: _lText,
        mutedColor: _lMuted,
      ),
      filledButtonTheme: _buildFilledButtonTheme(
        background: _lPrimary,
        foreground: Colors.white,
      ),
      elevatedButtonTheme: _buildElevatedButtonTheme(
        background: _lPrimary,
        foreground: Colors.white,
      ),
      outlinedButtonTheme: _buildOutlinedButtonTheme(
        foreground: brandBlueDeep,
        borderColor: _lBorder,
      ),
      textButtonTheme: _buildTextButtonTheme(
        foreground: _lPrimary,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: _lText,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: _lMutedSoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: brandNavy,
        actionTextColor: const Color(0xFFF6D483),
        contentTextStyle: GoogleFonts.manrope(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: brandBlue.withValues(alpha: 0.35),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _lPrimary,
        linearTrackColor: _lPrimaryContainer,
        circularTrackColor: _lPrimaryContainer,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _lMutedSoft;
          }
          return _lPrimary;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _lMutedSoft;
          }
          if (states.contains(WidgetState.selected)) {
            return _lPrimary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(
          color: _lBorder,
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return _lSurface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _lPrimary.withValues(alpha: 0.88);
          }
          return _lMutedSoft.withValues(alpha: 0.30);
        }),
        trackOutlineColor:
        WidgetStateProperty.all(Colors.transparent),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _lMuted,
        textColor: _lText,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 2,
        ),
      ),
      chipTheme: _buildChipTheme(
        backgroundColor: _lSurfaceSoft,
        selectedColor: _lPrimaryContainer,
        disabledColor: const Color(0xFFE9F0F1),
        borderColor: _lBorder,
        labelColor: _lText,
        selectedLabelColor: brandBlueDeep,
      ),
      dividerTheme: const DividerThemeData(
        color: _lBorder,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _lSurface,
        modalBackgroundColor: _lSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: _lBorder,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _lSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _lBorder),
        ),
        textStyle: GoogleFonts.manrope(
          color: _lText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _lPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        extendedTextStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      bottomNavigationBarTheme:
      const BottomNavigationBarThemeData(
        backgroundColor: _lSurface,
        selectedItemColor: _lPrimary,
        unselectedItemColor: _lMuted,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: _lSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _lPrimaryContainer.withValues(alpha: 0.94),
        labelBehavior:
        NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle:
        WidgetStateProperty.resolveWith((states) {
          final bool selected =
          states.contains(WidgetState.selected);

          return GoogleFonts.manrope(
            fontWeight:
            selected ? FontWeight.w800 : FontWeight.w700,
            fontSize: 12,
            color: selected ? _lPrimary : _lMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected =
          states.contains(WidgetState.selected);

          return IconThemeData(
            color: selected ? _lPrimary : _lMuted,
            size: 22,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _lPrimary,
        unselectedLabelColor: _lMuted,
        indicatorColor: _lPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: _lBorder,
        labelStyle: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: brandNavy,
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ============================================================
  // DARK THEME
  // ============================================================
  static ThemeData dark() {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    final TextTheme textTheme = _buildTextTheme(
      base.textTheme,
      text: _dText,
      muted: _dMuted,
    );

    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _dPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _dPrimary,
      onPrimary: brandNavy,
      primaryContainer: _dPrimaryContainer,
      onPrimaryContainer: const Color(0xFFDCF8F2),
      secondary: _dSecondary,
      onSecondary: brandNavy,
      secondaryContainer: _dSecondaryContainer,
      onSecondaryContainer: const Color(0xFFFFE89C),
      tertiary: _dTertiary,
      onTertiary: brandNavy,
      tertiaryContainer: _dTertiaryContainer,
      onTertiaryContainer: const Color(0xFFD7F9F1),
      error: _danger,
      onError: Colors.white,
      surface: _dSurface,
      onSurface: _dText,
      onSurfaceVariant: _dMuted,
      outline: _dBorder,
      outlineVariant: _dBorder,
      surfaceTint: Colors.transparent,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _dBackground,
      canvasColor: _dBackground,
      cardColor: _dSurface,
      dividerColor: _dBorder,
      shadowColor: Colors.black.withValues(alpha: 0.38),
      focusColor: _dPrimary.withValues(alpha: 0.15),
      disabledColor: _dMutedSoft.withValues(alpha: 0.42),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: const IconThemeData(
        color: _dMuted,
        size: 22,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: _dPrimary,
        selectionColor: _dPrimary.withValues(alpha: 0.24),
        selectionHandleColor: _dPrimary,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: _dBackground,
        foregroundColor: _dText,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(
          color: _dText,
          size: 22,
        ),
        actionsIconTheme: const IconThemeData(
          color: _dText,
          size: 22,
        ),
        titleTextStyle: GoogleFonts.manrope(
          color: _dText,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.25,
        ),
      ),
      cardTheme: CardThemeData(
        color: _dSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: 0.34),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(
            color: _dBorder,
            width: 1,
          ),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: _dSurface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: _buildInputDecorationTheme(
        fillColor: _dSurfaceSoft,
        borderColor: _dBorder,
        focusColor: _dPrimary,
        textColor: _dText,
        mutedColor: _dMuted,
      ),
      filledButtonTheme: _buildFilledButtonTheme(
        background: _dPrimary,
        foreground: brandNavy,
      ),
      elevatedButtonTheme: _buildElevatedButtonTheme(
        background: _dPrimary,
        foreground: brandNavy,
      ),
      outlinedButtonTheme: _buildOutlinedButtonTheme(
        foreground: _dText,
        borderColor: _dBorder,
      ),
      textButtonTheme: _buildTextButtonTheme(
        foreground: _dPrimary,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: _dText,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: _dMutedSoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: _dSurfaceStrong,
        actionTextColor: _dSecondary,
        contentTextStyle: GoogleFonts.manrope(
          color: _dText,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _dBorder),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _dPrimary,
        linearTrackColor: _dPrimaryContainer,
        circularTrackColor: _dPrimaryContainer,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _dMutedSoft;
          }
          return _dPrimary;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return _dMutedSoft;
          }
          if (states.contains(WidgetState.selected)) {
            return _dPrimary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(brandNavy),
        side: const BorderSide(
          color: _dBorder,
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return brandNavy;
          }
          return const Color(0xFFEAF5F2);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _dPrimary.withValues(alpha: 0.88);
          }
          return _dMutedSoft.withValues(alpha: 0.28);
        }),
        trackOutlineColor:
        WidgetStateProperty.all(Colors.transparent),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _dMuted,
        textColor: _dText,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 2,
        ),
      ),
      chipTheme: _buildChipTheme(
        backgroundColor: _dSurfaceSoft,
        selectedColor: _dPrimaryContainer,
        disabledColor: const Color(0xFF173A44),
        borderColor: _dBorder,
        labelColor: _dText,
        selectedLabelColor: const Color(0xFFDCF8F2),
      ),
      dividerTheme: const DividerThemeData(
        color: _dBorder,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _dSurface,
        modalBackgroundColor: _dSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: _dBorder,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _dSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _dBorder),
        ),
        textStyle: GoogleFonts.manrope(
          color: _dText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _dPrimary,
        foregroundColor: brandNavy,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        extendedTextStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      bottomNavigationBarTheme:
      const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF102F3E),
        selectedItemColor: _dPrimary,
        unselectedItemColor: _dMuted,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: const Color(0xFF102F3E),
        surfaceTintColor: Colors.transparent,
        indicatorColor: _dPrimaryContainer.withValues(alpha: 0.96),
        labelBehavior:
        NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle:
        WidgetStateProperty.resolveWith((states) {
          final bool selected =
          states.contains(WidgetState.selected);

          return GoogleFonts.manrope(
            fontWeight:
            selected ? FontWeight.w800 : FontWeight.w700,
            fontSize: 12,
            color: selected ? _dPrimary : _dMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected =
          states.contains(WidgetState.selected);

          return IconThemeData(
            color: selected ? _dPrimary : _dMuted,
            size: 22,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _dPrimary,
        unselectedLabelColor: _dMuted,
        indicatorColor: _dPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: _dBorder,
        labelStyle: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _dSurfaceStrong,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _dBorder),
        ),
        textStyle: GoogleFonts.manrope(
          color: _dText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
