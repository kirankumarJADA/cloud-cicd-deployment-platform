import { useState } from 'react';
import { useAuth } from '../context/AuthContext.jsx';

const PIPELINE = [
  'backend-test',
  'frontend-build',
  'docker-build',
  'image-push',
  'deploy-production',
];

export default function Login() {
  const { login, register } = useAuth();
  const [mode, setMode] = useState('login');
  const [form, setForm] = useState({ username: '', email: '', password: '' });
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const isLogin = mode === 'login';

  const update = (key) => (e) =>
    setForm((f) => ({ ...f, [key]: e.target.value }));

  const submit = async (e) => {
    e.preventDefault();
    setError('');
    setBusy(true);
    try {
      if (isLogin) {
        await login({ username: form.username, password: form.password });
      } else {
        await register(form);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="auth-shell">
      <aside className="auth-brand">
        <div className="brand-mark">
          <span className="glyph">C</span>
          <span>cloud-cicd-deployment-platform</span>
        </div>

        <div>
          <p className="eyebrow">Operations Console</p>
          <h1>
            Ship to production
            <br />
            on every <span>git push</span>.
          </h1>
          <p>
            A sample microservice wired to a full CI/CD pipeline: tested,
            containerized, registry-pushed, and deployed to a Linux VM over SSH
            with zero manual steps.
          </p>
        </div>

        <div className="pipeline-mini">
          {PIPELINE.map((stage, i) => (
            <div className={`row ${i === PIPELINE.length - 1 ? 'live' : ''}`} key={stage}>
              <span>{String(i + 1).padStart(2, '0')}</span>
              <span>{stage}</span>
              <span className="bar" />
              <span>{i === PIPELINE.length - 1 ? '◉ live' : '✓'}</span>
            </div>
          ))}
        </div>
      </aside>

      <main className="auth-form-wrap">
        <form className="auth-card" onSubmit={submit}>
          <div className="card-head">
            <h2>{isLogin ? 'Sign in' : 'Create account'}</h2>
            <span className="tag">{isLogin ? 'AUTH' : 'REGISTER'}</span>
          </div>

          {error && <div className="form-error">{error}</div>}

          <div className="field">
            <label htmlFor="username">Username</label>
            <input
              id="username"
              autoComplete="username"
              value={form.username}
              onChange={update('username')}
              required
            />
          </div>

          {!isLogin && (
            <div className="field">
              <label htmlFor="email">Email</label>
              <input
                id="email"
                type="email"
                autoComplete="email"
                value={form.email}
                onChange={update('email')}
                required
              />
            </div>
          )}

          <div className="field">
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              autoComplete={isLogin ? 'current-password' : 'new-password'}
              value={form.password}
              onChange={update('password')}
              required
            />
          </div>

          <button className="btn-primary" type="submit" disabled={busy}>
            {busy ? 'Working…' : isLogin ? 'Authenticate' : 'Provision account'}
          </button>

          <div className="switch-mode">
            {isLogin ? "No account yet?" : 'Already provisioned?'}{' '}
            <button
              type="button"
              onClick={() => {
                setMode(isLogin ? 'register' : 'login');
                setError('');
              }}
            >
              {isLogin ? 'Create one' : 'Sign in'}
            </button>
          </div>

          <p className="hint">
            Seeded admin → <code>admin</code> / <code>AdminPass123</code>
            <br />
            Rotate this credential immediately in any real environment.
          </p>
        </form>
      </main>
    </div>
  );
}
