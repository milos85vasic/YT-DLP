import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { Subscription, timer } from 'rxjs';
import { switchMap, take } from 'rxjs/operators';
import { MetubeService, DownloadInfo } from '../../services/metube.service';

type TrackState = 'idle' | 'adding' | 'queued' | 'downloading' | 'finished' | 'error' | 'timeout';

@Component({
  selector: 'app-download-form',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  template: `
    <div class="page">
      <div class="card">
        <h2>⬇️ Add Download</h2>
        <div class="input-group">
          <label>Video URL</label>
          <input
            type="text"
            [(ngModel)]="url"
            placeholder="https://www.youtube.com/watch?v=..."
            (keydown.enter)="addDownload()"
            [disabled]="loading"
          />
        </div>

        <div class="row">
          <div class="input-group">
            <label>Quality</label>
            <select [(ngModel)]="quality" [disabled]="loading">
              <option value="best">Best</option>
              <option value="2160">4K (2160p)</option>
              <option value="1440">2K (1440p)</option>
              <option value="1080">1080p</option>
              <option value="720">720p</option>
              <option value="480">480p</option>
              <option value="360">360p</option>
              <option value="worst">Worst</option>
            </select>
          </div>
          <div class="input-group">
            <label>Format</label>
            <select [(ngModel)]="format" [disabled]="loading">
              <option value="any">Any</option>
              <option value="mp4">MP4</option>
              <option value="mp3">MP3 (audio)</option>
              <option value="m4a">M4A (audio)</option>
            </select>
          </div>
        </div>

        <div class="input-group">
          <label>Folder (optional)</label>
          <input
            type="text"
            [(ngModel)]="folder"
            placeholder="subfolder/name"
            [disabled]="loading"
          />
        </div>

        <button
          class="btn-primary"
          (click)="addDownload()"
          [disabled]="!url.trim() || loading"
        >
          <span *ngIf="!loading">Add to Queue</span>
          <span *ngIf="loading">Adding…</span>
        </button>

        <!-- Live tracking panel -->
        <div *ngIf="tracker.state !== 'idle'" class="tracker" [class.error]="tracker.state === 'error'" [class.success]="tracker.state === 'finished'">
          <div class="tracker-header">
            <span class="tracker-icon">
              <span *ngIf="tracker.state === 'adding'">⏳</span>
              <span *ngIf="tracker.state === 'queued'">📥</span>
              <span *ngIf="tracker.state === 'downloading'">⬇️</span>
              <span *ngIf="tracker.state === 'finished'">✅</span>
              <span *ngIf="tracker.state === 'error'">❌</span>
              <span *ngIf="tracker.state === 'timeout'">⏱️</span>
            </span>
            <span class="tracker-title">{{ trackerTitle }}</span>
          </div>
          <div *ngIf="tracker.item?.title" class="tracker-subtitle">{{ tracker.item?.title }}</div>

          <!-- Bot detection / cookie error -->
          <div *ngIf="isBotError" class="tracker-hint bot">
            <strong>🔒 YouTube bot detection triggered</strong>
            <p>YouTube requires fresh browser cookies for this video.</p>
            <ol>
              <li>Open the <a href="http://localhost:8086" target="_blank">Landing Page</a></li>
              <li>Sign in to YouTube in your browser</li>
              <li>Export fresh cookies using the "Get cookies.txt" extension</li>
              <li>Upload via the Landing Page</li>
              <li>Return here and retry</li>
            </ol>
            <p class="hint-small">Cookies expire quickly — always export them right before downloading.</p>
          </div>

          <!-- Stale cookies error -->
          <div *ngIf="isStaleCookieError" class="tracker-hint stale">
            <strong>🍪 Your cookies have expired</strong>
            <p>YouTube rotated your session cookies as a security measure.</p>
            <p>Go to the <a href="http://localhost:8086" target="_blank">Landing Page</a> to export fresh cookies and retry.</p>
          </div>

          <!-- Generic error message -->
          <div *ngIf="tracker.item?.msg && !isBotError && !isStaleCookieError" class="tracker-msg">{{ tracker.item?.msg }}</div>

          <div *ngIf="tracker.item?.status === 'error' && !isBotError && !isStaleCookieError" class="tracker-actions">
            <button class="btn-retry" (click)="retryTracked()">↻ Retry</button>
            <a routerLink="/history" class="link-history">View in History →</a>
          </div>
          <div *ngIf="tracker.item?.status === 'finished'" class="tracker-actions">
            <span class="tracker-filename" *ngIf="tracker.item?.filename">📁 {{ tracker.item?.filename }}</span>
            <a routerLink="/history" class="link-history">View in History →</a>
          </div>
        </div>
      </div>

      <div class="card platforms">
        <h3>✅ Supported Platforms</h3>
        <div class="platform-grid">
          <div class="platform" *ngFor="let p of platforms" [class.ok]="p.ok" [class.warn]="!p.ok">
            <span class="icon">{{ p.icon }}</span>
            <span class="name">{{ p.name }}</span>
            <span class="badge" *ngIf="p.ok">✓</span>
            <span class="badge" *ngIf="!p.ok">⚠</span>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .page { padding: 24px; max-width: 720px; margin: 0 auto; }
    .card {
      background: rgba(255,255,255,0.04);
      border: 1px solid rgba(255,255,255,0.08);
      border-radius: 16px;
      padding: 28px;
      margin-bottom: 20px;
    }
    h2 { margin: 0 0 20px; font-size: 20px; color: #fff; }
    h3 { margin: 0 0 16px; font-size: 16px; color: #ddd; }
    .input-group { margin-bottom: 16px; }
    .input-group label {
      display: block;
      font-size: 12px;
      color: #888;
      margin-bottom: 6px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .input-group input, .input-group select {
      width: 100%;
      padding: 10px 14px;
      background: rgba(0,0,0,0.25);
      border: 1px solid rgba(255,255,255,0.1);
      border-radius: 10px;
      color: #fff;
      font-size: 14px;
      outline: none;
      transition: border-color 0.2s;
    }
    .input-group input:focus, .input-group select:focus {
      border-color: #ff0050;
    }
    .input-group input::placeholder { color: #555; }
    .row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
    .btn-primary {
      width: 100%;
      padding: 12px;
      background: linear-gradient(90deg, #ff0050, #ff3366);
      border: none;
      border-radius: 10px;
      color: #fff;
      font-size: 15px;
      font-weight: 600;
      cursor: pointer;
      transition: opacity 0.2s;
    }
    .btn-primary:hover:not(:disabled) { opacity: 0.9; }
    .btn-primary:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }
    .tracker {
      margin-top: 16px;
      padding: 14px 16px;
      background: rgba(0,150,255,0.06);
      border: 1px solid rgba(0,150,255,0.15);
      border-radius: 12px;
    }
    .tracker.error {
      background: rgba(255,0,80,0.06);
      border-color: rgba(255,0,80,0.2);
    }
    .tracker.success {
      background: rgba(0,255,136,0.06);
      border-color: rgba(0,255,136,0.2);
    }
    .tracker-header {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .tracker-icon { font-size: 18px; }
    .tracker-title {
      font-size: 14px;
      font-weight: 600;
      color: #fff;
    }
    .tracker-subtitle {
      margin-top: 6px;
      font-size: 13px;
      color: #ccc;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .tracker-msg {
      margin-top: 8px;
      padding: 8px 12px;
      background: rgba(255,0,80,0.08);
      border-radius: 8px;
      font-size: 12px;
      color: #ff5588;
      font-family: monospace;
      white-space: pre-wrap;
      word-break: break-word;
    }
    .tracker-hint {
      margin-top: 10px;
      padding: 12px 14px;
      border-radius: 10px;
      font-size: 13px;
    }
    .tracker-hint.bot {
      background: rgba(255,200,0,0.08);
      border: 1px solid rgba(255,200,0,0.2);
      color: #ffcc66;
    }
    .tracker-hint.stale {
      background: rgba(255,150,0,0.08);
      border: 1px solid rgba(255,150,0,0.2);
      color: #ffaa55;
    }
    .tracker-hint strong {
      display: block;
      margin-bottom: 6px;
      font-size: 14px;
    }
    .tracker-hint ol {
      margin: 8px 0;
      padding-left: 20px;
      line-height: 1.7;
    }
    .tracker-hint a {
      color: #66b3ff;
      text-decoration: underline;
    }
    .hint-small {
      margin-top: 8px;
      font-size: 11px;
      color: #888;
    }
    .tracker-actions {
      margin-top: 10px;
      display: flex;
      align-items: center;
      gap: 12px;
      flex-wrap: wrap;
    }
    .btn-retry {
      padding: 6px 14px;
      border-radius: 8px;
      border: none;
      background: rgba(0,255,136,0.12);
      color: #00ff88;
      cursor: pointer;
      font-size: 13px;
      font-weight: 600;
    }
    .btn-retry:hover { background: rgba(0,255,136,0.25); }
    .link-history {
      color: #66b3ff;
      text-decoration: none;
      font-size: 13px;
    }
    .link-history:hover { text-decoration: underline; }
    .tracker-filename {
      font-size: 11px;
      color: #666;
      font-family: monospace;
    }
    .platform-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
      gap: 10px;
    }
    .platform {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 10px 12px;
      background: rgba(0,0,0,0.2);
      border-radius: 10px;
      font-size: 13px;
    }
    .platform.ok { border: 1px solid rgba(0,255,136,0.15); }
    .platform.warn { border: 1px solid rgba(255,200,0,0.15); opacity: 0.7; }
    .platform .icon { font-size: 16px; }
    .platform .name { flex: 1; color: #ccc; }
    .platform .badge { font-size: 11px; }
  `],
})
export class DownloadFormComponent implements OnInit, OnDestroy {
  url = '';
  quality = 'best';
  format = 'any';
  folder = '';
  loading = false;

  tracker: { state: TrackState; item: DownloadInfo | null } = { state: 'idle', item: null };
  private trackSub?: Subscription;

  platforms = [
    { name: 'YouTube', icon: '📺', ok: true },
    { name: 'Vimeo', icon: '🎬', ok: true },
    { name: 'Dailymotion', icon: '▶️', ok: true },
    { name: 'Twitch', icon: '🎮', ok: true },
    { name: 'Instagram', icon: '📸', ok: true },
    { name: 'Reddit', icon: '🤖', ok: true },
    { name: 'Rumble', icon: '📡', ok: true },
    { name: 'VK', icon: '🇻🇰', ok: true },
    { name: 'PeerTube', icon: '🔭', ok: true },
    { name: 'SoundCloud', icon: '☁️', ok: true },
    { name: 'Bandcamp', icon: '🎵', ok: true },
    { name: 'TikTok', icon: '🎵', ok: false },
    { name: 'Bilibili', icon: '🇨🇳', ok: false },
    { name: 'Facebook', icon: '👤', ok: false },
  ];

  constructor(private metube: MetubeService) {}

  ngOnInit(): void {}

  ngOnDestroy(): void {
    this.trackSub?.unsubscribe();
  }

  get trackerTitle(): string {
    switch (this.tracker.state) {
      case 'adding': return 'Tracking download…';
      case 'queued': return 'In queue';
      case 'downloading': return 'Downloading';
      case 'finished': return 'Download complete!';
      case 'error': return 'Download failed';
      case 'timeout': return 'Still processing — check Queue/History';
      default: return '';
    }
  }

  get isBotError(): boolean {
    const msg = this.tracker.item?.msg || '';
    return msg.includes('not a bot') || msg.includes('Sign in to confirm');
  }

  get isStaleCookieError(): boolean {
    const msg = this.tracker.item?.msg || '';
    return msg.includes('no longer valid') || msg.includes('rotated in the browser');
  }

  addDownload(): void {
    if (!this.url.trim()) return;
    this.loading = true;
    this.tracker = { state: 'adding', item: null };
    this.trackSub?.unsubscribe();

    const submittedUrl = this.url.trim();

    this.metube
      .addDownload({
        url: submittedUrl,
        quality: this.quality,
        format: this.format,
        folder: this.folder.trim(),
      })
      .subscribe({
        next: (res) => {
          if (res.status !== 'ok') {
            this.loading = false;
            this.tracker = { state: 'error', item: { id: '', title: '', url: submittedUrl, quality: '', format: '', folder: '', status: 'error', msg: res.msg || 'Unknown error' } as DownloadInfo };
            return;
          }
          this.trackDownload(submittedUrl);
        },
        error: (err) => {
          this.loading = false;
          this.tracker = { state: 'error', item: { id: '', title: '', url: submittedUrl, quality: '', format: '', folder: '', status: 'error', msg: err.error?.msg || err.message || 'Network error' } as DownloadInfo };
        },
      });
  }

  private trackDownload(targetUrl: string): void {
    let attempts = 0;
    const maxAttempts = 30;

    this.trackSub = timer(0, 500).pipe(
      switchMap(() => this.metube.getHistory()),
      take(maxAttempts)
    ).subscribe({
      next: (data) => {
        attempts++;
        const all = [...(data.pending || []), ...(data.queue || []), ...(data.done || [])];
        const match = all.find((item) => item.url === targetUrl);

        if (match) {
          if (match.status === 'error') {
            this.loading = false;
            this.tracker = { state: 'error', item: match };
            this.trackSub?.unsubscribe();
          } else if (match.status === 'finished') {
            this.loading = false;
            this.tracker = { state: 'finished', item: match };
            this.trackSub?.unsubscribe();
          } else if (match.status === 'downloading') {
            this.tracker = { state: 'downloading', item: match };
          } else {
            this.tracker = { state: 'queued', item: match };
          }
        } else if (attempts >= maxAttempts) {
          this.loading = false;
          this.tracker = { state: 'timeout', item: null };
        }
      },
      error: () => {
        this.loading = false;
        this.tracker = { state: 'timeout', item: null };
      },
    });
  }

  retryTracked(): void {
    if (!this.tracker.item) return;
    this.url = this.tracker.item.url;
    this.tracker = { state: 'idle', item: null };
    this.addDownload();
  }
}
