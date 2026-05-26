export async function httpGet<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    method: 'GET',
    headers: {
      Accept: 'application/json',
      ...init?.headers,
    },
    ...init,
  });

  if (!response.ok) {
    const message = await response.text();
    throw new Error(`HTTP ${response.status}: ${message || 'Request failed'}`);
  }

  return (await response.json()) as T;
}

export async function httpGetText(url: string, init?: RequestInit): Promise<string> {
  const response = await fetch(url, {
    method: 'GET',
    headers: {
      Accept: 'text/html, text/plain, */*',
      ...init?.headers,
    },
    ...init,
  });

  const text = await response.text();
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${text || 'Request failed'}`);
  }

  return text;
}
