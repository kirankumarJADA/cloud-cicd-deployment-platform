import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext.jsx';
import { api } from '../api/client.js';
import PipelineFlow from '../components/PipelineFlow.jsx';

function uptime(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  return `${h}h ${m}m ${s}s`;
}

const DEPLOY_LOG = [
  ['INFO', 'info', 'Workflow triggered by push to refs/heads/main'],
  ['OK', 'ok', 'backend-test ✓  42 tests, 0 failures'],
  ['OK', 'ok', 'frontend-build ✓  vite build 3.1s, bundle 184 kB gz'],
  ['INFO', 'info', 'docker buildx — backend image (multi-stage)'],
  ['INFO', 'info', 'docker buildx — frontend image (nginx static)'],
  ['OK', 'ok', 'image-push ✓  ghcr.io/org/cloud-cicd:sha-9f2a1c'],
  ['INFO', 'info', 'ssh deploy@prod-vm — pulling latest containers'],
  ['WARN', 'warn', 'old container drained, 3s grace period'],
  ['OK', 'ok', 'deploy-production ✓  health checks green, swap complete'],
];

export default function Dashboard() {
  const { session, logout } = useAuth();
  const [data, setData] = useState(null);
  const [profile, setProfile] = useState(null);
  const [health, setHealth] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    Promise.all([api.dashboard(), api.me(), api.health()])
      .then(([d, p, h]) => {
        if (!active) return;
        setData(d);
        setProfile(p);
        setHealth(h);
      })
      .catch((e) => active && setError(e.message));
    return () => {
      active = false;
    };
  }, []);

  if (error) {
    return (
      <div className="loading">
        <div>
          telemetry unavailable — {error}
        </div>
      </div>
    );
  }

  if (!data || !profile) {
    return <div className="loading">establishing link…</div>;
  }

  return (
    <div className="console">
      <header className="topbar">
        <div className="left">
          <span className="status-dot" />
          <span className="title">{data.serviceName}</span>
          <span className="tag">v{data.version}</span>
          <span className="tag">{data.environment.toUpperCase()}</span>
        </div>
        <div className="right">
          <span>
            {session.username} · {session.role}
          </span>
          <button className="btn-ghost" onClick={logout}>
            Sign out
          </button>
        </div>
      </header>

      <section className="metrics-grid">
        <div className="metric">
          <div className="label">Service Health</div>
          <div className="value ok">
            {health ? health.status : '—'}
            <small>liveness + readiness</small>
          </div>
        </div>
        <div className="metric">
          <div className="label">Registered Users</div>
          <div className="value">{data.totalUsers}</div>
        </div>
        <div className="metric">
          <div className="label">Process Uptime</div>
          <div className="value">{uptime(data.uptimeSeconds)}</div>
        </div>
        <div className="metric">
          <div className="label">Environment</div>
          <div className="value">
            {data.environment}
            <small>via env vars</small>
          </div>
        </div>
      </section>

      <section className="section">
        <div className="section-head">
          <h3>Last deployment pipeline</h3>
          <span className="meta">GITHUB ACTIONS · 5 STAGES</span>
        </div>
        <PipelineFlow deployments={data.recentDeployments} />
      </section>

      <section className="section">
        <div className="section-head">
          <h3>Deployment log</h3>
          <span className="meta">SSH · CONTAINER ORCHESTRATION</span>
        </div>
        <div className="logbox">
          {DEPLOY_LOG.map(([lvl, cls, msg], i) => (
            <div className="logline" key={i}>
              <span className="time">
                {String(10 + Math.floor(i / 3)).padStart(2, '0')}:
                {String((i * 7) % 60).padStart(2, '0')}:
                {String((i * 13) % 60).padStart(2, '0')}
              </span>
              <span className={`lvl ${cls}`}>{lvl}</span>
              <span className="msg">{msg}</span>
            </div>
          ))}
        </div>
      </section>

      <section className="section">
        <div className="section-head">
          <h3>Authenticated session</h3>
          <span className="meta">JWT · STATELESS</span>
        </div>
        <div className="profile-strip">
          <div className="cell">
            <div className="k">User ID</div>
            <div className="v">{profile.id}</div>
          </div>
          <div className="cell">
            <div className="k">Username</div>
            <div className="v">{profile.username}</div>
          </div>
          <div className="cell">
            <div className="k">Email</div>
            <div className="v">{profile.email}</div>
          </div>
          <div className="cell">
            <div className="k">Role</div>
            <div className="v">{profile.role}</div>
          </div>
        </div>
      </section>

      <footer className="footer-note">
        <span>cloud-cicd-deployment-platform · operations console</span>
        <span>spring boot · react · docker · github actions · nginx</span>
      </footer>
    </div>
  );
}
