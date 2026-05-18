// Thin fetch wrapper. The base URL is empty in production because nginx serves
// the SPA and proxies /api to the backend on the same origin.
const BASE_URL = import.meta.env.VITE_API_BASE_URL || '';

let authToken = null;

export function setAuthToken(token) {
  authToken = token;
}

async function request(path, { method = 'GET', body, auth = true } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (auth && authToken) {
    headers.Authorization = `Bearer ${authToken}`;
  }

  const response = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : null;

  if (!response.ok) {
    const message =
      (data && (data.message || data.error)) || `Request failed (${response.status})`;
    throw new Error(message);
  }
  return data;
}

export const api = {
  register: (payload) =>
    request('/api/auth/register', { method: 'POST', body: payload, auth: false }),
  login: (payload) =>
    request('/api/auth/login', { method: 'POST', body: payload, auth: false }),
  me: () => request('/api/me'),
  dashboard: () => request('/api/dashboard'),
  health: () => request('/api/public/health', { auth: false }),
};
