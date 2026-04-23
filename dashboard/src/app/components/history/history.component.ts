import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Subscription } from 'rxjs';
import { MetubeService, DownloadInfo } from '../../services/metube.service';

@Component({
  selector: 'app-history',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="page">
      <h2>📜 Download History</h2>

      <div *ngIf="history.length === 0" class="empty">
        <div class="empty-icon">📭</div>
        <p>No completed downloads yet.</p>
      </div>

      <div class="list">
        <div class="item" *ngFor="let item of history" [class.error]="item.status === 'error'" [class.finished]="item.status === 'finished'">
          <div class="thumb">
            <span *ngIf="item.status === 'error'">❌</span>
            <span *ngIf="item.status === 'finished'">✅</span>
            <span *ngIf="item.status !== 'error' && item.status !== 'finished'">📄</span>
          </div>
          <div class="info">
            <div class="title" [title]="item.title">{{ item.title || 'Untitled' }}</div>
            <div class="meta">
              <span class="status" [class]="item.status">{{ item.status }}</span>
              <span *ngIf="item.size">• {{ formatSize(item.size) }}</span>
            </div>
            <!-- Filename for successful downloads -->
            <div *ngIf="item.filename" class="filename" [title]="item.filename">📁 {{ item.filename }}</div>
            <!-- URL for context -->
            <div *ngIf="item.url" class="url" [title]="item.url">{{ item.url }}</div>
            <!-- Error message -->
            <div *ngIf="item.msg" class="msg">{{ item.msg }}</div>
          </div>
          <div class="actions">
            <button *ngIf="item.status === 'error'" class="btn-retry" (click)="retry(item.id)" title="Retry download">↻ Retry</button>
            <button class="btn-delete" (click)="delete(item.id)" title="Remove from history">✕</button>
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
      padding: 14px 18px;
      background: rgba(255,255,255,0.04);
      border: 1px solid rgba(255,255,255,0.06);
      border-radius: 14px;
      transition: background 0.2s;
    }
    .item:hover { background: rgba(255,255,255,0.06); }
    .item.error { border-color: rgba(255,0,80,0.3); background: rgba(255,0,80,0.03); }
    .item.finished { border-color: rgba(0,255,136,0.15); }
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
      margin-top: 4px;
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
    .status.finished { background: rgba(0,255,136,0.12); color: #00ff88; }
    .status.error { background: rgba(255,0,80,0.12); color: #ff5588; }
    .filename {
      margin-top: 6px;
      font-size: 11px;
      color: #666;
      font-family: monospace;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .url {
      margin-top: 4px;
      font-size: 11px;
      color: #555;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
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
      background: rgba(255,255,255,0.06);
      color: #888;
      cursor: pointer;
      font-size: 14px;
      transition: all 0.2s;
    }
    .btn-delete:hover { background: rgba(255,0,80,0.2); color: #ff5588; }
    .btn-retry {
      padding: 6px 14px;
      border-radius: 8px;
      border: none;
      background: rgba(0,255,136,0.1);
      color: #00ff88;
      cursor: pointer;
      font-size: 12px;
      font-weight: 600;
      transition: background 0.2s;
    }
    .btn-retry:hover { background: rgba(0,255,136,0.25); }
  `],
})
export class HistoryComponent implements OnInit, OnDestroy {
  history: DownloadInfo[] = [];
  private sub?: Subscription;

  constructor(private metube: MetubeService) {}

  ngOnInit(): void {
    this.sub = this.metube.getHistoryPolling(1000).subscribe({
      next: (data) => {
        this.history = data.done || [];
      },
      error: (err) => console.error('History poll error', err),
    });
  }

  ngOnDestroy(): void {
    this.sub?.unsubscribe();
  }

  delete(id: string): void {
    this.metube.deleteDownloads([id], 'done').subscribe();
  }

  retry(id: string): void {
    this.metube.startDownloads([id]).subscribe({
      next: () => {},
      error: (err) => console.error('Retry failed', err),
    });
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
