import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Subscription } from 'rxjs';
import { MetubeService } from '../../services/metube.service';

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
            No cookies found. Upload cookies from a signed-in YouTube session to download videos.
          </p>
          <p class="hint stale-hint" *ngIf="isStale">
            Your cookies are old. YouTube cookies expire quickly. If downloads fail with "Sign in to confirm you're not a bot", export fresh cookies and re-upload.
          </p>
        </div>

        <!-- Upload Card -->
        <div class="card">
          <h2>Upload Cookies</h2>
          <p class="subtitle">
            Export cookies from your browser while signed in to YouTube, then upload them here.
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
      color: #fff;
    }
    .card {
      background: rgba(255,255,255,0.04);
      border: 1px solid rgba(255,255,255,0.08);
      border-radius: 16px;
      padding: 24px;
      margin-bottom: 16px;
    }
    .card h2 {
      font-size: 1.1rem;
      font-weight: 600;
      margin-bottom: 16px;
      color: #fff;
    }
    .subtitle {
      color: #888;
      font-size: 0.9rem;
      margin-bottom: 16px;
      line-height: 1.5;
    }
    .subtitle a {
      color: #ff5588;
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
      border-bottom: 1px solid rgba(255,255,255,0.04);
    }
    .status-row:last-child {
      border-bottom: none;
    }
    .status-label {
      color: #888;
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
      background: rgba(255,255,255,0.06);
      color: #aaa;
    }
    .status-badge.fresh {
      background: rgba(0,255,136,0.1);
      color: #00ff88;
    }
    .status-badge.stale {
      background: rgba(255,200,0,0.1);
      color: #ffcc66;
    }
    .status-badge.missing {
      background: rgba(255,0,80,0.1);
      color: #ff5588;
    }
    .status-value {
      font-size: 0.9rem;
      color: #ccc;
    }
    .status-value.stale-text {
      color: #ffcc66;
    }
    .status-value.online {
      color: #00ff88;
    }
    .status-value.offline {
      color: #ff5588;
    }
    .hint {
      margin-top: 12px;
      font-size: 0.85rem;
      color: #888;
      line-height: 1.5;
    }
    .stale-hint {
      color: #ffcc66;
    }
    .upload-zone {
      border: 2px dashed rgba(255,255,255,0.15);
      border-radius: 16px;
      padding: 40px 30px;
      text-align: center;
      cursor: pointer;
      transition: all 0.3s ease;
    }
    .upload-zone:hover, .upload-zone.dragover {
      border-color: #00ff88;
      background: rgba(0,255,136,0.04);
    }
    .upload-zone .big {
      font-size: 2.5rem;
      margin-bottom: 10px;
    }
    .upload-zone p {
      color: #888;
      font-size: 0.95rem;
    }
    .upload-result {
      margin-top: 12px;
      padding: 10px 14px;
      border-radius: 10px;
      font-size: 0.9rem;
    }
    .upload-result.success {
      background: rgba(0,255,136,0.08);
      color: #00ff88;
    }
    .upload-result.error {
      background: rgba(255,0,80,0.08);
      color: #ff5588;
    }
    .btn-delete {
      padding: 10px 20px;
      background: rgba(255,0,80,0.12);
      color: #ff5588;
      border: 1px solid rgba(255,0,80,0.2);
      border-radius: 10px;
      font-size: 0.9rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
    }
    .btn-delete:hover:not(:disabled) {
      background: rgba(255,0,80,0.2);
    }
    .btn-delete:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }
    .btn-retry {
      padding: 8px 16px;
      background: rgba(0,255,136,0.12);
      color: #00ff88;
      border: 1px solid rgba(0,255,136,0.2);
      border-radius: 8px;
      font-size: 0.85rem;
      font-weight: 600;
      cursor: pointer;
      margin-top: 10px;
    }
    .loading {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 60px 20px;
      color: #888;
      gap: 16px;
    }
    .spinner {
      width: 40px;
      height: 40px;
      border: 3px solid rgba(255,255,255,0.1);
      border-top-color: #ff0050;
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }
    .spinner-inline {
      display: inline-block;
      width: 16px;
      height: 16px;
      border: 2px solid rgba(255,255,255,0.1);
      border-top-color: #ff0050;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin-right: 8px;
      vertical-align: middle;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    .error-state {
      padding: 40px 20px;
      text-align: center;
      color: #ff5588;
    }
    .toast {
      position: fixed;
      bottom: 24px;
      left: 50%;
      transform: translateX(-50%);
      padding: 12px 24px;
      background: rgba(0,255,136,0.9);
      color: #000;
      border-radius: 10px;
      font-size: 0.9rem;
      font-weight: 600;
      z-index: 1000;
      animation: toastIn 0.3s ease;
    }
    .toast.error {
      background: rgba(255,0,80,0.9);
      color: #fff;
    }
    @keyframes toastIn {
      from { opacity: 0; transform: translateX(-50%) translateY(20px); }
      to { opacity: 1; transform: translateX(-50%) translateY(0); }
    }
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
