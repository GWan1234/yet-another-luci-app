import 'package:flutter/foundation.dart';
import 'luci_module.dart';

/// Central registry for managing dynamic LuCI app modules.
class LuciModuleRegistry extends ChangeNotifier {
  static final LuciModuleRegistry _instance = LuciModuleRegistry._internal();
  factory LuciModuleRegistry() => _instance;
  LuciModuleRegistry._internal();

  static LuciModuleRegistry get instance => _instance;

  final Map<String, LuciModule> _modules = {};

  /// Registers a module with the framework.
  void registerModule(LuciModule module) {
    if (_modules.containsKey(module.id)) {
      debugPrint('[LuciModuleRegistry] Module already registered: ${module.id}');
      return;
    }
    _modules[module.id] = module;
    module.initialize();
    notifyListeners();
    debugPrint('[LuciModuleRegistry] Registered module: ${module.id} (${module.name})');
  }

  /// Unregisters a module by its ID.
  void unregisterModule(String id) {
    final module = _modules.remove(id);
    if (module != null) {
      module.dispose();
      notifyListeners();
      debugPrint('[LuciModuleRegistry] Unregistered module: $id');
    }
  }

  /// Retrieves a registered module by ID.
  LuciModule? getModule(String id) => _modules[id];

  /// Returns all registered modules sorted by priority.
  List<LuciModule> get allModules {
    final list = _modules.values.toList();
    list.sort((a, b) => a.priority.compareTo(b.priority));
    return list;
  }

  /// Returns only enabled modules sorted by priority.
  List<LuciModule> get enabledModules {
    return allModules.where((m) => m.isEnabled).toList();
  }

  /// Returns enabled modules that belong to a specific category.
  List<LuciModule> getModulesByCategory(LuciModuleCategory category) {
    return enabledModules.where((m) => m.category == category).toList();
  }

  /// Returns enabled modules marked for bottom navigation bar.
  List<LuciModule> get bottomNavModules {
    return enabledModules.where((m) => m.showInBottomNav).toList();
  }

  /// Clears all modules.
  void clear() {
    for (final module in _modules.values) {
      module.dispose();
    }
    _modules.clear();
    notifyListeners();
  }
}
