import { MAINTENANCE_ERROR_CODE, NETWORK_ERROR_CODE, enableMaintenanceOfflineMode, enableNetworkOfflineMode, isMaintenancePayload } from '@/lib/offline-mode';

export async function httpGet<T>(url: string, init?: RequestInit): Promise<T> {
  let response: Response;
  try {
    response = await fetch(url, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        ...init?.headers,
      },
      ...init,
    });
  } catch {
    enableNetworkOfflineMode();
    throw new Error(NETWORK_ERROR_CODE);
  }

  if (!response.ok) {
    const message = await response.text();
    if (isMaintenancePayload(response.status, message)) {
      enableMaintenanceOfflineMode();
      throw new Error(MAINTENANCE_ERROR_CODE);
    }
    throw new Error(`HTTP ${response.status}: ${message || 'Request failed'}`);
  }

  return (await response.json()) as T;
}

export async function httpGetText(url: string, init?: RequestInit): Promise<string> {
  let response: Response;
  try {
    response = await fetch(url, {
      method: 'GET',
      headers: {
        Accept: 'text/html, text/plain, */*',
        ...init?.headers,
      },
      ...init,
    });
  } catch {
    enableNetworkOfflineMode();
    throw new Error(NETWORK_ERROR_CODE);
  }

  const text = await response.text();
  if (!response.ok) {
    if (isMaintenancePayload(response.status, text)) {
      enableMaintenanceOfflineMode();
      throw new Error(MAINTENANCE_ERROR_CODE);
    }
    throw new Error(`HTTP ${response.status}: ${text || 'Request failed'}`);
  }

  return text;
}
