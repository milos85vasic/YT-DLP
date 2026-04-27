import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Subscription } from 'rxjs';
import { MetubeService, PlatformCookieBucket } from '../../services/metube.service';

interface PlatformRow {
  key: string;
  display: string;
  icon: string;
  bucket: PlatformCookieBucket;
  status: 'fresh' | 'expiring' | 'expired';
  expiryHint: string;
}

@Component({
  selector: 'app-cookies',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="page">
      <h1 class="page-title">🍪 Cookie Management</h1>

      <!-- Loading -->
      <div *ngIf="loading" class="loading">
        <div class="spinner"></div>
        <p>Checking cookie status...</p>
      </div>

      <!-- Error -->
      <div *ngIf="error" class="error-state">
        <p>⚠️ {{ error }}</p>
        <button class="btn-retry" (click)="loadStatus()">Retry</button>
      </div>

      <!-- Content -->
      <div *ngIf="!loading && !error" class="content">
        <!-- Status Card -->
        <div class="card">
          <h2>Cookie Status</h2>
          <div class="status-row">
            <span class="status-label">Status:</span>
            <span class="status-badge" [class.fresh]="hasCookies && !isStale" [class.stale]="isStale" [class.missing]="!hasCookies">
              {{ statusText }}
            </span>
          </div>
          <div class="status-row" *ngIf="hasCookies && cookieAge !== null">
            <span class="status-label">Age:</span>
            <span class="status-value" [class.stale-text]="isStale">{{ formatAge(cookieAge) }}</span>
          </div>
          <div class="status-row" *ngIf="metubeReachable !== null">
            <span class="status-label">MeTube:</span>
            <span class="status-value" [class.online]="metubeReachable" [class.offline]="!metubeReachable">
              {{ metubeReachable ? '✅ Reachable' : '❌ Unreachable' }}
            </span>
          </div>
          <p class="hint" *ngIf="!hasCookies">
            No cookies found. Upload cookies from a signed-in session of any platform you want to download from
            (YouTube, Instagram, Facebook, X / Twitter, TikTok, Bilibili, Threads, Reddit, etc.).
          </p>
          <p class="hint stale-hint" *ngIf="isStale">
            Your cookies are old. Session cookies (especially YouTube and Instagram) expire quickly.
            If downloads fail with "Sign in to confirm you're not a bot" or similar auth prompts, export fresh cookies and re-upload.
          </p>
        </div>

        <!-- Per-platform breakdown -->
        <div class="card" *ngIf="hasCookies && platformRows.length > 0">
          <h2>Cookies By Platform</h2>
          <p class="subtitle">
            One cookies.txt can carry sessions for many sites. Earliest expiry per platform shown — when it goes red, re-export from that site.
          </p>
          <div class="platform-list">
            <div
              class="platform-row"
              *ngFor="let row of platformRows"
              [class.fresh]="row.status === 'fresh'"
              [class.expiring]="row.status === 'expiring'"
              [class.expired]="row.status === 'expired'"
              [attr.title]="row.expiryHint"
            >
              <span class="p-icon">{{ row.icon }}</span>
              <span class="p-name">{{ row.display }}</span>
              <span class="p-count">{{ row.bucket.session_count }} cookie{{ row.bucket.session_count === 1 ? '' : 's' }}</span>
              <span class="p-status">
                <ng-container [ngSwitch]="row.status">
                  <span *ngSwitchCase="'fresh'">✅ {{ row.expiryHint }}</span>
                  <span *ngSwitchCase="'expiring'">⏳ {{ row.expiryHint }}</span>
                  <span *ngSwitchCase="'expired'">❌ {{ row.expiryHint }}</span>
                </ng-container>
              </span>
            </div>
          </div>
        </div>

        <!-- Upload Card -->
        <div class="card">
          <h2>Upload Cookies</h2>
          <p class="subtitle">
            Export cookies from your browser while signed in to the site you want to download from,
            then upload them here. One Netscape-format file can contain cookies for multiple platforms.
            Use the <a href="http://localhost:8086" target="_blank">Landing Page</a> for a guided walkthrough.
          </p>

          <div
            class="upload-zone"
            [class.dragover]="dragOver"
            (click)="fileInput.click()"
            (dragover)="onDragOver($event)"
            (dragleave)="onDragLeave($event)"
            (drop)="onDrop($event)"
          >
            <div class="big">🍪</div>
            <p *ngIf="!uploading">
              Drag & drop your cookies.txt file here<br>or click to select file
            </p>
            <p *ngIf="uploading">
              <span class="spinner-inline"></span> Uploading...
            </p>
            <input
              #fileInput
              type="file"
              accept=".txt"
              style="display: none"
              (change)="onFileSelected($event)"
            />
          </div>

          <div *ngIf="uploadResult" class="upload-result" [class.success]="uploadResult.success" [class.error]="!uploadResult.success">
            {{ uploadResult.success ? '✅ ' + (uploadResult.msg || 'Cookies uploaded successfully') : '❌ ' + (uploadResult.error || 'Upload failed') }}
          </div>
        </div>

        <!-- Actions Card -->
        <div class="card" *ngIf="hasCookies">
          <h2>Actions</h2>
          <button class="btn-delete" (click)="onDeleteCookies()" [disabled]="deleting">
            {{ deleting ? 'Deleting...' : '🗑️ Delete Cookies' }}
          </button>
          <p class="hint">Deleting cookies will remove the current session. You'll need to re-upload fresh cookies to continue downloading.</p>
        </div>
      </div>
    </div>

    <!-- Toast -->
    <div *ngIf="toast" class="toast" [class.error]="toastError">
      {{ toast }}
    </div>
  `,
  styles: [`
    .page {
      padding: 24px;
      max-width: 700px;
      margin: 0 auto;
    }
    .page-title {
      font-size: 1.5rem;
      font-weight: 700;
      margin-bottom: 20px;
      color: #a9b7c6;
    }
    .card {
      background: #3c3f41;
      border: 1px solid #555555;
      border-radius: 16px;
      padding: 24px;
      margin-bottom: 16px;
    }
    .card h2 {
      font-size: 1.1rem;
      font-weight: 600;
      margin-bottom: 16px;
      color: #a9b7c6;
    }
    .subtitle {
      color: #808080;
      font-size: 0.9rem;
      margin-bottom: 16px;
      line-height: 1.5;
    }
    .subtitle a {
      color: #cc7832;
      text-decoration: none;
    }
    .subtitle a:hover {
      text-decoration: underline;
    }
    .status-row {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 8px 0;
      border-bottom: 1px solid rgba(169,183,198,0.04);
    }
    .status-row:last-child {
      border-bottom: none;
    }
    .status-label {
      color: #808080;
      font-size: 0.9rem;
      min-width: 70px;
    }
    .status-badge {
      display: inline-flex;
      align-items: center;
      padding: 4px 12px;
      border-radius: 8px;
      font-size: 0.85rem;
      font-weight: 600;
      background: #4e5254;
      color: #808080;
    }
    .status-badge.fresh {
      background: rgba(106,135,89,0.12);
      color: #6a8759;
    }
    .status-badge.stale {
      background: rgba(217,164,65,0.12);
      color: #d9a441;
    }
    .status-badge.missing {
      background: rgba(157,0,30,0.12);
      color: #cc7832;
    }
    .status-value {
      font-size: 0.9rem;
      color: #a9b7c6;
    }
    .status-value.stale-text {
      color: #d9a441;
    }
    .status-value.online {
      color: #6a8759;
    }
    .status-value.offline {
      color: #cc7832;
    }
    .hint {
      margin-top: 12px;
      font-size: 0.85rem;
      color: #808080;
      line-height: 1.5;
    }
    .stale-hint {
      color: #d9a441;
    }
    .upload-zone {
      border: 2px dashed rgba(169,183,198,0.15);
      border-radius: 16px;
      padding: 40px 30px;
      text-align: center;
      cursor: pointer;
      transition: all 0.3s ease;
    }
    .upload-zone:hover, .upload-zone.dragover {
      border-color: #6a8759;
      background: rgba(106,135,89,0.04);
    }
    .upload-zone .big {
      font-size: 2.5rem;
      margin-bottom: 10px;
    }
    .upload-zone p {
      color: #808080;
      font-size: 0.95rem;
    }
    .upload-result {
      margin-top: 12px;
      padding: 10px 14px;
      border-radius: 10px;
      font-size: 0.9rem;
    }
    .upload-result.success {
      background: rgba(106,135,89,0.08);
      color: #6a8759;
    }
    .upload-result.error {
      background: rgba(204,120,50,0.08);
      color: #cc7832;
    }
    .btn-delete {
      padding: 10px 20px;
      background: rgba(157,0,30,0.12);
      color: #cc7832;
      border: 1px solid rgba(157,0,30,0.2);
      border-radius: 10px;
      font-size: 0.9rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
    }
    .btn-delete:hover:not(:disabled) {
      background: rgba(157,0,30,0.2);
    }
    .btn-delete:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }
    .btn-retry {
      padding: 8px 16px;
      background: rgba(106,135,89,0.12);
      color: #6a8759;
      border: 1px solid rgba(106,135,89,0.2);
      border-radius: 8px;
      font-size: 0.85rem;
      font-weight: 600;
      cursor: pointer;
      margin-top: 10px;
    }
    @media (max-width: 640px) {
      .page { padding: 16px; }
      .page-title { font-size: 1.25rem; }
      .card { padding: 20px; }
      .upload-zone { padding: 30px 20px; }
      .status-row { flex-wrap: wrap; gap: 6px; }
      .status-label { min-width: 60px; }
      .toast { max-width: 90%; text-align: center; }
    }
    .loading {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 60px 20px;
      color: #808080;
      gap: 16px;
    }
    .spinner {
      width: 40px;
      height: 40px;
      border: 3px solid #4e5254;
      border-top-color: #9d001e;
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }
    .spinner-inline {
      display: inline-block;
      width: 16px;
      height: 16px;
      border: 2px solid #4e5254;
      border-top-color: #9d001e;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin-right: 8px;
      vertical-align: middle;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    .error-state {
      padding: 40px 20px;
      text-align: center;
      color: #cc7832;
    }
    .toast {
      position: fixed;
      bottom: 24px;
      left: 50%;
      transform: translateX(-50%);
      padding: 12px 24px;
      background: rgba(106,135,89,0.9);
      color: #2b2b2b;
      border-radius: 10px;
      font-size: 0.9rem;
      font-weight: 600;
      z-index: 1000;
      animation: toastIn 0.3s ease;
    }
    .toast.error {
      background: rgba(204,120,50,0.9);
      color: #a9b7c6;
    }
    @keyframes toastIn {
      from { opacity: 0; transform: translateX(-50%) translateY(20px); }
      to { opacity: 1; transform: translateX(-50%) translateY(0); }
    }
    .platform-list {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .platform-row {
      display: grid;
      grid-template-columns: 28px 1fr auto auto;
      gap: 12px;
      align-items: center;
      padding: 10px 12px;
      border-radius: 10px;
      background: rgba(0,0,0,0.18);
      border: 1px solid rgba(169,183,198,0.06);
      cursor: help;
      font-size: 13px;
    }
    .platform-row.fresh    { border-color: rgba(106,135,89,0.30); }
    .platform-row.expiring { border-color: rgba(217,164,65,0.30); }
    .platform-row.expired  { border-color: rgba(157,0,30,0.40); opacity: 0.85; }
    .platform-row .p-icon { font-size: 18px; text-align: center; }
    .platform-row .p-name { color: #a9b7c6; font-weight: 600; }
    .platform-row .p-count { color: #808080; font-size: 12px; }
    .platform-row .p-status { font-size: 12px; color: #808080; }
    .platform-row.fresh    .p-status { color: #6a8759; }
    .platform-row.expiring .p-status { color: #d9a441; }
    .platform-row.expired  .p-status { color: #cc7832; }
  `],
})
export class CookiesComponent implements OnInit, OnDestroy {
  loading = true;
  error: string | null = null;
  hasCookies = false;
  isStale = false;
  cookieAge: number | null = null;
  metubeReachable: boolean | null = null;
  statusText = 'Checking...';
  platformRows: PlatformRow[] = [];

  private readonly PLATFORM_DISPLAY: Record<string, { display: string; icon: string }> = {
    youtube:     { display: 'YouTube',     icon: '📺' },
    vimeo:       { display: 'Vimeo',       icon: '🎬' },
    dailymotion: { display: 'Dailymotion', icon: '▶️' },
    twitch:      { display: 'Twitch',      icon: '🎮' },
    rumble:      { display: 'Rumble',      icon: '📡' },
    peertube:    { display: 'PeerTube',    icon: '🔭' },
    instagram:   { display: 'Instagram',   icon: '📸' },
    reddit:      { display: 'Reddit',      icon: '🤖' },
    facebook:    { display: 'Facebook',    icon: '👤' },
    x:           { display: 'X / Twitter', icon: '𝕏'  },
    threads:     { display: 'Threads',     icon: '🧵' },
    tiktok:      { display: 'TikTok',      icon: '🎵' },
    vk:          { display: 'VK',          icon: '🇻🇰' },
    bilibili:    { display: 'Bilibili',    icon: '🇨🇳' },
    soundcloud:  { display: 'SoundCloud',  icon: '☁️' },
    bandcamp:    { display: 'Bandcamp',    icon: '🎵' },
  };

  dragOver = false;
  uploading = false;
  uploadResult: { success: boolean; msg?: string; error?: string } | null = null;

  deleting = false;

  toast: string | null = null;
  toastError = false;

  private sub?: Subscription;
  private toastTimer?: ReturnType<typeof setTimeout>;

  constructor(private metube: MetubeService) {}

  ngOnInit(): void {
    this.loadStatus();
  }

  ngOnDestroy(): void {
    this.sub?.unsubscribe();
    if (this.toastTimer) clearTimeout(this.toastTimer);
  }

  loadStatus(): void {
    this.loading = true;
    this.error = null;
    this.sub = this.metube.getCookieStatus().subscribe({
      next: (data) => {
        this.hasCookies = data.has_cookies;
        this.cookieAge = data.cookie_age_minutes ?? null;
        this.metubeReachable = data.metube_reachable ?? null;
        this.isStale = !!(this.cookieAge && this.cookieAge > 60);
        this.platformRows = this.buildPlatformRows(data.platforms || {});

        if (!this.hasCookies) {
          this.statusText = '❌ No Cookies';
        } else if (this.isStale) {
          this.statusText = '⚠️ Stale';
        } else {
          this.statusText = '✅ Fresh';
        }

        this.loading = false;
      },
      error: (err) => {
        this.error = 'Failed to check cookie status: ' + (err.error?.error || err.message);
        this.loading = false;
      },
    });
  }

  formatAge(minutes: number): string {
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return `${Math.round(minutes)} min`;
    const hours = Math.floor(minutes / 60);
    const mins = Math.round(minutes % 60);
    return `${hours}h ${mins}m`;
  }

  buildPlatformRows(platforms: { [k: string]: PlatformCookieBucket }): PlatformRow[] {
    const nowSec = Math.floor(Date.now() / 1000);
    const rows: PlatformRow[] = [];
    for (const key of Object.keys(platforms).sort()) {
      const bucket = platforms[key];
      const meta = this.PLATFORM_DISPLAY[key] || { display: key, icon: '🍪' };

      // Earliest non-zero expiry decides whether the bucket is stale.
      // 0 = no expiry recorded (session cookie or pre-expiry). We treat
      // those as "fresh" since they're either still valid or rely on
      // the file-level mtime check the parent panel already shows.
      const minExpiry = bucket.min_expiry_unix;
      let status: 'fresh' | 'expiring' | 'expired';
      let expiryHint: string;
      if (minExpiry === 0) {
        status = 'fresh';
        expiryHint = 'session cookies, no recorded expiry';
      } else {
        const secondsLeft = minExpiry - nowSec;
        if (secondsLeft <= 0) {
          status = 'expired';
          expiryHint = `expired ${this.formatRelative(-secondsLeft)} ago`;
        } else if (secondsLeft < 24 * 3600) {
          status = 'expiring';
          expiryHint = `expires in ${this.formatRelative(secondsLeft)}`;
        } else {
          status = 'fresh';
          expiryHint = `expires in ${this.formatRelative(secondsLeft)}`;
        }
      }
      rows.push({ key, display: meta.display, icon: meta.icon, bucket, status, expiryHint });
    }
    return rows;
  }

  private formatRelative(seconds: number): string {
    if (seconds < 60) return `${seconds}s`;
    if (seconds < 3600) return `${Math.round(seconds / 60)}m`;
    if (seconds < 86400) return `${Math.round(seconds / 3600)}h`;
    return `${Math.round(seconds / 86400)}d`;
  }

  onDragOver(event: DragEvent): void {
    event.preventDefault();
    this.dragOver = true;
  }

  onDragLeave(event: DragEvent): void {
    event.preventDefault();
    this.dragOver = false;
  }

  onDrop(event: DragEvent): void {
    event.preventDefault();
    this.dragOver = false;
    const files = event.dataTransfer?.files;
    if (files && files.length > 0) {
      this.uploadFile(files[0]);
    }
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      this.uploadFile(input.files[0]);
    }
  }

  uploadFile(file: File): void {
    this.uploading = true;
    this.uploadResult = null;
    this.metube.uploadCookies(file).subscribe({
      next: (res) => {
        this.uploading = false;
        this.uploadResult = res;
        if (res.success) {
          this.showToast('Cookies uploaded successfully!', false);
          this.loadStatus();
        } else {
          this.showToast('Upload failed: ' + (res.error || 'Unknown error'), true);
        }
      },
      error: (err) => {
        this.uploading = false;
        this.uploadResult = { success: false, error: err.error?.error || err.message };
        this.showToast('Upload failed: ' + (err.error?.error || err.message), true);
      },
    });
  }

  onDeleteCookies(): void {
    this.deleting = true;
    this.metube.deleteCookies().subscribe({
      next: (res) => {
        this.deleting = false;
        if (res.success) {
          this.showToast(res.msg || 'Cookies deleted', false);
          this.loadStatus();
        } else {
          this.showToast('Delete failed: ' + (res.error || 'Unknown error'), true);
        }
      },
      error: (err) => {
        this.deleting = false;
        this.showToast('Delete failed: ' + (err.error?.error || err.message), true);
      },
    });
  }

  private showToast(message: string, isError: boolean): void {
    this.toast = message;
    this.toastError = isError;
    if (this.toastTimer) clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => {
      this.toast = null;
    }, 4000);
  }
}
