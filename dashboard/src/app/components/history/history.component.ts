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
      <!-- Safety Banner -->
      <div class="safety-banner">
        <strong>🛡️ Safe History Management</strong>
        <p>
          Our dashboard <strong>never deletes your files</strong> when clearing history.
          Only the list entries are removed. Files stay in your downloads folder.
        </p>
        <p class="warning-small">
          ⚠️ <strong>Warning:</strong> The original MeTube Classic interface (port 8088)
          may still delete files when using "Clear Completed". Use this dashboard for safety.
        </p>
      </div>

      <div class="header-row">
        <h2>📜 Download History</h2>
        <button
          *ngIf="history.length > 0"
          class="btn-clear-all"
          (click)="clearAll()"
          title="Remove all items from history (files are kept)"
        >
          🧹 Clear All History
        </button>
      </div>

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
            <!-- Cleanup: remove from history only -->
            <button class="btn-action btn-cleanup" (click)="cleanup(item.id)" title="Remove from history (keep file)">🧹</button>
            <!-- Refresh: re-download -->
            <button class="btn-action btn-refresh" (click)="refresh(item)" title="Re-download">↻</button>
            <!-- Delete: remove from history + delete file -->
            <button class="btn-action btn-delete" (click)="confirmDelete(item)" title="Delete file + remove from history">🗑️</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Confirmation Dialog -->
    <div class="dialog-overlay" *ngIf="dialogItem" (click)="cancelDialog()">
      <div class="dialog" (click)="$event.stopPropagation()">
        <h3>🗑️ Confirm Deletion</h3>
        <p>Are you sure you want to permanently delete this download?</p>
        <div class="dialog-item">
          <strong>{{ dialogItem.title || 'Untitled' }}</strong>
          <span *ngIf="dialogItem.filename">{{ dialogItem.filename }}</span>
        </div>
        <p class="dialog-warning">This will remove the file from disk and delete the history entry. This action cannot be undone.</p>
        <div class="dialog-actions">
          <button class="btn-cancel" (click)="cancelDialog()">Cancel</button>
          <button class="btn-confirm" (click)="executeDelete()" [disabled]="dialogLoading">
            <span *ngIf="!dialogLoading">Delete Permanently</span>
            <span *ngIf="dialogLoading">Deleting…</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Toast notification -->
    <div class="toast" *ngIf="toastMsg" [class.error]="toastError">{{ toastMsg }}</div>
  `,
  styles: [`
    .page { padding: 24px; max-width: 900px; margin: 0 auto; }
    .safety-banner {
      margin-bottom: 20px;
      padding: 16px 20px;
      background: rgba(0,255,136,0.06);
      border: 1px solid rgba(0,255,136,0.15);
      border-radius: 14px;
      color: #ccc;
      font-size: 13px;
      line-height: 1.6;
    }
    .safety-banner strong {
      display: block;
      color: #00ff88;
      font-size: 15px;
      margin-bottom: 6px;
    }
    .safety-banner p { margin: 0 0 6px; }
    .safety-banner .warning-small {
      margin-top: 8px;
      padding-top: 8px;
      border-top: 1px solid rgba(255,200,0,0.15);
      color: #ffcc66;
      font-size: 12px;
    }
    .header-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 20px;
      gap: 12px;
      flex-wrap: wrap;
    }
    h2 { margin: 0; font-size: 20px; color: #fff; }
    .btn-clear-all {
      padding: 8px 16px;
      border-radius: 10px;
      border: 1px solid rgba(255,200,0,0.3);
      background: rgba(255,200,0,0.08);
      color: #ffcc66;
      cursor: pointer;
      font-size: 13px;
      font-weight: 600;
      transition: all 0.2s;
    }
    .btn-clear-all:hover { background: rgba(255,200,0,0.15); }
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
    .btn-action {
      width: 32px;
      height: 32px;
      border-radius: 8px;
      border: none;
      cursor: pointer;
      font-size: 14px;
      transition: all 0.2s;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .btn-cleanup {
      background: rgba(255,200,0,0.08);
      color: #ffcc66;
    }
    .btn-cleanup:hover { background: rgba(255,200,0,0.2); }
    .btn-refresh {
      background: rgba(0,150,255,0.08);
      color: #66b3ff;
    }
    .btn-refresh:hover { background: rgba(0,150,255,0.2); }
    .btn-delete {
      background: rgba(255,0,80,0.08);
      color: #ff5588;
    }
    .btn-delete:hover { background: rgba(255,0,80,0.2); }

    /* Dialog */
    .dialog-overlay {
      position: fixed;
      inset: 0;
      background: rgba(0,0,0,0.7);
      z-index: 1000;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .dialog {
      background: #1a1a2e;
      border: 1px solid rgba(255,255,255,0.1);
      border-radius: 16px;
      padding: 28px;
      max-width: 420px;
      width: 100%;
    }
    .dialog h3 { margin: 0 0 12px; font-size: 18px; color: #fff; }
    .dialog p { margin: 0 0 16px; font-size: 14px; color: #aaa; }
    .dialog-item {
      background: rgba(255,255,255,0.04);
      border-radius: 10px;
      padding: 12px 14px;
      margin-bottom: 16px;
    }
    .dialog-item strong {
      display: block;
      color: #fff;
      font-size: 14px;
      margin-bottom: 4px;
    }
    .dialog-item span {
      font-size: 12px;
      color: #666;
      font-family: monospace;
    }
    .dialog-warning {
      color: #ff5588 !important;
      font-size: 13px !important;
    }
    .dialog-actions {
      display: flex;
      gap: 10px;
      justify-content: flex-end;
    }
    .btn-cancel {
      padding: 10px 18px;
      border-radius: 10px;
      border: 1px solid rgba(255,255,255,0.15);
      background: transparent;
      color: #aaa;
      cursor: pointer;
      font-size: 14px;
    }
    .btn-cancel:hover { background: rgba(255,255,255,0.05); }
    .btn-confirm {
      padding: 10px 18px;
      border-radius: 10px;
      border: none;
      background: linear-gradient(90deg, #ff0050, #ff3366);
      color: #fff;
      cursor: pointer;
      font-size: 14px;
      font-weight: 600;
    }
    .btn-confirm:hover:not(:disabled) { opacity: 0.9; }
    .btn-confirm:disabled { opacity: 0.5; cursor: not-allowed; }

    /* Toast */
    .toast {
      position: fixed;
      bottom: 24px;
      left: 50%;
      transform: translateX(-50%);
      padding: 12px 24px;
      background: rgba(0,255,136,0.12);
      border: 1px solid rgba(0,255,136,0.2);
      border-radius: 12px;
      color: #00ff88;
      font-size: 14px;
      z-index: 1001;
      animation: toastIn 0.3s ease;
    }
    .toast.error {
      background: rgba(255,0,80,0.12);
      border-color: rgba(255,0,80,0.2);
      color: #ff5588;
    }
    @keyframes toastIn {
      from { opacity: 0; transform: translate(-50%, 20px); }
      to { opacity: 1; transform: translate(-50%, 0); }
    }
  `],
})
export class HistoryComponent implements OnInit, OnDestroy {
  history: DownloadInfo[] = [];
  private sub?: Subscription;

  dialogItem: DownloadInfo | null = null;
  dialogLoading = false;

  toastMsg = '';
  toastError = false;
  private toastTimer?: ReturnType<typeof setTimeout>;

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
    if (this.toastTimer) clearTimeout(this.toastTimer);
  }

  showToast(msg: string, error = false): void {
    this.toastMsg = msg;
    this.toastError = error;
    if (this.toastTimer) clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => {
      this.toastMsg = '';
    }, 3000);
  }

  clearAll(): void {
    if (!confirm(
      '🛡️ SAFETY CONFIRMATION\n\n' +
      'Remove ALL items from history?\n\n' +
      '✅ YOUR DOWNLOADED FILES WILL BE KEPT.\n' +
      '✅ Only the history list entries will be removed.\n\n' +
      'Press OK to proceed.'
    )) {
      return;
    }
    this.metube.clearHistory().subscribe({
      next: () => this.showToast('History cleared'),
      error: (err) => this.showToast('Failed to clear history: ' + (err.error?.msg || err.message), true),
    });
  }

  cleanup(id: string): void {
    this.metube.deleteDownloads([id], 'done').subscribe({
      next: () => this.showToast('Removed from history'),
      error: (err) => this.showToast('Failed to remove: ' + (err.error?.msg || err.message), true),
    });
  }

  refresh(item: DownloadInfo): void {
    this.metube.retryDownload(item).subscribe({
      next: () => this.showToast('Re-queued for download'),
      error: (err) => this.showToast('Failed to re-queue: ' + (err.error?.msg || err.message), true),
    });
  }

  confirmDelete(item: DownloadInfo): void {
    this.dialogItem = item;
    this.dialogLoading = false;
  }

  cancelDialog(): void {
    this.dialogItem = null;
    this.dialogLoading = false;
  }

  executeDelete(): void {
    if (!this.dialogItem) return;
    this.dialogLoading = true;
    this.metube.deleteDownloadWithFile(this.dialogItem, true).subscribe({
      next: (res) => {
        this.dialogItem = null;
        this.dialogLoading = false;
        if (res.success) {
          const fileCount = res.files_deleted?.length || 0;
          this.showToast(fileCount > 0 ? `Deleted (${fileCount} file${fileCount > 1 ? 's' : ''})` : 'Removed from history');
        } else {
          this.showToast('Delete failed: ' + (res.error || 'Unknown error'), true);
        }
      },
      error: (err) => {
        this.dialogItem = null;
        this.dialogLoading = false;
        this.showToast('Delete failed: ' + (err.error?.error || err.message), true);
      },
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
