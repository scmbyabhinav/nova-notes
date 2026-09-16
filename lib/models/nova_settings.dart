enum NovaThemeMode {
  system,
  light,
  dark,
  amoled,
}

enum NovaViewMode {
  grid,
  list,
  compact,
}

class NovaSettings {
  const NovaSettings({
    this.themeMode = NovaThemeMode.system,
    this.viewMode = NovaViewMode.grid,
    this.accentColor = 0xFF2563EB,
    this.appLockEnabled = false,
    this.biometricEnabled = false,
  });

  final NovaThemeMode themeMode;
  final NovaViewMode viewMode;
  final int accentColor;
  final bool appLockEnabled;
  final bool biometricEnabled;
}
