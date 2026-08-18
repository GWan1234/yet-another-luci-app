// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:luci_mobile/models/router.dart' as model;
import 'package:luci_mobile/services/secure_storage_service.dart';

class RouterService {
  RouterService({this.isReviewerMode = false});

  final bool isReviewerMode;
  final SecureStorageService _secureStorageService = SecureStorageService();

  List<model.Router> _routers = [];
  model.Router? _selectedRouter;

  static final model.Router mockRouter = model.Router(
    id: 'http://192.168.1.1-root',
    ipAddress: '192.168.1.1',
    username: 'root',
    password: '',
    useHttps: false,
    lastKnownHostname: 'OpenWrt-Reviewer',
  );

  List<model.Router> get routers =>
      _routers.isEmpty && isReviewerMode ? [mockRouter] : _routers;
  model.Router? get selectedRouter =>
      _selectedRouter ?? (isReviewerMode ? mockRouter : null);

  static String generateId(String ip, String user, bool useHttps) {
    final scheme = useHttps ? 'https' : 'http';
    return '$scheme://$ip-$user';
  }

  Future<void> loadRouters() async {
    _routers = await _secureStorageService.getRouters();

    // Single active router mode: if routers exist, select the first router
    if (_routers.isNotEmpty) {
      _selectedRouter = _routers.first;
      // Enforce single item in list
      _routers = [_selectedRouter!];
      await _secureStorageService.saveSelectedRouterId(_selectedRouter!.id);
    } else {
      _selectedRouter = null;
    }
  }

  Future<void> addRouter(model.Router router) async {
    // Single active router mode: replace any stored router with the current active router
    _routers = [router];
    _selectedRouter = router;
    await _secureStorageService.saveRouters(_routers);
    await _secureStorageService.saveSelectedRouterId(router.id);
  }

  Future<void> clearAllRouters() async {
    _routers = [];
    _selectedRouter = null;
    await _secureStorageService.saveRouters([]);
    await _secureStorageService.saveSelectedRouterId(null);
  }

  Future<bool> removeRouter(String id) async {
    _routers.clear();
    _selectedRouter = null;
    await _secureStorageService.saveRouters([]);
    await _secureStorageService.saveSelectedRouterId(null);
    return false;
  }

  model.Router? selectRouter(String id) {
    if (_routers.isEmpty) return null;
    _selectedRouter = _routers.first;
    return _selectedRouter;
  }

  Future<void> updateRouter(model.Router router) async {
    _routers = [router];
    _selectedRouter = router;
    await _secureStorageService.saveRouters(_routers);
    await _secureStorageService.saveSelectedRouterId(router.id);
  }

  Future<void> updateSelectedRouterHostname(String hostname) async {
    if (_selectedRouter != null && hostname.isNotEmpty) {
      _selectedRouter = _selectedRouter!.copyWith(lastKnownHostname: hostname);
      _routers = [_selectedRouter!];
      await _secureStorageService.saveRouters(_routers);
    }
  }

  model.Router createRouter(
    String ip,
    String user,
    String pass,
    bool useHttps,
  ) {
    final id = generateId(ip, user, useHttps);
    return model.Router(
      id: id,
      ipAddress: ip,
      username: user,
      password: pass,
      useHttps: useHttps,
    );
  }
}
