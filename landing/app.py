#!/usr/bin/env python3
"""
MeTube Landing Page - Seamless YouTube Authentication
Flow: Open YouTube → Sign in → Export cookies → Auto-redirect to MeTube
"""

import os
import uuid
import time
from flask import Flask, render_template_string, request, jsonify, make_response
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
    <title>MeTube - YouTube Downloader</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            color: #fff;
            padding: 20px;
        }
        .container { text-align: center; max-width: 550px; width: 100%; }
        .logo { font-size: 80px; margin-bottom: 10px; }
        h1 {
            font-size: 3rem;
            margin-bottom: 5px;
            background: linear-gradient(90deg, #ff0050, #ffcc00);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .subtitle { color: #888; margin-bottom: 35px; font-size: 1.1rem; }
        
        .auth-card {
            background: rgba(255,255,255,0.05);
            border-radius: 20px;
            padding: 45px 40px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.1);
        }
        
        .step-progress {
            display: flex;
            justify-content: center;
            gap: 12px;
            margin-bottom: 35px;
        }
        .step {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: rgba(255,255,255,0.15);
            transition: all 0.4s ease;
        }
        .step.active { background: #ff0050; transform: scale(1.4); box-shadow: 0 0 15px rgba(255,0,80,0.5); }
        .step.done { background: #00ff88; }
        .step-connector {
            width: 40px;
            height: 2px;
            background: rgba(255,255,255,0.15);
            align-self: center;
        }
        .step-connector.active { background: linear-gradient(90deg, #00ff88, #ff0050); }
        
        .action-btn {
            display: inline-flex;
            align-items: center;
            gap: 12px;
            background: #ff0000;
            color: #fff;
            padding: 18px 40px;
            border-radius: 50px;
            font-size: 1.25rem;
            font-weight: 600;
            text-decoration: none;
            cursor: pointer;
            border: none;
            transition: all 0.3s ease;
            box-shadow: 0 4px 25px rgba(255,0,0,0.35);
        }
        .action-btn:hover {
            transform: translateY(-3px);
            box-shadow: 0 8px 35px rgba(255,0,0,0.5);
        }
        .action-btn svg { width: 26px; height: 26px; }
        
        .guide {
            text-align: left;
            margin-top: 30px;
            padding: 25px;
            background: rgba(0,0,0,0.25);
            border-radius: 16px;
            border: 1px solid rgba(255,255,255,0.05);
        }
        .guide h3 {
            color: #fff;
            margin-bottom: 15px;
            font-size: 1rem;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .guide ol {
            margin: 0;
            padding-left: 25px;
            color: #aaa;
            font-size: 0.95rem;
            line-height: 1.8;
        }
        .guide li { margin-bottom: 8px; }
        .guide strong { color: #fff; }
        .guide .highlight { color: #ff0050; font-weight: 600; }
        
        .upload-zone {
            border: 2px dashed rgba(255,255,255,0.2);
            border-radius: 16px;
            padding: 40px 30px;
            margin-top: 25px;
            transition: all 0.3s ease;
            cursor: pointer;
        }
        .upload-zone:hover, .upload-zone.dragover {
            border-color: #00ff88;
            background: rgba(0,255,136,0.05);
        }
        .upload-zone p { color: #888; font-size: 0.95rem; }
        .upload-zone .big { font-size: 2.5rem; margin-bottom: 10px; }
        
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
                window.open('https://www.youtube.com/', '_blank');
                setupUpload();
            }
            
            if (n === 3) {
                document.getElementById('metubeLink').href = BASE_URL + '/app';
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
                    showLoading('Success! Redirecting...');
                    setTimeout(() => window.location.href = METUBE_URL, 1500);
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
                    showLoading('Already authenticated! Redirecting...');
                    setTimeout(() => window.location.href = BASE_URL + '/app', 800);
                }
            } catch (e) {
                console.log('Auth check failed');
            }
        }
        
        checkAuth();
        
        .loading-overlay {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(0,0,0,0.88);
            z-index: 1000;
            flex-direction: column;
            align-items: center;
            justify-content: center;
        }
        .loading-overlay.active { display: flex; }
        .spinner {
            width: 55px;
            height: 55px;
            border: 4px solid rgba(255,255,255,0.1);
            border-top-color: #ff0050;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin { to { transform: rotate(360deg); } }
        .loading-text { margin-top: 18px; font-size: 1.15rem; color: #fff; }
        
        .features { display: flex; gap: 12px; justify-content: center; margin-top: 30px; flex-wrap: wrap; }
        .feature { background: rgba(255,255,255,0.05); padding: 12px 20px; border-radius: 10px; font-size: 0.85rem; color: #888; }
        .feature span { color: #fff; }
        .footer { margin-top: 30px; color: #555; font-size: 0.8rem; }
        
        input[type="file"] { display: none; }
        
        .step-content { display: none; }
        .step-content.active { display: block; }
        
        .cookie-banner {
            margin-bottom: 20px;
            padding: 14px 18px;
            border-radius: 12px;
            font-size: 0.9rem;
            text-align: left;
        }
        .cookie-banner.stale {
            background: rgba(255,200,0,0.08);
            border: 1px solid rgba(255,200,0,0.2);
            color: #ffcc66;
        }
        .cookie-banner.fresh {
            background: rgba(0,255,136,0.06);
            border: 1px solid rgba(0,255,136,0.15);
            color: #00ff88;
        }
        .cookie-banner strong { display: block; margin-bottom: 4px; }
        .cookie-banner a { color: inherit; text-decoration: underline; }
        .services { margin-top: 28px; text-align: left; }
        .services h3 {
            font-size: 0.95rem;
            color: #aaa;
            margin-bottom: 14px;
            text-align: center;
        }
        .service-grid {
            display: flex;
            flex-direction: column;
            gap: 10px;
        }
        .service-card {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 12px 16px;
            background: rgba(255,255,255,0.05);
            border: 1px solid rgba(255,255,255,0.08);
            border-radius: 12px;
            text-decoration: none;
            color: #ccc;
            transition: all 0.2s ease;
            cursor: pointer;
        }
        .service-card:hover {
            background: rgba(255,255,255,0.1);
            border-color: rgba(255,255,255,0.15);
            transform: translateY(-1px);
        }
        .service-card.primary {
            border-color: rgba(255,0,80,0.25);
            background: rgba(255,0,80,0.06);
        }
        .service-card.primary:hover {
            border-color: rgba(255,0,80,0.4);
            background: rgba(255,0,80,0.1);
        }
        .service-card .s-icon { font-size: 20px; }
        .service-card .s-name {
            font-weight: 600;
            color: #fff;
            font-size: 0.95rem;
        }
        .service-card .s-port {
            font-size: 0.8rem;
            color: #888;
            font-family: monospace;
            margin-left: auto;
        }
        .service-card .s-desc {
            width: 100%;
            font-size: 0.8rem;
            color: #888;
            margin-top: 2px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🎬</div>
        <h1>MeTube</h1>
        <p class="subtitle">YouTube Video Downloader</p>
        
        <div class="auth-card">
            <div class="step-progress">
                <div class="step active" id="step1"></div>
                <div class="step-connector" id="conn1"></div>
                <div class="step" id="step2"></div>
                <div class="step-connector" id="conn2"></div>
                <div class="step" id="step3"></div>
            </div>
            
            <!-- Step 1: Open YouTube -->
            <div class="step-content active" id="content1">
                <button class="action-btn" onclick="goToStep(2)">
                    <svg viewBox="0 0 24 24" fill="currentColor">
                        <path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/>
                    </svg>
                    Open YouTube & Sign In
                </button>
                
                <div class="guide">
                    <h3>📋 How it works:</h3>
                    <ol>
                        <li>Click the button above to open YouTube</li>
                        <li><strong>Sign in to your Google account</strong> on YouTube</li>
                        <li>Come back to this page when done</li>
                        <li>You'll need to export your cookies using a browser extension</li>
                    </ol>
                </div>
            </div>
            
            <!-- Step 2: Export Cookies -->
            <div class="step-content" id="content2">
                <p style="color: #888; margin-bottom: 20px;">
                    Great! Now you need to export your YouTube cookies.<br>
                    <strong style="color: #fff;">This is required</strong> to download videos.
                </p>
                
                <div class="guide">
                    <h3>🔧 Export Cookies (takes 30 seconds):</h3>
                    <ol>
                        <li>Install extension: <strong>Get cookies.txt</strong> for 
                            <span class="highlight">Chrome</span> or 
                            <span class="highlight">Firefox</span>
                        </li>
                        <li>Go to <strong>youtube.com</strong> (make sure you're signed in)</li>
                        <li>Click the extension icon in your browser toolbar</li>
                        <li>Click <strong>"Export"</strong> to download cookies file</li>
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
                <p>Redirecting you to the YT-DLP Dashboard...</p>
                <a href="/app" class="metube-link" id="metubeLink">→ Open Dashboard</a>

                <div id="cookieBanner" class="cookie-banner" style="display:none;margin-top:16px;"></div>

                <div class="services">
                    <h3>🚀 Available Services</h3>
                    <div class="service-grid">
                        <a class="service-card primary" href="{{ dashboard_url }}" target="_blank">
                            <span class="s-icon">📊</span>
                            <span class="s-name">YT-DLP Dashboard</span>
                            <span class="s-port">:9090</span>
                            <span class="s-desc">Modern Angular UI — recommended</span>
                        </a>
                        <a class="service-card" href="{{ metube_url }}" target="_blank">
                            <span class="s-icon">🎬</span>
                            <span class="s-name">MeTube Classic</span>
                            <span class="s-port">:8088</span>
                            <span class="s-desc">Original web interface</span>
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
        
        <p class="footer">YT-DLP Landing Page</p>
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
                window.open('https://www.youtube.com/', '_blank');
                setupUpload();
            }
            
            if (n === 3) {
                document.getElementById('metubeLink').href = DASHBOARD_URL;
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
                    // Show cookie freshness banner instead of auto-redirecting
                    hideLoading();
                    showCookieBanner(data);
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
                    YouTube cookies expire quickly. If downloads fail with "Sign in to confirm you're not a bot",
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
        return f"Error connecting to MeTube: {e}", 502


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

    # Warn if no recognised video-platform domains are present
    recognised = {
        "youtube.com", "youtu.be", "google.com",
        "vimeo.com", "dailymotion.com", "twitch.tv",
        "instagram.com", "reddit.com", "rumble.com",
        "vk.com", "vkvideo.ru", "peertube.tv",
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


@app.route("/api/upload-cookies", methods=["POST"])
def upload_cookies():
    try:
        if "cookies" not in request.files:
            return jsonify({"success": False, "error": "No file provided"}), 400

        file = request.files["cookies"]
        content = file.read().decode("utf-8")

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


@app.route("/api/cookie-status")
def cookie_status():
    """Return cookie status including freshness (age in minutes)."""
    has_cookies = False
    cookie_age_minutes = 0
    try:
        # Check the cookie file directly for age info
        cookie_path = "/config/cookies.txt"
        if os.path.exists(cookie_path):
            has_cookies = True
            mtime = os.path.getmtime(cookie_path)
            cookie_age_minutes = (time.time() - mtime) / 60
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
    })


@app.route("/favicon.ico")
def favicon():
    return "", 204


if __name__ == "__main__":
    print(f"Starting MeTube Landing Page on port {PROXY_PORT}")
    print(f"MeTube URL: {METUBE_URL}")
    app.run(host="0.0.0.0", port=PROXY_PORT, debug=False)
