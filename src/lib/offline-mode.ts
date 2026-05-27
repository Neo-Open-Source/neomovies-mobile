import * as SecureStore from 'expo-secure-store';

const OFFLINE_MODE_KEY = 'neomovies_offline_mode_v1';
export const MAINTENANCE_ERROR_CODE = 'MAINTENANCE_MODE';
export const NETWORK_ERROR_CODE = 'NETWORK_UNAVAILABLE';

type OfflineModeState = {
  enabled: boolean;
  reason: 'maintenance' | 'network' | null;
};

let state: OfflineModeState = {
  enabled: false,
  reason: null,
};

const listeners = new Set<(next: OfflineModeState) => void>();

function emit() {
  for (const listener of listeners) listener(state);
}

export function getOfflineModeSnapshot() {
  return state;
}

export function subscribeOfflineMode(listener: (next: OfflineModeState) => void) {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

export async function hydrateOfflineMode() {
  try {
    const raw = await SecureStore.getItemAsync(OFFLINE_MODE_KEY);
    if (!raw) return;
    const parsed = JSON.parse(raw) as OfflineModeState;
    if (parsed && typeof parsed.enabled === 'boolean') {
      state = {
        enabled: parsed.enabled,
        reason: parsed.reason === 'maintenance' || parsed.reason === 'network' ? parsed.reason : null,
      };
      emit();
    }
  } catch {
    // ignore
  }
}

export function enableMaintenanceOfflineMode() {
  if (state.enabled && state.reason === 'maintenance') return;
  state = { enabled: true, reason: 'maintenance' };
  emit();
  void SecureStore.setItemAsync(OFFLINE_MODE_KEY, JSON.stringify(state));
}

export function enableNetworkOfflineMode() {
  if (state.enabled && state.reason === 'network') return;
  state = { enabled: true, reason: 'network' };
  emit();
  void SecureStore.setItemAsync(OFFLINE_MODE_KEY, JSON.stringify(state));
}

export function disableOfflineMode() {
  if (!state.enabled) return;
  state = { enabled: false, reason: null };
  emit();
  void SecureStore.setItemAsync(OFFLINE_MODE_KEY, JSON.stringify(state));
}

export function isMaintenancePayload(status: number, bodyText: string) {
  if (status !== 503) return false;
  const text = bodyText.trim();
  if (!text) return false;
  if (text.includes(`"${MAINTENANCE_ERROR_CODE}"`)) return true;
  try {
    const parsed = JSON.parse(text) as { code?: string };
    return parsed.code === MAINTENANCE_ERROR_CODE;
  } catch {
    return false;
  }
}
