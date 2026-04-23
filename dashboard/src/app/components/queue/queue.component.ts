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

      <div *ngIf="queue.length === 0 && pending.length === 0" class="empty">
        <div class="empty-icon">📭</div>
        <p>Queue is empty. Add a download from the Download tab.</p>
      </div>

      <div class="list">
        <!-- Pending items -->
        <div class="item pending" *ngFor="let item of pending">
          <div class="info">
            <div class="title" [title]="item.title">{{ item.title || 'Untitled' }}</div>
            <div class="meta">
              <span class="status pending">pending</span>
            </div>
          </div>
          <button class="btn-delete" (click)="delete(item.id, 'queue')" title="Cancel">✕</button>
        </div>

        <!-- Queue items -->
        <div class="item" *ngFor="let item of queue" [class.error]="item.status === 'error'">
          <div class="info">
            <div class="title" [title]="item.title">{{ item.title || 'Untitled' }}</div>
            <div class="meta">
              <span class="status" [class]="item.status">{{ item.status }}</span>
              <span *ngIf="item.speed">• {{ item.speed }}</span>
              <span *ngIf="item.eta">• ETA {{ item.eta }}</span>
              <span *ngIf="item.size">• {{ formatSize(item.size) }}</span>
            </div>
            <div *ngIf="item.msg" class="msg">{{ item.msg }}</div>
          </div>

          <div class="progress-wrap" *ngIf="item.status === 'downloading' || item.status === 'preparing'">
            <div class="progress-bar">
              <div class="fill" [style.width.%]="item.percent || 0"></div>
            </div>
            <span class="percent">{{ item.percent || 0 }}%</span>
          </div>

          <button class="btn-delete" (click)="delete(item.id, 'queue')" title="Cancel">✕</button>
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
      align-items: center;
      gap: 16px;
      padding: 16px 20px;
      background: rgba(255,255,255,0.04);
      border: 1px solid rgba(255,255,255,0.06);
      border-radius: 14px;
      transition: background 0.2s;
    }
    .item:hover { background: rgba(255,255,255,0.06); }
    .item.error { border-color: rgba(255,0,80,0.3); }
    .item.pending { border-color: rgba(255,200,0,0.15); }
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
    .msg { margin-top: 6px; font-size: 12px; color: #ff5588; }
    .progress-wrap {
      display: flex;
      align-items: center;
      gap: 10px;
      width: 200px;
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
  `],
})
export class QueueComponent implements OnInit, OnDestroy {
  queue: DownloadInfo[] = [];
  pending: DownloadInfo[] = [];
  private sub?: Subscription;

  constructor(private metube: MetubeService) {}

  ngOnInit(): void {
    this.sub = this.metube.getHistoryPolling().subscribe({
      next: (data) => {
        this.queue = data.queue || [];
        this.pending = data.pending || [];
      },
      error: (err) => console.error('Queue poll error', err),
    });
  }

  ngOnDestroy(): void {
    this.sub?.unsubscribe();
  }

  delete(id: string, where: 'queue' | 'done'): void {
    this.metube.deleteDownloads([id], where).subscribe();
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
