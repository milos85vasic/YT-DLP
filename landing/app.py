#!/usr/bin/env python3
"""
Боба Landing Page - Seamless multi-platform cookie authentication.
Flow: Sign in to your platforms (YouTube / Instagram / Facebook / X / TikTok /
Bilibili / Threads / Reddit / …) → export cookies → upload here →
auto-redirect to Dashboard. A single Netscape cookies.txt may carry sessions
for many platforms simultaneously; the validator accepts any of the supported
video sites (see ``_validate_cookie_file`` for the canonical list).
"""

import os
import uuid
import time
from flask import Flask, render_template_string, request, jsonify, make_response, send_from_directory
import requests

app = Flask(__name__)

METUBE_URL = os.environ.get("METUBE_URL", "http://metube-direct:8081")
PROXY_PORT = int(os.environ.get("PROXY_PORT", "8080"))

app.sessions = {}

INDEX_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Боба — YouTube Downloader</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            background: #2b2b2b;
            color: #a9b7c6;
            padding: 20px;
        }
        .container { text-align: center; max-width: 550px; width: 100%; }
        .logo-img {
            width: 96px;
            height: 96px;
            margin-bottom: 12px;
            border-radius: 20px;
            object-fit: contain;
        }
        h1 {
            font-size: 2.8rem;
            font-weight: 800;
            margin-bottom: 6px;
            color: #a9b7c6;
            letter-spacing: -1px;
        }
        .subtitle { color: #808080; margin-bottom: 32px; font-size: 1.05rem; }

        .auth-card {
            background: #3c3f41;
            border-radius: 8px;
            padding: 36px 32px;
            border: 1px solid #555555;
            text-align: left;
        }

        .step-progress {
            display: flex;
            justify-content: center;
            gap: 10px;
            margin-bottom: 28px;
        }
        .step {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: #4e5254;
            transition: all 0.4s ease;
        }
        .step.active { background: #9d001e; transform: scale(1.3); box-shadow: 0 0 12px rgba(157,0,30,0.4); }
        .step.done { background: #6a8759; }
        .step-connector {
            width: 36px;
            height: 2px;
            background: #4e5254;
            align-self: center;
        }
        .step-connector.active { background: linear-gradient(90deg, #6a8759, #9d001e); }

        .action-btn {
            display: inline-flex;
            align-items: center;
            gap: 10px;
            background: #9d001e;
            color: #a9b7c6;
            padding: 14px 32px;
            border-radius: 6px;
            font-size: 1rem;
            font-weight: 600;
            text-decoration: none;
            cursor: pointer;
            border: none;
            transition: all 0.2s ease;
            box-shadow: 0 4px 20px rgba(157,0,30,0.25);
        }
        .action-btn:hover {
            background: #c4002a;
            transform: translateY(-2px);
            box-shadow: 0 6px 28px rgba(157,0,30,0.4);
        }
        .action-btn svg { width: 22px; height: 22px; }

        .guide {
            margin-top: 24px;
            padding: 20px;
            background: #2b2b2b;
            border-radius: 6px;
            border: 1px solid #555555;
        }
        .guide h3 {
            color: #a9b7c6;
            margin-bottom: 12px;
            font-size: 0.95rem;
            display: flex;
            align-items: center;
            gap: 8px;
            font-weight: 600;
        }
        .guide ol {
            margin: 0;
            padding-left: 22px;
            color: #808080;
            font-size: 0.9rem;
            line-height: 1.7;
        }
        .guide li { margin-bottom: 6px; }
        .guide strong { color: #a9b7c6; font-weight: 500; }
        .guide .highlight {
            color: #d9a441;
            font-weight: 600;
        }

        .upload-zone {
            border: 2px dashed #555555;
            border-radius: 6px;
            padding: 36px 28px;
            margin-top: 20px;
            text-align: center;
            transition: all 0.3s ease;
            cursor: pointer;
            background: #2b2b2b;
        }
        .upload-zone:hover, .upload-zone.dragover {
            border-color: #6a8759;
            background: rgba(106,135,89,0.06);
        }
        .upload-zone p { color: #808080; font-size: 0.9rem; }
        .upload-zone .big { font-size: 2.2rem; margin-bottom: 8px; }

        .loading-overlay {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(43,43,43,0.95);
            z-index: 1000;
            flex-direction: column;
            align-items: center;
            justify-content: center;
        }
        .loading-overlay.active { display: flex; }
        .spinner {
            width: 48px;
            height: 48px;
            border: 3px solid #4e5254;
            border-top-color: #9d001e;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin { to { transform: rotate(360deg); } }
        .loading-text { margin-top: 16px; font-size: 1rem; color: #a9b7c6; }

        .features {
            display: flex;
            gap: 10px;
            justify-content: center;
            margin-top: 24px;
            flex-wrap: wrap;
        }
        .feature {
            background: #3c3f41;
            padding: 10px 18px;
            border-radius: 6px;
            font-size: 0.82rem;
            color: #808080;
            border: 1px solid #555555;
        }
        .feature span { color: #a9b7c6; }
        .footer {
            margin-top: 24px;
            color: #555555;
            font-size: 0.78rem;
        }

        input[type="file"] { display: none; }

        .step-content { display: none; }
        .step-content.active { display: block; }

        .success-view { text-align: center; }
        .success-view .icon { font-size: 3rem; margin-bottom: 12px; }
        .success-view h2 {
            font-size: 1.5rem;
            font-weight: 700;
            color: #a9b7c6;
            margin-bottom: 8px;
        }
        .success-view p {
            color: #808080;
            margin-bottom: 16px;
            font-size: 0.95rem;
        }
        .dash-link {
            display: inline-block;
            padding: 10px 24px;
            background: rgba(157,0,30,0.12);
            color: #cc7832;
            border: 1px solid rgba(157,0,30,0.2);
            border-radius: 6px;
            text-decoration: none;
            font-weight: 600;
            font-size: 0.9rem;
            transition: all 0.2s;
        }
        .dash-link:hover {
            background: rgba(157,0,30,0.2);
        }

        .cookie-banner {
            margin-top: 16px;
            padding: 12px 16px;
            border-radius: 6px;
            font-size: 0.85rem;
            text-align: left;
        }
        .cookie-banner.stale {
            background: rgba(217,164,65,0.08);
            border: 1px solid rgba(217,164,65,0.2);
            color: #d9a441;
        }
        .cookie-banner.fresh {
            background: rgba(106,135,89,0.08);
            border: 1px solid rgba(106,135,89,0.2);
            color: #6a8759;
        }
        .cookie-banner strong { display: block; margin-bottom: 4px; font-weight: 600; }
        .cookie-banner a { color: inherit; text-decoration: underline; }

        .services { margin-top: 24px; text-align: left; }
        .services h3 {
            font-size: 0.9rem;
            color: #808080;
            margin-bottom: 12px;
            text-align: center;
            font-weight: 500;
        }
        .service-grid {
            display: flex;
            flex-direction: column;
            gap: 8px;
        }
        .service-card {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 12px 16px;
            background: #3c3f41;
            border: 1px solid #555555;
            border-radius: 6px;
            text-decoration: none;
            color: #808080;
            transition: all 0.2s ease;
            cursor: pointer;
        }
        .service-card:hover {
            background: #4e5254;
            border-color: #555555;
            transform: translateY(-1px);
        }
        .service-card.primary {
            border-color: rgba(157,0,30,0.3);
            background: rgba(157,0,30,0.06);
        }
        .service-card.primary:hover {
            border-color: rgba(157,0,30,0.4);
            background: rgba(157,0,30,0.1);
        }
        .service-card .s-icon { font-size: 18px; }
        .service-card .s-name {
            font-weight: 600;
            color: #a9b7c6;
            font-size: 0.9rem;
        }
        .service-card .s-port {
            font-size: 0.75rem;
            color: #555555;
            font-family: monospace;
            margin-left: auto;
        }
        .service-card .s-desc {
            width: 100%;
            font-size: 0.78rem;
            color: #808080;
            margin-top: 2px;
        }

        @media (max-width: 480px) {
            body { padding: 12px; }
            .logo-img { width: 72px; height: 72px; }
            h1 { font-size: 2rem; letter-spacing: -0.5px; }
            .subtitle { font-size: 0.95rem; margin-bottom: 20px; }
            .auth-card { padding: 20px; border-radius: 6px; }
            .action-btn { padding: 12px 20px; font-size: 0.95rem; max-width: 100%; flex-wrap: wrap; }
            .guide { padding: 14px; }
            .upload-zone { padding: 24px 16px; }
            .upload-zone .big { font-size: 1.8rem; }
            .service-card { flex-wrap: wrap; padding: 10px 12px; }
            .success-view .icon { font-size: 2.2rem; }
            .success-view h2 { font-size: 1.25rem; }
            .features { gap: 6px; }
            .feature { padding: 8px 12px; font-size: 0.75rem; }
        }
    </style>
</head>
<body>
    <div class="container">
        <img src="/logo.png" alt="Боба" class="logo-img">
        <h1>Боба</h1>
        <p class="subtitle">Universal Video Downloader — YouTube, Instagram, Facebook, X, TikTok, Bilibili & more</p>

        <div class="auth-card">
            <div class="step-progress">
                <div class="step active" id="step1"></div>
                <div class="step-connector" id="conn1"></div>
                <div class="step" id="step2"></div>
                <div class="step-connector" id="conn2"></div>
                <div class="step" id="step3"></div>
            </div>

            <!-- Step 1: Sign in to your platform -->
            <div class="step-content active" id="content1">
                <div style="text-align: center; margin-bottom: 20px;">
                    <button class="action-btn" onclick="goToStep(2)">
                        <svg viewBox="0 0 24 24" fill="currentColor">
                            <path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/>
                        </svg>
                        Sign In to Your Platform
                    </button>
                </div>

                <div class="guide">
                    <h3>📋 How it works</h3>
                    <ol>
                        <li>Open the site you want to download from in a normal browser tab
                            (YouTube, Instagram, Facebook, X / Twitter, TikTok, Bilibili, Threads, Reddit, …)</li>
                        <li><strong>Sign in</strong> to that site with your account</li>
                        <li>Come back to this page when done</li>
                        <li>Export your cookies using a browser extension</li>
                    </ol>
                    <p style="color: #808080; font-size: 0.85rem; margin-top: 10px;">
                        Tip: a single cookies.txt can contain entries for multiple sites — sign in to all of them
                        first, then export once.
                    </p>
                </div>
            </div>

            <!-- Step 2: Export Cookies -->
            <div class="step-content" id="content2">
                <p style="color: #808080; margin-bottom: 16px; font-size: 0.95rem;">
                    Great! Now export your session cookies for the platform(s) you signed in to.<br>
                    <strong style="color: #a9b7c6;">This is required</strong> to download login-walled or age-restricted videos.
                </p>

                <div class="guide">
                    <h3>🔧 Export Cookies (takes 30 seconds)</h3>
                    <ol>
                        <li>Install extension: <strong>Get cookies.txt</strong> for
                            <span class="highlight">Chrome</span> or
                            <span class="highlight">Firefox</span>
                        </li>
                        <li>Visit each site you signed in to (youtube.com, instagram.com, facebook.com,
                            x.com, tiktok.com, bilibili.com, threads.net, reddit.com, …) — make sure you are signed in</li>
                        <li>Click the extension icon in your browser toolbar</li>
                        <li>Click <strong>"Export"</strong> to download the cookies file</li>
                        <li>Drag that file below or click to upload</li>
                    </ol>
                </div>

                <div class="upload-zone" id="dropZone">
                    <div class="big">🍪</div>
                    <p>Drag & drop your cookies file here<br>or click to select file</p>
                    <input type="file" id="cookieFile" accept=".txt">
                </div>
            </div>

            <!-- Step 3: Success -->
            <div class="step-content success-view" id="content3">
                <div class="icon">🎉</div>
                <h2>You're All Set!</h2>
                <p>Redirecting you to the Боба Dashboard...</p>
                <a href="/app" class="dash-link" id="dashLink">→ Open Dashboard</a>

                <div id="cookieBanner" class="cookie-banner" style="display:none;"></div>

                <div class="services">
                    <h3>🚀 Available Services</h3>
                    <div class="service-grid">
                        <a class="service-card primary" href="{{ dashboard_url }}" target="_blank">
                            <span class="s-icon">📊</span>
                            <span class="s-name">Боба Dashboard</span>
                            <span class="s-port">:9090</span>
                            <span class="s-desc">Modern Angular UI — recommended</span>
                        </a>
                        <a class="service-card" href="{{ metube_url }}" target="_blank">
                            <span class="s-icon">🎬</span>
                            <span class="s-name">Classic UI</span>
                            <span class="s-port">:8088</span>
                            <span class="s-desc">Original MeTube web interface</span>
                        </a>
                        <a class="service-card" href="{{ dashboard_url }}/api/history" target="_blank">
                            <span class="s-icon">📡</span>
                            <span class="s-name">MeTube API</span>
                            <span class="s-port">/api</span>
                            <span class="s-desc">JSON API endpoint</span>
                        </a>
                    </div>
                </div>
            </div>
        </div>

        <div class="features">
            <div class="feature">🎥 <span>HD Video</span></div>
            <div class="feature">🎵 <span>Audio Only</span></div>
            <div class="feature">📝 <span>Subtitles</span></div>
        </div>

        <p class="footer">Боба — powered by yt-dlp & MeTube</p>
    </div>

    <div class="loading-overlay" id="loadingOverlay">
        <div class="spinner"></div>
        <p class="loading-text" id="loadingText">Please wait...</p>
    </div>

    <script>
        const METUBE_URL = '{{ metube_url }}';
        const DASHBOARD_URL = '{{ dashboard_url }}';
        const BASE_URL = window.location.origin;
        let currentStep = 1;
        const SESSION = '{{ session_id }}';

        function showLoading(text) {
            document.getElementById('loadingText').textContent = text;
            document.getElementById('loadingOverlay').classList.add('active');
        }
        function hideLoading() {
            document.getElementById('loadingOverlay').classList.remove('active');
        }

        function goToStep(n) {
            currentStep = n;

            for (let i = 1; i <= 3; i++) {
                document.getElementById('step' + i).className = 'step';
                document.getElementById('content' + i).classList.remove('active');
                if (i < 3) document.getElementById('conn' + i).className = 'step-connector';
            }

            for (let i = 1; i < n; i++) {
                document.getElementById('step' + i).classList.add('done');
                if (i < 3) document.getElementById('conn' + i).classList.add('active');
            }
            document.getElementById('step' + n).classList.add('active');
            document.getElementById('content' + n).classList.add('active');

            if (n === 2) {
                // Step 1's button now leads to "Sign In to Your Platform" (not just YouTube),
                // so we no longer auto-open youtube.com. Users open whichever site(s) they
                // need to sign in to themselves.
                setupUpload();
            }

            if (n === 3) {
                document.getElementById('dashLink').href = DASHBOARD_URL;
            }
        }

        function setupUpload() {
            const zone = document.getElementById('dropZone');
            const input = document.getElementById('cookieFile');

            zone.addEventListener('click', () => input.click());

            zone.addEventListener('dragover', (e) => {
                e.preventDefault();
                zone.classList.add('dragover');
            });
            zone.addEventListener('dragleave', () => zone.classList.remove('dragover'));
            zone.addEventListener('drop', (e) => {
                e.preventDefault();
                zone.classList.remove('dragover');
                if (e.dataTransfer.files[0]) uploadFile(e.dataTransfer.files[0]);
            });

            input.addEventListener('change', () => {
                if (input.files[0]) uploadFile(input.files[0]);
            });
        }

        async function uploadFile(file) {
            showLoading('Uploading cookies...');

            const formData = new FormData();
            formData.append('session', SESSION);
            formData.append('cookies', file);

            try {
                const resp = await fetch('/api/upload-cookies', {
                    method: 'POST',
                    body: formData
                });
                const data = await resp.json();

                if (data.success) {
                    goToStep(3);
                    showLoading('Success! Redirecting to Dashboard...');
                    setTimeout(() => window.location.href = DASHBOARD_URL, 1500);
                } else {
                    hideLoading();
                    alert('Upload failed: ' + (data.error || 'Unknown error'));
                }
            } catch (e) {
                hideLoading();
                alert('Error: ' + e.message);
            }
        }

        async function checkAuth() {
            try {
                const resp = await fetch('/api/cookie-status');
                const data = await resp.json();
                if (data.has_cookies && data.metube_reachable) {
                    goToStep(3);
                    showCookieBanner(data);
                    showLoading('Redirecting to Dashboard...');
                    setTimeout(() => window.location.href = DASHBOARD_URL, 2500);
                }
            } catch (e) {
                console.log('Auth check failed');
            }
        }

        function showCookieBanner(data) {
            const banner = document.getElementById('cookieBanner');
            if (!banner) return;
            const ageMin = data.cookie_age_minutes || 0;
            if (ageMin > 60) {
                banner.className = 'cookie-banner stale';
                banner.innerHTML = `
                    <strong>⚠ Your cookies are ${Math.round(ageMin)} minutes old</strong>
                    Session cookies (especially YouTube and Instagram) expire quickly.
                    If downloads fail with auth prompts like "Sign in to confirm you're not a bot",
                    <a href="#" onclick="goToStep(2); return false;">export fresh cookies</a> and re-upload.
                `;
            } else {
                banner.className = 'cookie-banner fresh';
                banner.innerHTML = `<strong>✅ Cookies look fresh (${Math.round(ageMin)} min old)</strong>`;
            }
            banner.style.display = 'block';
        }

        checkAuth();
    </script>
</body>
</html>
"""


@app.route("/")
def index():
    session_id = str(uuid.uuid4())
    app.sessions[session_id] = {"created": time.time()}
    import re

    me_port = os.environ.get("METUBE_PUBLIC_PORT", "8088")
    dashboard_port = os.environ.get("DASHBOARD_PORT", "9090")
    host = request.host_url.rstrip("/") if request.host_url else f"http://localhost"
    match = re.search(r":(\d+)$", host)
    if match:
        landing_port = match.group(1)
        metube_url = host.replace(f":{landing_port}", f":{me_port}")
        dashboard_url = host.replace(f":{landing_port}", f":{dashboard_port}")
    else:
        metube_url = f"http://localhost:{me_port}"
        dashboard_url = f"http://localhost:{dashboard_port}"
    return render_template_string(
        INDEX_TEMPLATE, session_id=session_id, metube_url=metube_url,
        dashboard_url=dashboard_url
    )


@app.route("/app")
def proxy():
    target_url = METUBE_URL
    if request.query_string:
        target_url = f"{METUBE_URL}?{request.query_string.decode()}"
    try:
        resp = requests.get(target_url, stream=True, timeout=10)
        response = make_response(resp.content)
        response.headers["Content-Type"] = resp.headers.get("Content-Type", "text/html")
        return response
    except Exception as e:
        return f"Error connecting to MeTube backend: {e}", 502


def _validate_cookie_file(content: str) -> tuple[bool, str]:
    """Validate Netscape cookie file format and contents.

    Returns (is_valid, error_message).
    """
    lines = content.strip().splitlines()
    if not lines:
        return False, "Cookie file is empty"

    # Check header
    if not lines[0].startswith("# Netscape HTTP Cookie File"):
        return False, "Invalid cookie file format — must be a Netscape HTTP Cookie File"

    # Count valid cookie lines (skip comments and empty lines)
    valid_domains = set()
    for line in lines[1:]:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 7:
            continue
        domain = parts[0].lstrip(".")
        valid_domains.add(domain.lower())

    if not valid_domains:
        return False, "Cookie file contains no valid cookie entries"

    # Warn if no recognised video-platform domains are present.
    # Each entry is a substring matched against the cookie's domain
    # (leading dot stripped) so e.g. "facebook.com" matches
    # ".facebook.com" and ".m.facebook.com".
    recognised = {
        # YouTube + Google session domains (Google sign-in cookies cover YT)
        "youtube.com", "youtu.be", "google.com",
        # General-purpose video platforms
        "vimeo.com", "dailymotion.com", "twitch.tv",
        "rumble.com", "peertube.tv",
        # Social platforms with embedded video
        "instagram.com", "reddit.com",
        "facebook.com", "fb.watch",
        "twitter.com", "x.com", "threads.net",
        "tiktok.com",
        # Russian / Chinese platforms
        "vk.com", "vkvideo.ru",
        "bilibili.com", "bilibili.tv",
        # Audio platforms (yt-dlp covers these too)
        "soundcloud.com", "bandcamp.com",
    }
    has_recognised = any(
        any(rd in domain for rd in recognised)
        for domain in valid_domains
    )
    if not has_recognised:
        return False, (
            "Cookie file does not contain cookies for any recognised video platform. "
            "Export cookies while signed in to the site you want to download from. "
            f"Found domains: {', '.join(sorted(valid_domains)[:5])}"
        )

    return True, ""


# Mapping from a recognised-domain substring to the canonical platform
# key surfaced in /api/cookie-status. Keep in sync with the recognised
# set in _validate_cookie_file. The drift gate
# scripts/check-recognised-domains-sync.sh asserts validator ↔ OpenAPI;
# this mapping is for breakdown labelling only.
_PLATFORM_FOR_DOMAIN = {
    "youtube.com": "youtube", "youtu.be": "youtube", "google.com": "youtube",
    "vimeo.com": "vimeo",
    "dailymotion.com": "dailymotion",
    "twitch.tv": "twitch",
    "rumble.com": "rumble",
    "peertube.tv": "peertube",
    "instagram.com": "instagram",
    "reddit.com": "reddit",
    "facebook.com": "facebook", "fb.watch": "facebook",
    "twitter.com": "x", "x.com": "x",
    "threads.net": "threads",
    "tiktok.com": "tiktok",
    "vk.com": "vk", "vkvideo.ru": "vk",
    "bilibili.com": "bilibili", "bilibili.tv": "bilibili",
    "soundcloud.com": "soundcloud",
    "bandcamp.com": "bandcamp",
}


def _summarize_cookies_by_platform(content: str) -> dict:
    """Group Netscape cookie entries by canonical platform.

    Returns a dict keyed by platform name (e.g. "youtube", "tiktok"),
    each value containing:
        domains_present: sorted list of distinct cookie domains
        session_count:   number of cookie lines
        max_expiry_unix: latest expiry epoch in the bucket (or 0 if none)
        min_expiry_unix: earliest non-zero expiry epoch in the bucket

    Cookies whose domain doesn't match any recognised platform are
    silently dropped — they may still be present in the file (the
    validator accepts the file as long as ONE recognised domain is
    present), but they don't contribute to platform breakdowns.
    """
    buckets: dict = {}
    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 7:
            continue
        domain = parts[0].lstrip(".").lower()
        try:
            expiry = int(parts[4])
        except (ValueError, IndexError):
            expiry = 0

        platform = None
        for needle, key in _PLATFORM_FOR_DOMAIN.items():
            if needle in domain:
                platform = key
                break
        if platform is None:
            continue

        b = buckets.setdefault(platform, {
            "domains_present": set(),
            "session_count": 0,
            "max_expiry_unix": 0,
            "min_expiry_unix": 0,
        })
        b["domains_present"].add("." + domain)
        b["session_count"] += 1
        if expiry > b["max_expiry_unix"]:
            b["max_expiry_unix"] = expiry
        if expiry > 0 and (b["min_expiry_unix"] == 0 or expiry < b["min_expiry_unix"]):
            b["min_expiry_unix"] = expiry

    # Convert sets to sorted lists for JSON serialisation.
    for b in buckets.values():
        b["domains_present"] = sorted(b["domains_present"])
    return buckets


@app.route("/api/upload-cookies", methods=["POST"])
def upload_cookies():
    try:
        if "cookies" not in request.files:
            return jsonify({"success": False, "error": "No file provided"}), 400

        file = request.files["cookies"]
        raw = file.read()
        try:
            content = raw.decode("utf-8")
        except UnicodeDecodeError as ude:
            # Non-UTF-8 byte stream is bad client input, not a server fault.
            # Netscape cookies.txt is plain ASCII text — anything that can't
            # decode as UTF-8 is either binary, an encoded archive, or a
            # truncated upload. Return 400 with a clear message instead of
            # falling through to the bare-except 500 below.
            return jsonify({
                "success": False,
                "error": (
                    f"Cookie file is not valid UTF-8 text "
                    f"({ude.reason} at byte {ude.start}). "
                    "Netscape cookies.txt must be plain UTF-8 / ASCII. "
                    "Re-export from your browser extension."
                ),
            }), 400

        is_valid, error_msg = _validate_cookie_file(content)
        if not is_valid:
            return jsonify({"success": False, "error": error_msg}), 400

        files = {"cookies": (file.filename, content, "text/plain")}
        resp = requests.post(f"{METUBE_URL}/upload-cookies", files=files, timeout=30)

        if resp.status_code == 200:
            return jsonify({"success": True})
        else:
            return jsonify({"success": False, "error": resp.text}), resp.status_code
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/delete-cookies", methods=["POST"])
def delete_cookies():
    """Delete the current cookie file."""
    try:
        cookie_path = "/config/cookies.txt"
        if os.path.exists(cookie_path):
            os.remove(cookie_path)
            return jsonify({"success": True, "msg": "Cookies deleted"})
        return jsonify({"success": True, "msg": "No cookies to delete"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/cookie-status")
def cookie_status():
    """Return cookie status including freshness and per-platform breakdown.

    Backward-compatible: the existing `has_cookies`, `metube_reachable`,
    `cookie_age_minutes` fields are unchanged. The new `platforms` field
    is a dict (possibly empty) keyed by canonical platform — see
    `_summarize_cookies_by_platform` for shape.
    """
    has_cookies = False
    cookie_age_minutes = 0
    platforms: dict = {}
    try:
        cookie_path = "/config/cookies.txt"
        if os.path.exists(cookie_path):
            has_cookies = True
            mtime = os.path.getmtime(cookie_path)
            cookie_age_minutes = (time.time() - mtime) / 60
            try:
                with open(cookie_path, "r", encoding="utf-8", errors="replace") as f:
                    platforms = _summarize_cookies_by_platform(f.read())
            except Exception:
                # Reading the file is best-effort; an unreadable file
                # still leaves `has_cookies=True` so the user can see
                # the file exists.
                platforms = {}
        else:
            # Fall back to MeTube API
            resp = requests.get(f"{METUBE_URL}/cookie-status", timeout=5)
            data = resp.json()
            has_cookies = data.get("has_cookies", False)
    except Exception:
        pass

    metube_reachable = False
    try:
        requests.get(f"{METUBE_URL}/history", timeout=3)
        metube_reachable = True
    except Exception:
        pass

    return jsonify({
        "has_cookies": has_cookies,
        "metube_reachable": metube_reachable,
        "cookie_age_minutes": round(cookie_age_minutes, 1),
        "platforms": platforms,
    })


@app.route("/api/profile-status")
def profile_status():
    """Report which compose profile is active (vpn / no-vpn / unknown).

    The compose file sets ACTIVE_PROFILE in the landing service's
    environment so this endpoint is authoritative for the running
    container. The dashboard surfaces this as a header badge so users
    know whether their downloads are tunneling through the VPN.
    """
    profile = os.environ.get("ACTIVE_PROFILE", "unknown")
    metube_url = os.environ.get("METUBE_URL", "")
    metube_reachable = False
    try:
        requests.get(f"{metube_url}/history", timeout=3)
        metube_reachable = True
    except Exception:
        pass
    return jsonify({
        "profile": profile,
        "vpn_active": profile == "vpn",
        "metube_url": metube_url,
        "metube_reachable": metube_reachable,
    })


@app.route("/health")
def health():
    """Health check endpoint for monitoring and smoke tests."""
    metube_ok = False
    try:
        resp = requests.get(f"{METUBE_URL}/history", timeout=3)
        metube_ok = resp.status_code == 200
    except Exception:
        pass

    return jsonify({
        "status": "ok",
        "service": "landing-page",
        "metube_reachable": metube_ok,
        "timestamp": time.time(),
    })


@app.route("/logo.png")
def logo():
    return send_from_directory(os.path.dirname(os.path.abspath(__file__)), "logo.png", mimetype="image/png")


@app.route("/favicon.ico")
def favicon():
    return "", 204


DOWNLOAD_DIR = os.environ.get("DOWNLOAD_DIR", "/downloads")


@app.route("/api/delete-download", methods=["POST"])
def delete_download():
    """Remove item from history and optionally delete downloaded files."""
    try:
        data = request.get_json() or {}
        # MeTube's /delete endpoint uses the download URL as the queue key,
        # so we must receive and send the URL (not the video id).
        item_url = data.get("url")
        title = data.get("title", "")
        folder = data.get("folder", "")
        delete_file = data.get("delete_file", False)

        if not item_url:
            return jsonify({"success": False, "error": "Missing url"}), 400

        # 1. Remove from history
        try:
            resp = requests.post(
                f"{METUBE_URL}/delete",
                json={"ids": [item_url], "where": "done"},
                timeout=10
            )
            history_deleted = resp.status_code == 200
        except Exception as e:
            return jsonify({"success": False, "error": f"Failed to remove from history: {e}"}), 500

        deleted_files = []
        if delete_file and title:
            # 2. Find and delete matching files
            target_dir = os.path.join(DOWNLOAD_DIR, folder) if folder else DOWNLOAD_DIR
            target_dir = os.path.abspath(target_dir)
            # Security: ensure we stay within DOWNLOAD_DIR
            if not target_dir.startswith(os.path.abspath(DOWNLOAD_DIR)):
                return jsonify({"success": False, "error": "Invalid folder path"}), 400

            if os.path.isdir(target_dir):
                # Search for files containing the title
                safe_title = "".join(c for c in title if c.isalnum() or c in " ._-").strip()
                for root, _dirs, files in os.walk(target_dir):
                    for fname in files:
                        # Match by title substring (case-insensitive) or exact url in filename
                        if safe_title.lower() in fname.lower() or item_url in fname:
                            fpath = os.path.join(root, fname)
                            try:
                                os.remove(fpath)
                                deleted_files.append(fname)
                            except Exception:
                                pass

        return jsonify({
            "success": True,
            "history_deleted": history_deleted,
            "files_deleted": deleted_files,
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


if __name__ == "__main__":
    print(f"Starting Боба Landing Page on port {PROXY_PORT}")
    print(f"MeTube backend URL: {METUBE_URL}")
    print(f"Download dir: {DOWNLOAD_DIR}")
    app.run(host="0.0.0.0", port=PROXY_PORT, debug=False)
