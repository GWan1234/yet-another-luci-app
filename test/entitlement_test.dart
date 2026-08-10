import 'package:flutter_test/flutter_test.dart';
import 'package:luci_mobile/providers/entitlement_provider.dart';

void main() {
  group('EntitlementTier Model & Router Limit Unit Tests', () {
    test('Free tier allows unlimited routers and shows ads', () {
      const state = EntitlementState(tier: EntitlementTier.free);
      expect(state.routerLimit, greaterThanOrEqualTo(9999));
      expect(state.isAdFree, isFalse);

      expect(state.canAddRouter(0), isTrue);
      expect(state.canAddRouter(1), isTrue);
      expect(state.canAddRouter(5), isTrue);
    });

    test('Plus tier allows unlimited routers and is ad-free', () {
      const state = EntitlementState(tier: EntitlementTier.plus);
      expect(state.routerLimit, greaterThanOrEqualTo(9999));
      expect(state.isAdFree, isTrue);

      expect(state.canAddRouter(0), isTrue);
      expect(state.canAddRouter(1), isTrue);
      expect(state.canAddRouter(5), isTrue);
    });

    test('Pro tier allows unlimited routers and is ad-free', () {
      const state = EntitlementState(tier: EntitlementTier.pro);
      expect(state.routerLimit, greaterThanOrEqualTo(9999));
      expect(state.isAdFree, isTrue);

      expect(state.canAddRouter(0), isTrue);
      expect(state.canAddRouter(3), isTrue);
      expect(state.canAddRouter(100), isTrue);
    });

    test('Lifetime tier allows unlimited routers and is ad-free', () {
      const state = EntitlementState(tier: EntitlementTier.lifetime);
      expect(state.routerLimit, greaterThanOrEqualTo(9999));
      expect(state.isAdFree, isTrue);

      expect(state.canAddRouter(0), isTrue);
      expect(state.canAddRouter(10), isTrue);
    });
  });

  group('EntitlementState Transitions', () {
    test('State copyWith correctly updates entitlement tier and retains state flags', () {
      const initial = EntitlementState(tier: EntitlementTier.free);
      expect(initial.tier, equals(EntitlementTier.free));

      final plusState = initial.copyWith(tier: EntitlementTier.plus);
      expect(plusState.tier, equals(EntitlementTier.plus));
      expect(plusState.isAdFree, isTrue);
      expect(plusState.canAddRouter(5), isTrue);

      final proState = plusState.copyWith(tier: EntitlementTier.pro);
      expect(proState.tier, equals(EntitlementTier.pro));
      expect(proState.isAdFree, isTrue);
      expect(proState.canAddRouter(5), isTrue);

      final lifetimeState = proState.copyWith(tier: EntitlementTier.lifetime);
      expect(lifetimeState.tier, equals(EntitlementTier.lifetime));
      expect(lifetimeState.isAdFree, isTrue);
    });
  });
}
