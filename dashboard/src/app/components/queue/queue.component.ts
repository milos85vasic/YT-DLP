import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subscription } from 'rxjs';
import { MetubeService, DownloadInfo } from '../../services/metube.service';

@Component({
  selector: 'app-queue',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page">
      <div class="header-row">
        <h2>⏳ Download Queue</h2>
        <div class="header-actions" *ngIf="allItems.length > 0">
          <button
            class="btn-clear-all"
            (click)="clearAllQueue()"
            title="Cancel and remove ALL queue + pending items"
            data-testid="queue-clear-all"
          >
            🧹 Clear All ({{ allItems.length }})
          </button>
        </div>
      </div>

      <!-- Selection toolbar -->
      <div class="selection-toolbar" *ngIf="allItems.length > 0">
        <label class="select-all-label" data-testid="queue-select-all-label">
          <input
            type="checkbox"
            class="checkbox"
            [checked]="allSelected"
            [indeterminate]="someSelected && !allSelected"
            (change)="toggleSelectAll()"
            data-testid="queue-select-all"
          />
          <span *ngIf="selectedCount === 0">Select all</span>
          <span *ngIf="selectedCount > 0 && !allSelected">{{ selectedCount }} selected</span>
          <span *ngIf="allSelected">All {{ allItems.length }} selected</span>
        </label>
        <div class="batch-actions" *ngIf="selectedCount > 0">
          <button
            class="btn-batch-clear"
            (click)="clearSelected()"
            title="Cancel and remove selected items from queue"
            data-testid="queue-clear-selected"
          >
            🧹 Clear {{ selectedCount }}
          </button>
        </div>
      </div>

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
        <div
          class="item state-pending"
          *ngFor="let item of pending; trackBy: trackById"
          [class.selected]="isSelected(item)"
          [attr.data-testid]="'queue-item-' + item.id"
          [attr.data-status]="'pending'"
        >
          <input
            type="checkbox"
            class="checkbox row-checkbox"
            [checked]="isSelected(item)"
            (change)="toggleSelected(item)"
            [attr.data-testid]="'queue-row-checkbox-' + item.id"
            [attr.aria-label]="'Select pending ' + (item.title || item.url)"
          />
          <div class="thumb" [attr.title]="'pending'">⏳</div>
          <div class="info">
            <div class="title" [title]="item.title">{{ item.title || 'Preparing…' }}</div>
            <div class="meta">
              <span class="status-badge state-pending">pending</span>
              <span *ngIf="item.url" class="url" [title]="item.url">{{ item.url }}</span>
            </div>
          </div>
          <button class="btn-start" (click)="start(item)" title="Start download">▶️</button>
          <button class="btn-delete" (click)="confirmCancel(item)" title="Cancel" data-testid="queue-cancel-button">✕</button>
        </div>

        <!-- Active queue items (downloading / preparing / postprocessing / error / finished) -->
        <div
          class="item"
          *ngFor="let item of queue; trackBy: trackById"
          [class]="'item ' + stateClass(item)"
          [class.selected]="isSelected(item)"
          [attr.data-testid]="'queue-item-' + item.id"
          [attr.data-status]="item.status"
        >
          <input
            type="checkbox"
            class="checkbox row-checkbox"
            [checked]="isSelected(item)"
            (change)="toggleSelected(item)"
            [attr.data-testid]="'queue-row-checkbox-' + item.id"
            [attr.aria-label]="'Select ' + (item.title || item.url)"
          />
          <div class="thumb" [attr.title]="item.status">{{ stateIcon(item) }}</div>
          <div class="info">
            <div class="title" [title]="item.title">{{ item.title || 'Untitled' }}</div>
            <div class="meta">
              <span class="status-badge" [class]="'status-badge ' + stateClass(item)">
                {{ stateLabel(item) }}
              </span>
              <span *ngIf="item.speed">• {{ item.speed }}</span>
              <span *ngIf="item.eta">• ETA {{ item.eta }}</span>
              <span *ngIf="item.size">• {{ formatSize(item.size) }}</span>
              <span *ngIf="item.percent !== undefined && item.percent !== null && isActive(item)">• {{ item.percent | number:'1.0-1' }}%</span>
            </div>
            <!-- Error message -->
            <div *ngIf="item.msg" class="msg">{{ item.msg }}</div>
            <!-- URL for context -->
            <div *ngIf="item.url && item.status === 'error'" class="url" [title]="item.url">{{ item.url }}</div>
          </div>

          <div class="progress-wrap" *ngIf="isActive(item)">
            <div class="progress-bar" [class.active]="item.status === 'downloading' || item.status === 'preparing'">
              <div class="fill" [style.width.%]="item.percent || 0" [class.indeterminate]="!item.percent"></div>
            </div>
          </div>

          <div class="actions">
            <button *ngIf="item.status === 'error'" class="btn-retry" (click)="retry(item)" title="Retry">↻</button>
            <button class="btn-delete" (click)="confirmCancel(item)" title="Cancel" data-testid="queue-cancel-button">✕</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Cancel confirmation dialog (single item) -->
    <div class="dialog-overlay" *ngIf="cancelDialogItem" (click)="cancelDialog()" data-testid="queue-cancel-dialog">
      <div class="dialog" (click)="$event.stopPropagation()" role="dialog" aria-modal="true">
        <h3>✕ Cancel download?</h3>
        <p>You're about to cancel this download:</p>
        <div class="dialog-item">
          <strong>{{ cancelDialogItem.title || cancelDialogItem.url }}</strong>
          <span *ngIf="cancelDialogItem.percent !== undefined && cancelDialogItem.percent !== null" class="dialog-progress">
            currently at {{ cancelDialogItem.percent | number:'1.0-1' }}%
          </span>
        </div>
        <p class="dialog-info">
          The download will stop and be moved to History as
          <strong class="status-badge state-aborted">aborted</strong>.
          No partial files will be retained.
        </p>
        <div class="dialog-actions">
          <button class="btn-cancel" (click)="cancelDialog()" [disabled]="cancelDialogLoading">
            Keep downloading
          </button>
          <button
            class="btn-confirm"
            (click)="executeCancel()"
            [disabled]="cancelDialogLoading"
            data-testid="queue-cancel-confirm-button"
          >
            <span *ngIf="!cancelDialogLoading">Cancel download</span>
            <span *ngIf="cancelDialogLoading">Cancelling…</span>
          </button>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .page { padding: 24px; max-width: 900px; margin: 0 auto; }
    .header-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;
      gap: 12px;
      flex-wrap: wrap;
    }
    .header-row h2 { margin: 0; }
    .header-actions { display: flex; gap: 8px; flex-wrap: wrap; }
    .btn-clear-all,
    .btn-batch-clear {
      padding: 8px 14px;
      border-radius: 10px;
      cursor: pointer;
      font-size: 13px;
      font-weight: 600;
      transition: all 0.2s;
      border: 1px solid rgba(217,164,65,0.3);
      background: rgba(217,164,65,0.08);
      color: #d9a441;
    }
    .btn-clear-all:hover,
    .btn-batch-clear:hover { background: rgba(217,164,65,0.15); }
    .selection-toolbar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
      padding: 10px 14px;
      background: rgba(104,151,187,0.04);
      border: 1px solid rgba(104,151,187,0.12);
      border-radius: 10px;
      margin-bottom: 14px;
      flex-wrap: wrap;
    }
    .select-all-label {
      display: flex;
      align-items: center;
      gap: 8px;
      color: #a9b7c6;
      font-size: 13px;
      cursor: pointer;
      user-select: none;
    }
    .batch-actions { display: flex; gap: 8px; flex-wrap: wrap; }
    .checkbox {
      width: 16px;
      height: 16px;
      accent-color: #6897bb;
      cursor: pointer;
    }
    .row-checkbox { margin-top: 4px; }
    .item.selected { background: rgba(104,151,187,0.10); border-color: rgba(104,151,187,0.30); }
    h2 { margin: 0 0 20px; font-size: 20px; color: #a9b7c6; }
    .empty {
      text-align: center;
      padding: 60px 20px;
      color: #808080;
    }
    .empty-icon { font-size: 48px; margin-bottom: 12px; }
    .list { display: flex; flex-direction: column; gap: 12px; }
    .item {
      display: flex;
      align-items: flex-start;
      gap: 14px;
      padding: 16px 20px;
      background: rgba(169,183,198,0.04);
      border: 1px solid rgba(169,183,198,0.06);
      border-radius: 14px;
      transition: background 0.2s;
    }
    .item:hover { background: rgba(169,183,198,0.06); }
    /* Per-state borders + tinted backgrounds — mapped from stateClass(item) */
    .item.state-pending       { border-color: rgba(217,164,65,0.30); background: rgba(217,164,65,0.04); }
    .item.state-preparing     { border-color: rgba(104,151,187,0.30); background: rgba(104,151,187,0.04); }
    .item.state-downloading   { border-color: rgba(106,135,89,0.30);  background: rgba(106,135,89,0.04); }
    .item.state-postprocessing { border-color: rgba(152,118,170,0.30); background: rgba(152,118,170,0.04); }
    .item.state-finished      { border-color: rgba(106,135,89,0.50);  background: rgba(106,135,89,0.06); }
    .item.state-error         { border-color: rgba(157,0,30,0.40);    background: rgba(157,0,30,0.05); }
    .item.state-aborted       { border-color: rgba(204,120,50,0.30);  background: rgba(204,120,50,0.04); }
    .item.state-unknown       { border-color: rgba(169,183,198,0.10); }
    .thumb { font-size: 20px; margin-top: 2px; }
    .info { flex: 1; min-width: 0; }
    .title {
      font-size: 14px;
      font-weight: 600;
      color: #a9b7c6;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .meta {
      margin-top: 6px;
      font-size: 12px;
      color: #808080;
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      align-items: center;
    }
    .status-badge {
      padding: 2px 8px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.4px;
    }
    .status-badge.state-pending       { background: rgba(217,164,65,0.18);  color: #d9a441; }
    .status-badge.state-preparing     { background: rgba(104,151,187,0.18); color: #6897bb; }
    .status-badge.state-downloading   { background: rgba(106,135,89,0.18);  color: #6a8759; }
    .status-badge.state-postprocessing { background: rgba(152,118,170,0.18); color: #9876aa; }
    .status-badge.state-finished      { background: rgba(106,135,89,0.25);  color: #a5c178; }
    .status-badge.state-error         { background: rgba(157,0,30,0.20);    color: #cc7832; }
    .status-badge.state-aborted       { background: rgba(204,120,50,0.20);  color: #cc7832; }
    .status-badge.state-unknown       { background: rgba(169,183,198,0.10); color: #808080; }
    .msg {
      margin-top: 8px;
      padding: 8px 12px;
      background: rgba(157,0,30,0.08);
      border: 1px solid rgba(157,0,30,0.15);
      border-radius: 8px;
      font-size: 12px;
      color: #cc7832;
      font-family: monospace;
      white-space: pre-wrap;
      word-break: break-word;
    }
    .url {
      margin-top: 4px;
      font-size: 11px;
      color: #808080;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .progress-wrap {
      display: flex;
      align-items: center;
      gap: 10px;
      width: 220px;
      margin-top: 4px;
    }
    .progress-bar {
      flex: 1;
      height: 8px;
      background: rgba(169,183,198,0.10);
      border-radius: 4px;
      overflow: hidden;
      position: relative;
    }
    .progress-bar.active::after {
      /* Subtle moving shimmer over the unfilled portion so the bar
         visibly "lives" even when percent updates pause briefly. */
      content: '';
      position: absolute;
      inset: 0;
      background: linear-gradient(
        90deg,
        transparent 0%,
        rgba(255,255,255,0.06) 50%,
        transparent 100%
      );
      animation: progress-shimmer 1.6s linear infinite;
      pointer-events: none;
    }
    @keyframes progress-shimmer {
      0%   { transform: translateX(-100%); }
      100% { transform: translateX(100%); }
    }
    .fill {
      height: 100%;
      background: linear-gradient(90deg, #9d001e, #d9a441);
      border-radius: 4px;
      transition: width 0.4s ease;
    }
    .fill.indeterminate {
      /* No percent reported yet — animate a sliding bar so the user
         knows something is happening. */
      width: 30% !important;
      animation: progress-indeterminate 1.4s ease-in-out infinite;
    }
    @keyframes progress-indeterminate {
      0%   { transform: translateX(-100%); width: 30%; }
      50%  { transform: translateX(120%); width: 40%; }
      100% { transform: translateX(280%); width: 30%; }
    }
    .dialog-overlay {
      position: fixed;
      inset: 0;
      background: rgba(0,0,0,0.65);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 1000;
      padding: 20px;
    }
    .dialog {
      background: #3c3f41;
      border: 1px solid rgba(157,0,30,0.30);
      border-radius: 14px;
      padding: 22px 24px;
      max-width: 460px;
      width: 100%;
      color: #a9b7c6;
    }
    .dialog h3 { margin: 0 0 12px; font-size: 17px; }
    .dialog p { margin: 0 0 10px; font-size: 13px; line-height: 1.5; color: #808080; }
    .dialog-item {
      margin: 12px 0;
      padding: 10px 14px;
      background: rgba(0,0,0,0.18);
      border-radius: 10px;
      font-size: 13px;
    }
    .dialog-item strong { display: block; color: #a9b7c6; word-break: break-all; }
    .dialog-progress { display: block; margin-top: 4px; font-size: 11px; color: #6897bb; }
    .dialog-info { font-size: 12px; color: #808080; }
    .dialog-actions {
      margin-top: 16px;
      display: flex;
      justify-content: flex-end;
      gap: 10px;
    }
    .dialog-actions button {
      padding: 8px 16px;
      border-radius: 8px;
      border: none;
      cursor: pointer;
      font-size: 13px;
      font-weight: 600;
    }
    .btn-cancel {
      background: rgba(169,183,198,0.10);
      color: #a9b7c6;
    }
    .btn-cancel:hover { background: rgba(169,183,198,0.18); }
    .btn-confirm {
      background: rgba(157,0,30,0.20);
      color: #cc7832;
      border: 1px solid rgba(157,0,30,0.40);
    }
    .btn-confirm:hover:not(:disabled) { background: rgba(157,0,30,0.30); }
    .btn-confirm:disabled { opacity: 0.5; cursor: not-allowed; }
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
      background: rgba(157,0,30,0.1);
      color: #cc7832;
      cursor: pointer;
      font-size: 14px;
      transition: background 0.2s;
    }
    .btn-delete:hover { background: rgba(157,0,30,0.25); }
    .btn-retry {
      width: 32px;
      height: 32px;
      border-radius: 8px;
      border: none;
      background: rgba(106,135,89,0.1);
      color: #6a8759;
      cursor: pointer;
      font-size: 16px;
      transition: background 0.2s;
    }
    .btn-retry:hover { background: rgba(106,135,89,0.25); }
    .btn-start {
      width: 32px;
      height: 32px;
      border-radius: 8px;
      border: none;
      background: rgba(104,151,187,0.1);
      color: #6897bb;
      cursor: pointer;
      font-size: 14px;
      transition: background 0.2s;
    }
    .btn-start:hover { background: rgba(104,151,187,0.25); }
    @media (max-width: 640px) {
      .page { padding: 16px; }
      h2 { font-size: 18px; }
      .item { flex-wrap: wrap; gap: 10px; padding: 12px 14px; }
      .info { width: 100%; min-width: auto; }
      .progress-wrap { width: 100%; margin-top: 4px; }
      .actions { margin-left: auto; gap: 8px; }
      .btn-delete, .btn-retry, .btn-start { width: 40px; height: 40px; font-size: 16px; }
    }
    .loading {
      text-align: center;
      padding: 60px 20px;
      color: #808080;
    }
    .loading .spinner {
      width: 40px;
      height: 40px;
      border: 3px solid #4e5254;
      border-top-color: #9d001e;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin: 0 auto 16px;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    .error-state {
      text-align: center;
      padding: 60px 20px;
      color: #cc7832;
    }
    .error-icon { font-size: 48px; margin-bottom: 12px; }
    .error-state .btn-retry {
      width: auto;
      height: auto;
      padding: 10px 20px;
      margin-top: 16px;
      background: rgba(204,120,50,0.08);
      border: 1px solid rgba(204,120,50,0.3);
      color: #cc7832;
    }
    .error-state .btn-retry:hover { background: rgba(204,120,50,0.15); }
  `],
})
export class QueueComponent implements OnInit, OnDestroy {
  queue: DownloadInfo[] = [];
  pending: DownloadInfo[] = [];
  loading = true;
  error: string | null = null;
  private sub?: Subscription;

  selectedIds = new Set<string>();

  // Single-item cancel confirm dialog
  cancelDialogItem: DownloadInfo | null = null;
  cancelDialogLoading = false;

  // Status mapping table — keep in sync with the CSS .state-* classes
  // and the kept-in-history aborted recorder. If MeTube ever emits a
  // new status string, the fall-through ('unknown') keeps the layout
  // intact instead of silently rendering a blank badge.
  private static readonly STATE_META: Record<string, { icon: string; label: string; klass: string; active: boolean }> = {
    pending:        { icon: '⏳', label: 'pending',        klass: 'state-pending',        active: false },
    preparing:      { icon: '⚙️', label: 'preparing',      klass: 'state-preparing',      active: true  },
    downloading:    { icon: '⬇️', label: 'downloading',    klass: 'state-downloading',    active: true  },
    postprocessing: { icon: '🛠️', label: 'postprocessing', klass: 'state-postprocessing', active: true  },
    finished:       { icon: '✅', label: 'finished',       klass: 'state-finished',       active: false },
    error:          { icon: '❌', label: 'error',          klass: 'state-error',          active: false },
    aborted:        { icon: '🛑', label: 'aborted',        klass: 'state-aborted',        active: false },
  };

  constructor(private metube: MetubeService) {}

  stateMeta(item: DownloadInfo): { icon: string; label: string; klass: string; active: boolean } {
    const s = (item.status || '').toLowerCase();
    return QueueComponent.STATE_META[s] || { icon: '📄', label: s || 'unknown', klass: 'state-unknown', active: false };
  }

  stateIcon(item: DownloadInfo): string  { return this.stateMeta(item).icon; }
  stateLabel(item: DownloadInfo): string { return this.stateMeta(item).label; }
  stateClass(item: DownloadInfo): string { return this.stateMeta(item).klass; }
  isActive(item: DownloadInfo): boolean  { return this.stateMeta(item).active; }

  trackById(_index: number, item: DownloadInfo): string {
    return item.id;
  }

  isSelected(item: DownloadInfo): boolean {
    return this.selectedIds.has(item.id);
  }

  toggleSelected(item: DownloadInfo): void {
    if (this.selectedIds.has(item.id)) {
      this.selectedIds.delete(item.id);
    } else {
      this.selectedIds.add(item.id);
    }
  }

  toggleSelectAll(): void {
    if (this.allSelected) {
      this.selectedIds.clear();
    } else {
      this.selectedIds = new Set(this.allItems.map((i) => i.id));
    }
  }

  get selectedCount(): number {
    let n = 0;
    for (const item of this.allItems) {
      if (this.selectedIds.has(item.id)) n += 1;
    }
    return n;
  }

  get allSelected(): boolean {
    return this.allItems.length > 0 && this.selectedCount === this.allItems.length;
  }

  get someSelected(): boolean {
    return this.selectedCount > 0;
  }

  selectedItems(): DownloadInfo[] {
    return this.allItems.filter((i) => this.selectedIds.has(i.id));
  }

  clearAllQueue(): void {
    if (!confirm(
      `Clear ALL ${this.allItems.length} queue + pending items?\n\n` +
      `Active downloads will be cancelled. No files have been written yet.\n\n` +
      `Press OK to proceed.`
    )) return;
    this.metube.clearAllQueue().subscribe({
      next: () => {
        this.queue = [];
        this.pending = [];
        this.selectedIds.clear();
      },
      error: (err) => console.error('Clear queue failed', err),
    });
  }

  clearSelected(): void {
    const items = this.selectedItems();
    if (items.length === 0) return;
    if (!confirm(
      `Cancel ${items.length} selected item${items.length === 1 ? '' : 's'}?\n\n` +
      `No files have been written yet.\n\n` +
      `Press OK to proceed.`
    )) return;
    const urls = items.map((i) => i.url);
    this.metube.clearSelected(urls, 'queue').subscribe({
      next: () => {
        const removedIds = new Set(items.map((i) => i.id));
        this.pending = this.pending.filter((i) => !removedIds.has(i.id));
        this.queue = this.queue.filter((i) => !removedIds.has(i.id));
        removedIds.forEach((id) => this.selectedIds.delete(id));
      },
      error: (err) => console.error('Clear selected failed', err),
    });
  }

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

  /**
   * Open the cancel confirmation dialog for a single queue item.
   * Direct deletion without the dialog is forbidden — see CONST-034
   * (anti-bluff): destructive UI actions MUST visibly gate.
   */
  confirmCancel(item: DownloadInfo): void {
    this.cancelDialogItem = item;
    this.cancelDialogLoading = false;
  }

  /** Close the cancel dialog without doing anything. */
  cancelDialog(): void {
    this.cancelDialogItem = null;
    this.cancelDialogLoading = false;
  }

  /**
   * Confirmed cancel:
   *   1. Tell MeTube to drop it from the queue.
   *   2. Record the abort to landing's /api/aborted-history so it
   *      shows up on the History page with status='aborted' instead
   *      of vanishing silently (vendor MeTube doesn't preserve
   *      cancelled items).
   */
  executeCancel(): void {
    if (!this.cancelDialogItem) return;
    const item = this.cancelDialogItem;
    this.cancelDialogLoading = true;
    this.metube.deleteDownloads([item.url], 'queue').subscribe({
      next: () => this.recordAndClose(item),
      error: () => {
        // Even if /delete failed (item already gone, race with worker),
        // record the abort intent so the user sees it in history.
        this.recordAndClose(item);
      },
    });
  }

  private recordAndClose(item: DownloadInfo): void {
    this.metube.recordAbortedItem(item).subscribe({
      next: () => {
        this.cancelDialogLoading = false;
        this.cancelDialogItem = null;
        this.selectedIds.delete(item.id);
      },
      error: () => {
        // Non-fatal — the user got their cancellation; recording is
        // a best-effort UX nicety.
        this.cancelDialogLoading = false;
        this.cancelDialogItem = null;
        this.selectedIds.delete(item.id);
      },
    });
  }

  /** Legacy code-path used by selection toolbar's "Clear N". */
  delete(item: DownloadInfo, where: 'queue' | 'done'): void {
    this.metube.deleteDownloads([item.url], where).subscribe();
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

  start(item: DownloadInfo): void {
    // Moves a pending item to the active download queue
    this.metube.startDownloads([item.url]).subscribe({
      next: () => {},
      error: (err) => console.error('Start failed', err),
    });
  }

  retry(item: DownloadInfo): void {
    // For queue items in error state, delete and re-add.
    // For pending items, start them.
    if (item.status === 'error') {
      this.metube.retryDownload(item).subscribe({
        next: () => {},
        error: (err) => console.error('Retry failed', err),
      });
    } else {
      this.start(item);
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
