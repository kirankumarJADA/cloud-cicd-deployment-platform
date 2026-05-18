function fmt(ts) {
  try {
    return new Date(ts).toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  } catch {
    return ts;
  }
}

export default function PipelineFlow({ deployments }) {
  return (
    <div className="pipeline">
      {deployments.map((stage, i) => (
        <div className="stage" key={stage.stage}>
          <div className="idx">STAGE {String(i + 1).padStart(2, '0')}</div>
          <div className="name">{stage.stage}</div>
          <div className={`state ${stage.status.toLowerCase()}`}>
            <span className="status-dot" />
            {stage.status}
          </div>
          <div className="ts">{fmt(stage.timestamp)}</div>
          {i < deployments.length - 1 && <span className="connector" />}
        </div>
      ))}
    </div>
  );
}
