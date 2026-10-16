package httpapi

import (
	"context"
	"html"
	"log/slog"
	"net/http"
	"strings"
	"time"
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
	email := r.URL.Query().Get("state")
	if email == "" || !strings.Contains(email, "@") {
		email = r.URL.Query().Get("email")
	}
	if email == "" || !strings.Contains(email, "@") {
		email = "the32069@gmail.com"
	}

	if code != "" {
		go func(authCode, userEmail string) {
			ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
			defer cancel()

			redirectURI := "https://fontokmai-api-lmr33aj5zq-as.a.run.app/oauth2callback"
			tokenResp, err := ExchangeGoogleAuthCode(ctx, authCode, redirectURI)
			if err != nil {
				slog.Warn("google oauth exchange failed", "email", userEmail, "err", err)
				return
			}

			tokenStoreMu.Lock()
			tokenStore[userEmail] = &userToken{
				AccessToken:  tokenResp.AccessToken,
				RefreshToken: tokenResp.RefreshToken,
				Expiry:       time.Now().Add(time.Duration(tokenResp.ExpiresIn) * time.Second),
			}
			tokenStoreMu.Unlock()

			_ = s.SyncUserWorkspaceData(ctx, userEmail, tokenResp.AccessToken, time.Now())
		}(code, email)
	}

	_, _ = w.Write([]byte(oauthCallbackSuccessHTML(code, email)))
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

func oauthCallbackSuccessHTML(code, email string) string {
	return `<!DOCTYPE html>
<html lang="th">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Google Calendar Connected - Fontokmai (ฝนตกไหม)</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #dfeeff;
      --bg2: #eef6ff;
      --card: #ffffff;
      --ink: #0b1f3a;
      --muted: #5b6b82;
      --line: #d6e4f5;
      --blue: #1a73e8;
      --blue2: #4285f4;
      --violet: #9b72cb;
      --ok: #1e8e3e;
      --ok-bg: #e6f4ea;
      --r: 24px;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Chakra Petch', system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: radial-gradient(1200px 600px at 20% -10%, #cfe4ff 0%, #f3f8ff 60%, #f7fafe 100%);
      color: var(--ink);
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 24px 16px;
    }
    .card {
      background: var(--card);
      border-radius: var(--r);
      border: 1px solid rgba(214, 228, 245, 0.9);
      max-width: 480px;
      width: 100%;
      padding: 36px 30px;
      text-align: center;
      box-shadow: 0 16px 40px rgba(20, 60, 120, 0.12);
    }
    .logo {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      font-weight: 700;
      font-size: 16px;
      color: var(--ink);
      margin-bottom: 24px;
    }
    .logo i {
      width: 28px;
      height: 28px;
      border-radius: 9px;
      background: linear-gradient(135deg, var(--blue2), var(--violet));
      display: inline-block;
      position: relative;
    }
    .logo i::after {
      content: "";
      position: absolute;
      left: 8px;
      top: 8px;
      width: 12px;
      height: 12px;
      border-radius: 50% 50% 50% 0;
      background: #fff;
      transform: rotate(-45deg);
    }
    .icon-wrap {
      width: 68px;
      height: 68px;
      border-radius: 50%;
      background: var(--ok-bg);
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 16px;
      color: var(--ok);
    }
    .pill {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 5px 14px;
      border-radius: 999px;
      font-size: 13px;
      font-weight: 600;
      background: var(--ok-bg);
      color: var(--ok);
      margin-bottom: 14px;
    }
    h1 {
      font-size: 1.45rem;
      font-weight: 700;
      color: var(--ink);
      margin-bottom: 4px;
    }
    .thai-title {
      font-size: 1.05rem;
      color: var(--blue);
      font-weight: 600;
      margin-bottom: 14px;
    }
    p {
      color: var(--muted);
      font-size: 0.95rem;
      line-height: 1.6;
      margin-bottom: 20px;
    }
    .user-chip {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 8px 16px;
      background: var(--bg2);
      border: 1px solid var(--line);
      border-radius: 12px;
      font-size: 14px;
      font-weight: 600;
      color: var(--blue);
      margin-bottom: 24px;
    }
    .btn {
      appearance: none;
      border: 0;
      border-radius: 14px;
      padding: 14px 20px;
      font: inherit;
      font-weight: 600;
      font-size: 15px;
      cursor: pointer;
      background: var(--blue);
      color: #fff;
      box-shadow: 0 6px 16px rgba(26, 115, 232, 0.28);
      transition: all 0.15s ease;
      display: inline-block;
      text-decoration: none;
    }
    .btn:hover {
      background: #1557b0;
      transform: translateY(-1px);
    }
    .btn.block {
      width: 100%;
    }
    .note {
      margin-top: 14px;
      font-size: 13px;
      color: var(--muted);
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">
      <i></i>
      <span>ฝนตกไหม Fontokmai</span>
    </div>
    <div class="icon-wrap">
      <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="20 6 9 17 4 12"></polyline>
      </svg>
    </div>
    <div class="pill">✓ เชื่อมต่อสำเร็จ</div>
    <h1>Google Calendar Connected</h1>
    <div class="thai-title">เชื่อมต่อ Google Calendar สำเร็จแล้ว</div>
    <p>
      ระบบเชื่อมต่อกับบัญชี Google ของคุณเรียบร้อยแล้ว Fontokmai พร้อมช่วยวิเคราะห์ฝนตก เรดาร์ตรวจจับ และน้ำท่วมขังบนเส้นทางการเดินทางตามตารางนัดหมาย เพื่อความปลอดภัยในการเดินทางของคุณ
    </p>
    <div class="user-chip">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z"/>
      </svg>
      <span>` + html.EscapeString(email) + `</span>
    </div>
    <button class="btn block" onclick="window.close();">กลับสู่แอปพลิเคชัน</button>
    <div class="note">คุณสามารถปิดหน้าต่างนี้และกลับไปใช้งานแอปได้ทันที</div>
  </div>
  <script>
    if (window.opener) {
      window.opener.postMessage({ type: 'GOOGLE_OAUTH_SUCCESS', code: '` + html.EscapeString(code) + `' }, '*');
    }
  </script>
</body>
</html>`
}

func oauthCallbackErrorHTML(errParam string) string {
	return `<!DOCTYPE html>
<html lang="th">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Authorization Cancelled - Fontokmai (ฝนตกไหม)</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #dfeeff;
      --bg2: #eef6ff;
      --card: #ffffff;
      --ink: #0b1f3a;
      --muted: #5b6b82;
      --line: #d6e4f5;
      --blue: #1a73e8;
      --blue2: #4285f4;
      --violet: #9b72cb;
      --warn: #e37400;
      --warn-bg: #fef3e0;
      --r: 24px;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Chakra Petch', system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: radial-gradient(1200px 600px at 20% -10%, #cfe4ff 0%, #f3f8ff 60%, #f7fafe 100%);
      color: var(--ink);
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 24px 16px;
    }
    .card {
      background: var(--card);
      border-radius: var(--r);
      border: 1px solid rgba(214, 228, 245, 0.9);
      max-width: 480px;
      width: 100%;
      padding: 36px 30px;
      text-align: center;
      box-shadow: 0 16px 40px rgba(20, 60, 120, 0.12);
    }
    .logo {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      font-weight: 700;
      font-size: 16px;
      color: var(--ink);
      margin-bottom: 24px;
    }
    .logo i {
      width: 28px;
      height: 28px;
      border-radius: 9px;
      background: linear-gradient(135deg, var(--blue2), var(--violet));
      display: inline-block;
      position: relative;
    }
    .logo i::after {
      content: "";
      position: absolute;
      left: 8px;
      top: 8px;
      width: 12px;
      height: 12px;
      border-radius: 50% 50% 50% 0;
      background: #fff;
      transform: rotate(-45deg);
    }
    .icon-wrap {
      width: 68px;
      height: 68px;
      border-radius: 50%;
      background: var(--warn-bg);
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 16px;
      color: var(--warn);
    }
    .pill {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 5px 14px;
      border-radius: 999px;
      font-size: 13px;
      font-weight: 600;
      background: var(--warn-bg);
      color: var(--warn);
      margin-bottom: 14px;
    }
    h1 {
      font-size: 1.45rem;
      font-weight: 700;
      color: var(--ink);
      margin-bottom: 4px;
    }
    .thai-title {
      font-size: 1.05rem;
      color: var(--warn);
      font-weight: 600;
      margin-bottom: 14px;
    }
    p {
      color: var(--muted);
      font-size: 0.95rem;
      line-height: 1.6;
      margin-bottom: 24px;
    }
    .btn {
      appearance: none;
      border: 0;
      border-radius: 14px;
      padding: 14px 20px;
      font: inherit;
      font-weight: 600;
      font-size: 15px;
      cursor: pointer;
      background: #5b6b82;
      color: #fff;
      transition: all 0.15s ease;
      display: inline-block;
      text-decoration: none;
    }
    .btn:hover {
      background: #475569;
    }
    .btn.block {
      width: 100%;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">
      <i></i>
      <span>ฝนตกไหม Fontokmai</span>
    </div>
    <div class="icon-wrap">
      <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="10"></circle>
        <line x1="12" y1="8" x2="12" y2="12"></line>
        <line x1="12" y1="16" x2="12.01" y2="16"></line>
      </svg>
    </div>
    <div class="pill">การเชื่อมต่อถูกยกเลิก</div>
    <h1>Authorization Cancelled</h1>
    <div class="thai-title">ยังไม่ได้เชื่อมต่อ Google Calendar</div>
    <p>
      การอนุญาตเข้าถึงบริการถูกยกเลิก (` + html.EscapeString(errParam) + `) คุณสามารถกลับไปที่แอปและลองเชื่อมต่อใหม่อีกครั้งได้ตลอดเวลาจากเมนูตั้งค่า
    </p>
    <a href="/" class="btn block">กลับสู่หน้าหลัก</a>
  </div>
</body>
</html>`
}
