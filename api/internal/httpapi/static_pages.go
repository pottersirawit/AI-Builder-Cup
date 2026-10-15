package httpapi

import (
	"net/http"
)

func (s *Server) homePage(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(homePageHTML))
}

func (s *Server) privacyPolicy(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(privacyPolicyHTML))
}

func (s *Server) oauth2Callback(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)

	errParam := r.URL.Query().Get("error")
	if errParam != "" {
		_, _ = w.Write([]byte(oauthCallbackErrorHTML(errParam)))
		return
	}

	code := r.URL.Query().Get("code")
	_, _ = w.Write([]byte(oauthCallbackSuccessHTML(code)))
}

const homePageHTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Fontokmai (ฝนตกไหม) - Bangkok Weather & Flood Commute Resilience</title>
  <style>
    :root {
      --bg: #0b1120;
      --card-bg: #1e293b;
      --text: #f8fafc;
      --text-muted: #94a3b8;
      --primary: #0284c7;
      --accent: #38bdf8;
      --border: #334155;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background-color: var(--bg);
      color: var(--text);
      line-height: 1.6;
      padding: 0 1.5rem;
    }
    .container {
      max-width: 900px;
      margin: 0 auto;
      padding: 3rem 0;
    }
    header {
      text-align: center;
      margin-bottom: 3.5rem;
    }
    .badge {
      display: inline-block;
      padding: 0.25rem 0.75rem;
      border-radius: 9999px;
      background: rgba(56, 189, 248, 0.1);
      color: var(--accent);
      font-size: 0.875rem;
      font-weight: 600;
      margin-bottom: 1rem;
      border: 1px solid rgba(56, 189, 248, 0.2);
    }
    h1 {
      font-size: 2.75rem;
      font-weight: 800;
      letter-spacing: -0.025em;
      margin-bottom: 0.75rem;
      background: linear-gradient(to right, #ffffff, #94a3b8);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .tagline {
      font-size: 1.25rem;
      color: var(--text-muted);
      max-width: 650px;
      margin: 0 auto;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 1.5rem;
      margin-bottom: 3rem;
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 1.75rem;
    }
    .card h3 {
      font-size: 1.25rem;
      margin-bottom: 0.5rem;
      color: #ffffff;
    }
    .card p {
      color: var(--text-muted);
      font-size: 0.95rem;
    }
    .features-list {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 2rem;
      margin-bottom: 3rem;
    }
    .features-list h2 {
      font-size: 1.5rem;
      margin-bottom: 1rem;
    }
    ul {
      list-style-position: inside;
      color: var(--text-muted);
    }
    li {
      margin-bottom: 0.5rem;
    }
    footer {
      border-top: 1px solid var(--border);
      padding-top: 2rem;
      text-align: center;
      color: var(--text-muted);
      font-size: 0.875rem;
    }
    footer a {
      color: var(--accent);
      text-decoration: none;
      margin: 0 0.75rem;
    }
    footer a:hover {
      text-decoration: underline;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <span class="badge">Bangkok Urban Mobility Intelligence</span>
      <h1>Fontokmai (ฝนตกไหม)</h1>
      <p class="tagline">An intelligent AI commute & flood resilience platform protecting Bangkok commuters with live sensor telemetry and proactive route intelligence.</p>
    </header>

    <div class="grid">
      <div class="card">
        <h3>251 BMA Road Sensors</h3>
        <p>Real-time depth telemetry across Bangkok flood spots filtered dynamically along user travel polylines.</p>
      </div>
      <div class="card">
        <h3>Marine Tidal Forecasting</h3>
        <p>Live Chao Phraya estuary surge telemetry to compute backwater drainage impedance risks in low-lying canals.</p>
      </div>
      <div class="card">
        <h3>WeatherNext 3 Radar</h3>
        <p>Precipitation, wind gust, and radar-backed weather predictions cached with high-throughput architecture.</p>
      </div>
    </div>

    <div class="features-list">
      <h2>Google Calendar & Proactive Advisory</h2>
      <p style="margin-bottom: 1rem; color: var(--text-muted);">
        Fontokmai integrates with Google Calendar to read upcoming event schedules and locations. By synchronizing anticipated travel times with incoming weather fronts and road inundation sensors, the AI calculates safe departure windows before flash floods trap commuters in traffic.
      </p>
      <ul>
        <li><strong>Privacy-First:</strong> Read-only calendar access, ephemeral in-memory processing.</li>
        <li><strong>Multimodal Ingestion:</strong> Evaluates route alternatives when primary corridors flood.</li>
        <li><strong>Emergency Hotlines:</strong> 1-tap direct access to 1784 DDPM, 1669 EMS, and 1586 DOH.</li>
      </ul>
    </div>

    <footer>
      <p>&copy; 2026 Fontokmai (ฝนตกไหม). All rights reserved.</p>
      <p style="margin-top: 0.75rem;">
        <a href="/">Home</a>
        <a href="/privacy">Privacy Policy</a>
        <a href="https://github.com/pottersirawit/AI-Builder-Cup" target="_blank" rel="noopener">GitHub Repository</a>
        <a href="mailto:the32069@gmail.com">Contact Developer</a>
      </p>
    </footer>
  </div>
</body>
</html>`

const privacyPolicyHTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Privacy Policy - Fontokmai (ฝนตกไหม)</title>
  <style>
    :root {
      --bg: #0b1120;
      --card-bg: #1e293b;
      --text: #f8fafc;
      --text-muted: #94a3b8;
      --primary: #0284c7;
      --accent: #38bdf8;
      --border: #334155;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background-color: var(--bg);
      color: var(--text);
      line-height: 1.6;
      padding: 0 1.5rem;
    }
    .container {
      max-width: 800px;
      margin: 0 auto;
      padding: 3rem 0;
    }
    header {
      margin-bottom: 2.5rem;
      border-bottom: 1px solid var(--border);
      padding-bottom: 1.5rem;
    }
    h1 {
      font-size: 2.25rem;
      font-weight: 800;
      margin-bottom: 0.5rem;
    }
    .date {
      color: var(--text-muted);
      font-size: 0.875rem;
    }
    section {
      margin-bottom: 2rem;
    }
    h2 {
      font-size: 1.35rem;
      color: var(--accent);
      margin-bottom: 0.75rem;
    }
    p, ul {
      color: var(--text-muted);
      margin-bottom: 1rem;
      font-size: 0.95rem;
    }
    ul {
      padding-left: 1.5rem;
    }
    li {
      margin-bottom: 0.5rem;
    }
    .callout {
      background: rgba(2, 132, 199, 0.1);
      border-left: 4px solid var(--primary);
      padding: 1rem 1.25rem;
      border-radius: 4px;
      margin: 1.5rem 0;
    }
    .callout p {
      color: #e2e8f0;
      margin-bottom: 0;
    }
    footer {
      border-top: 1px solid var(--border);
      padding-top: 2rem;
      text-align: center;
      color: var(--text-muted);
      font-size: 0.875rem;
      margin-top: 3rem;
    }
    footer a {
      color: var(--accent);
      text-decoration: none;
      margin: 0 0.75rem;
    }
    footer a:hover {
      text-decoration: underline;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>Privacy Policy</h1>
      <p class="date">Last updated: October 16, 2026 &bull; Fontokmai (ฝนตกไหม)</p>
    </header>

    <section>
      <h2>1. Overview</h2>
      <p>
        Fontokmai ("ฝนตกไหม", "we", "our", or "the app") provides weather resilience and flood commute advisory services for Bangkok. This Privacy Policy details our practices concerning data collection, usage, and user protection.
      </p>
    </section>

    <section>
      <h2>2. Google User Data & Google Calendar Access</h2>
      <p>
        Fontokmai offers an optional feature that allows users to connect their Google Calendar account to anticipate commute schedules.
      </p>
      <ul>
        <li><strong>OAuth Scope Requested:</strong> <code>https://www.googleapis.com/auth/calendar.readonly</code></li>
        <li><strong>Specific Data Accessed:</strong> We access strictly read-only event timing (start/end timestamp) and event destination location strings for upcoming calendar entries. We do not access attendee lists, event descriptions, attachments, or private notes.</li>
        <li><strong>Purpose of Access:</strong> Calendar event locations and times are used solely to determine your upcoming route and departure window, correlating them with real-time Bangkok Metropolitan Administration (BMA) flood sensors and weather forecasts to notify you of potential travel disruptions.</li>
      </ul>

      <div class="callout">
        <p><strong>Google API Limited Use Disclosure:</strong> Fontokmai's use and transfer to any other app of information received from Google APIs will adhere to the <a href="https://developers.google.com/terms/api-services-user-data-policy" target="_blank" rel="noopener" style="color: #38bdf8;">Google API Services User Data Policy</a>, including the <strong>Limited Use</strong> requirements.</p>
      </div>
    </section>

    <section>
      <h2>3. Data Retention & Storage</h2>
      <p>
        We practice strict data minimization:
      </p>
      <ul>
        <li><strong>In-Memory Processing:</strong> Calendar data and route coordinates are processed ephemerally in-memory during your active planning session.</li>
        <li><strong>No Persistent Database Storage:</strong> Your calendar events, personal identifiers, and past locations are never permanently written to backend databases or disks.</li>
        <li><strong>Zero Data Selling:</strong> We never sell, rent, commercialize, or share your Google user data or personal information with third parties, advertisers, or data brokers.</li>
      </ul>
    </section>

    <section>
      <h2>4. User Control & Revocation of Access</h2>
      <p>
        You have complete control over your Google account permissions at all times. You can disconnect calendar access within the app settings or immediately revoke Fontokmai's access through your Google Account Security Dashboard:
      </p>
      <p>
        <a href="https://myaccount.google.com/permissions" target="_blank" rel="noopener" style="color: var(--accent);">https://myaccount.google.com/permissions</a>
      </p>
    </section>

    <section>
      <h2>5. Contact Us</h2>
      <p>
        If you have any questions or inquiries regarding this Privacy Policy or data processing practices, please contact:
      </p>
      <p>
        <strong>Developer Contact:</strong> <a href="mailto:the32069@gmail.com" style="color: var(--accent);">the32069@gmail.com</a><br>
        <strong>Project Repository:</strong> <a href="https://github.com/pottersirawit/AI-Builder-Cup" target="_blank" rel="noopener" style="color: var(--accent);">github.com/pottersirawit/AI-Builder-Cup</a>
      </p>
    </section>

    <footer>
      <p>&copy; 2026 Fontokmai (ฝนตกไหม). All rights reserved.</p>
      <p style="margin-top: 0.75rem;">
        <a href="/">Home</a>
        <a href="/privacy">Privacy Policy</a>
      </p>
    </footer>
  </div>
</body>
</html>`

func oauthCallbackSuccessHTML(code string) string {
	return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Google Calendar Connected - Fontokmai (ฝนตกไหม)</title>
  <style>
    :root {
      --bg: #0b1120;
      --card-bg: #1e293b;
      --text: #f8fafc;
      --text-muted: #94a3b8;
      --success: #10b981;
      --accent: #38bdf8;
      --border: #334155;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background-color: var(--bg);
      color: var(--text);
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 1.5rem;
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 16px;
      max-width: 520px;
      width: 100%;
      padding: 2.5rem;
      text-align: center;
      box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5);
    }
    .icon-circle {
      width: 72px;
      height: 72px;
      border-radius: 50%;
      background: rgba(16, 185, 129, 0.15);
      border: 2px solid var(--success);
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 1.5rem;
      color: var(--success);
      font-size: 2.5rem;
      line-height: 1;
    }
    h1 {
      font-size: 1.75rem;
      font-weight: 700;
      margin-bottom: 0.5rem;
    }
    .thai-sub {
      font-size: 1.1rem;
      color: var(--accent);
      margin-bottom: 1.25rem;
      font-weight: 500;
    }
    p {
      color: var(--text-muted);
      font-size: 0.95rem;
      line-height: 1.5;
      margin-bottom: 1.75rem;
    }
    .badge {
      display: inline-block;
      padding: 0.35rem 0.75rem;
      border-radius: 6px;
      background: rgba(56, 189, 248, 0.1);
      color: var(--accent);
      font-size: 0.8rem;
      font-family: monospace;
      margin-bottom: 1.75rem;
      border: 1px solid rgba(56, 189, 248, 0.2);
    }
    .btn {
      display: inline-block;
      width: 100%;
      padding: 0.875rem;
      background: #0284c7;
      color: #ffffff;
      text-decoration: none;
      border-radius: 8px;
      font-weight: 600;
      font-size: 1rem;
      border: none;
      cursor: pointer;
      transition: background 0.15s ease;
    }
    .btn:hover {
      background: #0369a1;
    }
    .note {
      margin-top: 1.25rem;
      font-size: 0.8rem;
      color: var(--text-muted);
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon-circle">&#10003;</div>
    <h1>Google Calendar Connected</h1>
    <div class="thai-sub">เชื่อมต่อ Google Calendar สำเร็จแล้ว</div>
    <p>
      Fontokmai is now authorized to coordinate your upcoming commute schedules with real-time Bangkok flood depth sensors, tidal surge, and weather radar.
    </p>
    <div class="badge">Scope: calendar.readonly</div>
    <button class="btn" onclick="window.close();">Close Window</button>
    <div class="note">You can safely close this browser tab and return to the app.</div>
  </div>
  <script>
    if (window.opener) {
      window.opener.postMessage({ type: 'GOOGLE_OAUTH_SUCCESS', code: '` + code + `' }, '*');
    }
  </script>
</body>
</html>`
}

func oauthCallbackErrorHTML(errParam string) string {
	return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Authorization Cancelled - Fontokmai (ฝนตกไหม)</title>
  <style>
    :root {
      --bg: #0b1120;
      --card-bg: #1e293b;
      --text: #f8fafc;
      --text-muted: #94a3b8;
      --warning: #f59e0b;
      --border: #334155;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background-color: var(--bg);
      color: var(--text);
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 1.5rem;
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 16px;
      max-width: 500px;
      width: 100%;
      padding: 2.5rem;
      text-align: center;
    }
    .icon-circle {
      width: 72px;
      height: 72px;
      border-radius: 50%;
      background: rgba(245, 158, 11, 0.15);
      border: 2px solid var(--warning);
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 1.5rem;
      color: var(--warning);
      font-size: 2.5rem;
      line-height: 1;
    }
    h1 {
      font-size: 1.5rem;
      font-weight: 700;
      margin-bottom: 0.5rem;
    }
    p {
      color: var(--text-muted);
      font-size: 0.95rem;
      margin-bottom: 1.5rem;
    }
    .btn {
      display: inline-block;
      padding: 0.75rem 1.5rem;
      background: #334155;
      color: #ffffff;
      text-decoration: none;
      border-radius: 8px;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon-circle">!</div>
    <h1>Authorization Cancelled</h1>
    <p>Google Calendar was not connected (` + errParam + `). You can safely close this window and try again later.</p>
    <a href="/" class="btn">Return to Home</a>
  </div>
</body>
</html>`
}
