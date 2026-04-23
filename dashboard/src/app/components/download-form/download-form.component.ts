import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MetubeService } from '../../services/metube.service';

@Component({
  selector: 'app-download-form',
  standalone: true,
  imports: [CommonModule, FormsModule],
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

        <div *ngIf="message" class="alert" [class.error]="isError" [class.success]="!isError">
          {{ message }}
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
    .alert {
      margin-top: 14px;
      padding: 10px 14px;
      border-radius: 10px;
      font-size: 13px;
    }
    .alert.success {
      background: rgba(0,255,136,0.1);
      border: 1px solid rgba(0,255,136,0.2);
      color: #00ff88;
    }
    .alert.error {
      background: rgba(255,0,80,0.1);
      border: 1px solid rgba(255,0,80,0.2);
      color: #ff5588;
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
export class DownloadFormComponent implements OnInit {
  url = '';
  quality = 'best';
  format = 'any';
  folder = '';
  loading = false;
  message = '';
  isError = false;

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

  addDownload(): void {
    if (!this.url.trim()) return;
    this.loading = true;
    this.message = '';

    this.metube
      .addDownload({
        url: this.url.trim(),
        quality: this.quality,
        format: this.format,
        folder: this.folder.trim(),
      })
      .subscribe({
        next: (res) => {
          this.loading = false;
          if (res.status === 'ok') {
            this.message = 'Added to queue successfully!';
            this.isError = false;
            this.url = '';
          } else {
            this.message = res.msg || 'Failed to add download';
            this.isError = true;
          }
        },
        error: (err) => {
          this.loading = false;
          this.isError = true;
          this.message = err.error?.msg || err.message || 'Network error';
        },
      });
  }
}
