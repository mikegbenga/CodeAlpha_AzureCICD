(async () => {
  const dl = document.getElementById('info');
  try {
    const res = await fetch('/api/info', { cache: 'no-store' });
    const data = await res.json();
    const rows = {
      Version: data.version,
      'Build ID': data.buildId,
      Environment: data.environment,
      Instance: data.hostname,
      Node: data.node,
      'Started at': new Date(data.startedAt).toLocaleString(),
      'Uptime (s)': data.uptimeSeconds,
    };
    dl.innerHTML = '';
    for (const [k, v] of Object.entries(rows)) {
      const dt = document.createElement('dt');
      const dd = document.createElement('dd');
      dt.textContent = k;
      dd.textContent = String(v);
      dl.append(dt, dd);
    }
  } catch (e) {
    dl.innerHTML = '<dt>Status</dt><dd>API unavailable</dd>';
  }
})();
