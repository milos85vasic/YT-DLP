import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Subscription } from 'rxjs';
import { MetubeService, DownloadInfo } from '../../services/metube.service';

@Component({
  selector: 'app-queue',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="page">
      <h2>⏳ Download Queue</h2>

      <div *ngIf="loading" class="loading">
        <div class="spinner"></div>
        <p>Loading queue…</p>
      </div>

      <div *ngIf="error" class="error-state">
        <div class="error-icon">⚠️</div>
        <p>{{ error }}</p>
        <button class="btn-retry" (click)="retryLoad()">↻ Retry</button>
      </div>

      <div *ngIf="!loading && !error && allItems.length === 0" class="empty">
        <div class="empty-icon">📭</div>
        <p>Queue is empty. Add a download from the Download tab.</p>
      </div>

      <div class="list">
        <!-- Pending items -->
        <div class="item pending" *ngFor="let item of pending">
          <div class="thumb">⏳</div>
          <div class="info">
            <div class="title" [title]="item.title">{{ item.title || 'Preparing...' }}</div>
            <div class="meta">
              <span class="status pending">pending</span>
              <span *ngIf="item.url" class="url" [title]="item.url">{{ item.url }}</span>
            </div>
          </div>
          <button class="btn-delete" (click)="delete(item.id, 'queue')" title="Cancel">✕</button>
        </div>

        <!-- Queue items -->
        <div class="item" *ngFor="let item of queue" [class.error]="item.status === 'error'">
          <div class="thumb">
            <span *ngIf="item.status === 'error'">❌</span>
            <span *ngIf="item.status !== 'error'">⬇️</span>
          </div>
          <div class="info">
            <div class="title" [title]="item.title">{{ item.title || 'Untitled' }}</div>
            <div class="meta">
              <span class="status" [class]="item.status">{{ item.status }}</span>
              <span *ngIf="item.speed">• {{ item.speed }}</span>
              <span *ngIf="item.eta">• ETA {{ item.eta }}</span>
              <span *ngIf="item.size">• {{ formatSize(item.size) }}</span>
            </div>
            <!-- Error message -->
            <div *ngIf="item.msg" class="msg">{{ item.msg }}</div>
            <!-- URL for context -->
            <div *ngIf="item.url && item.status === 'error'" class="url" [title]="item.url">{{ item.url }}</div>
          </div>

          <div class="progress-wrap" *ngIf="item.status === 'downloading' || item.status === 'preparing'">
            <div class="progress-bar">
              <div class="fill" [style.width.%]="item.percent || 0"></div>
            </div>
            <span class="percent">{{ item.percent || 0 }}%</span>
          </div>

          <div class="actions">
            <button *ngIf="item.status === 'error'" class="btn-retry" (click)="retry(item)" title="Retry">↻</button>
            <button class="btn-delete" (click)="delete(item.id, 'queue')" title="Cancel">✕</button>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .page { padding: 24px; max-width: 900px; margin: 0 auto; }
    h2 { margin: 0 0 20px; font-size: 20px; color: #fff; }
    .empty {
      text-align: center;
      padding: 60px 20px;
      color: #666;
    }
    .empty-icon { font-size: 48px; margin-bottom: 12px; }
    .list { display: flex; flex-direction: column; gap: 12px; }
    .item {
      display: flex;
      align-items: flex-start;
      gap: 14px;
      padding: 16px 20px;
      background: rgba(255,255,255,0.04);
      border: 1px solid rgba(255,255,255,0.06);
      border-radius: 14px;
      transition: background 0.2s;
    }
    .item:hover { background: rgba(255,255,255,0.06); }
    .item.error { border-color: rgba(255,0,80,0.3); background: rgba(255,0,80,0.03); }
    .item.pending { border-color: rgba(255,200,0,0.15); }
    .thumb { font-size: 20px; margin-top: 2px; }
    .info { flex: 1; min-width: 0; }
    .title {
      font-size: 14px;
      font-weight: 600;
      color: #fff;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .meta {
      margin-top: 6px;
      font-size: 12px;
      color: #888;
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      align-items: center;
    }
    .status {
      padding: 2px 8px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
    }
    .status.pending { background: rgba(255,200,0,0.12); color: #ffcc00; }
    .status.preparing { background: rgba(0,150,255,0.12); color: #66b3ff; }
    .status.downloading { background: rgba(0,255,136,0.12); color: #00ff88; }
    .status.processing { background: rgba(150,0,255,0.12); color: #cc88ff; }
    .status.finished { background: rgba(0,255,136,0.12); color: #00ff88; }
    .status.error { background: rgba(255,0,80,0.12); color: #ff5588; }
    .msg {
      margin-top: 8px;
      padding: 8px 12px;
      background: rgba(255,0,80,0.08);
      border: 1px solid rgba(255,0,80,0.15);
      border-radius: 8px;
      font-size: 12px;
      color: #ff5588;
      font-family: monospace;
      white-space: pre-wrap;
      word-break: break-word;
    }
    .url {
      margin-top: 4px;
      font-size: 11px;
      color: #555;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .progress-wrap {
      display: flex;
      align-items: center;
      gap: 10px;
      width: 180px;
      margin-top: 4px;
    }
    .progress-bar {
      flex: 1;
      height: 6px;
      background: rgba(255,255,255,0.08);
      border-radius: 3px;
      overflow: hidden;
    }
    .fill {
      height: 100%;
      background: linear-gradient(90deg, #ff0050, #ffcc00);
      border-radius: 3px;
      transition: width 0.5s ease;
    }
    .percent { font-size: 12px; color: #aaa; width: 36px; text-align: right; }
    .actions {
      display: flex;
      gap: 6px;
      align-items: center;
    }
    .btn-delete {
      width: 32px;
      height: 32px;
      border-radius: 8px;
      border: none;
      background: rgba(255,0,80,0.1);
      color: #ff5588;
      cursor: pointer;
      font-size: 14px;
      transition: background 0.2s;
    }
    .btn-delete:hover { background: rgba(255,0,80,0.25); }
    .btn-retry {
      width: 32px;
      height: 32px;
      border-radius: 8px;
      border: none;
      background: rgba(0,255,136,0.1);
      color: #00ff88;
      cursor: pointer;
      font-size: 16px;
      transition: background 0.2s;
    }
    .btn-retry:hover { background: rgba(0,255,136,0.25); }
    .loading {
      text-align: center;
      padding: 60px 20px;
      color: #666;
    }
    .loading .spinner {
      width: 40px;
      height: 40px;
      border: 3px solid rgba(255,255,255,0.1);
      border-top-color: #00ff88;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin: 0 auto 16px;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    .error-state {
      text-align: center;
      padding: 60px 20px;
      color: #ff5588;
    }
    .error-icon { font-size: 48px; margin-bottom: 12px; }
    .error-state .btn-retry {
      width: auto;
      height: auto;
      padding: 10px 20px;
      margin-top: 16px;
      background: rgba(255,85,136,0.08);
      border: 1px solid rgba(255,85,136,0.3);
      color: #ff5588;
    }
    .error-state .btn-retry:hover { background: rgba(255,85,136,0.15); }
  `],
})
export class QueueComponent implements OnInit, OnDestroy {
  queue: DownloadInfo[] = [];
  pending: DownloadInfo[] = [];
  loading = true;
  error: string | null = null;
  private sub?: Subscription;

  constructor(private metube: MetubeService) {}

  ngOnInit(): void {
    this.sub = this.metube.getHistoryPolling(1000).subscribe({
      next: (data) => {
        this.loading = false;
        this.error = null;
        this.queue = data.queue || [];
        this.pending = data.pending || [];
      },
      error: (err) => {
        this.loading = false;
        this.error = 'Failed to load queue. Is the MeTube service running?';
        console.error('Queue poll error', err);
      },
    });
  }

  ngOnDestroy(): void {
    this.sub?.unsubscribe();
  }

  get allItems(): DownloadInfo[] {
    return [...this.pending, ...this.queue];
  }

  delete(id: string, where: 'queue' | 'done'): void {
    this.metube.deleteDownloads([id], where).subscribe();
  }

  retryLoad(): void {
    this.loading = true;
    this.error = null;
    this.sub?.unsubscribe();
    this.sub = this.metube.getHistoryPolling(1000).subscribe({
      next: (data) => {
        this.loading = false;
        this.error = null;
        this.queue = data.queue || [];
        this.pending = data.pending || [];
      },
      error: (err) => {
        this.loading = false;
        this.error = 'Failed to load queue. Is the MeTube service running?';
        console.error('Queue poll error', err);
      },
    });
  }

  retry(item: DownloadInfo): void {
    // For queue items, startDownloads only works on pending.
    // For error items in queue, we must delete and re-add.
    if (item.status === 'error') {
      this.metube.retryDownload(item).subscribe({
        next: () => {},
        error: (err) => console.error('Retry failed', err),
      });
    } else {
      this.metube.startDownloads([item.id]).subscribe({
        next: () => {},
        error: (err) => console.error('Retry failed', err),
      });
    }
  }

  formatSize(size: number | string): string {
    if (typeof size === 'string') return size;
    const units = ['B', 'KB', 'MB', 'GB'];
    let i = 0;
    let s = Number(size);
    while (s >= 1024 && i < units.length - 1) {
      s /= 1024;
      i++;
    }
    return `${s.toFixed(1)} ${units[i]}`;
  }
}
