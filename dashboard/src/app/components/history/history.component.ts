import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subscription } from 'rxjs';
import {
  MetubeService,
  DownloadInfo,
  BulkDeleteResult,
} from '../../services/metube.service';

type BulkScope = 'all' | 'selected' | 'single';

@Component({
  selector: 'app-history',
  standalone: true,
  imports: [CommonModule, FormsModule],
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
        <div class="header-actions" *ngIf="history.length > 0">
          <button
            class="btn-clear-all"
            (click)="clearAll()"
            title="Remove all items from history (files are kept)"
            data-testid="history-clear-all"
          >
            🧹 Clear All ({{ history.length }})
          </button>
          <button
            class="btn-delete-all"
            (click)="openBulkDeleteDialog('all')"
            title="Permanently delete all items AND files from disk"
            data-testid="history-delete-all"
          >
            🗑️ Delete All ({{ history.length }})
          </button>
        </div>
      </div>

      <!-- Selection toolbar -->
      <div class="selection-toolbar" *ngIf="history.length > 0">
        <label class="select-all-label" data-testid="history-select-all-label">
          <input
            type="checkbox"
            class="checkbox"
            [checked]="allSelected"
            [indeterminate]="someSelected && !allSelected"
            (change)="toggleSelectAll()"
            data-testid="history-select-all"
          />
          <span *ngIf="selectedCount === 0">Select all</span>
          <span *ngIf="selectedCount > 0 && !allSelected">{{ selectedCount }} selected</span>
          <span *ngIf="allSelected">All {{ history.length }} selected</span>
        </label>
        <div class="batch-actions" *ngIf="selectedCount > 0">
          <button
            class="btn-batch-clear"
            (click)="clearSelected()"
            title="Remove selected items from history (files are kept)"
            data-testid="history-clear-selected"
          >
            🧹 Clear {{ selectedCount }}
          </button>
          <button
            class="btn-batch-delete"
            (click)="openBulkDeleteDialog('selected')"
            title="Permanently delete selected items AND files from disk"
            data-testid="history-delete-selected"
          >
            🗑️ Delete {{ selectedCount }}
          </button>
        </div>
      </div>

      <div *ngIf="loading" class="loading">
        <div class="spinner"></div>
        <p>Loading history…</p>
      </div>

      <div *ngIf="error" class="error-state">
        <div class="error-icon">⚠️</div>
        <p>{{ error }}</p>
        <button class="btn-retry" (click)="retry()">↻ Retry</button>
      </div>

      <div *ngIf="!loading && !error && history.length === 0" class="empty">
        <div class="empty-icon">📭</div>
        <p>No completed downloads yet.</p>
      </div>

      <div class="list">
        <div
          class="item"
          *ngFor="let item of history; trackBy: trackById"
          [class.error]="item.status === 'error'"
          [class.finished]="item.status === 'finished'"
          [class.selected]="isSelected(item)"
        >
          <input
            type="checkbox"
            class="checkbox row-checkbox"
            [checked]="isSelected(item)"
            (change)="toggleSelected(item)"
            [attr.data-testid]="'history-row-checkbox-' + item.id"
            [attr.aria-label]="'Select ' + (item.title || item.url)"
          />
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
            <button class="btn-action btn-cleanup" (click)="cleanup(item)" title="Remove from history (keep file)">🧹</button>
            <!-- Refresh: re-download -->
            <button class="btn-action btn-refresh" (click)="refresh(item)" title="Re-download">↻</button>
            <!-- Delete: remove from history + delete file -->
            <button class="btn-action btn-delete" (click)="confirmDelete(item)" title="Delete file + remove from history">🗑️</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Confirmation Dialog (unified — single / selected / all) -->
    <div class="dialog-overlay" *ngIf="dialogScope" (click)="cancelDialog()" data-testid="history-delete-dialog">
      <div class="dialog" (click)="$event.stopPropagation()" role="dialog" aria-modal="true">
        <h3>🗑️ Confirm Permanent Deletion</h3>
        <p>{{ dialogTitle }}</p>

        <!-- Single-item preview -->
        <div class="dialog-item" *ngIf="dialogScope === 'single' && dialogItem">
          <strong>{{ dialogItem.title || 'Untitled' }}</strong>
          <span *ngIf="dialogItem.filename">{{ dialogItem.filename }}</span>
        </div>

        <!-- Multi-item preview -->
        <div class="dialog-list" *ngIf="dialogScope !== 'single'">
          <ul class="dialog-list-items">
            <li *ngFor="let it of dialogTargetsPreview">
              <strong>{{ it.title || 'Untitled' }}</strong>
              <span *ngIf="it.filename" class="dialog-filename">{{ it.filename }}</span>
            </li>
          </ul>
          <p class="dialog-list-more" *ngIf="dialogTargets.length > dialogTargetsPreview.length">
            …and {{ dialogTargets.length - dialogTargetsPreview.length }} more
          </p>
        </div>

        <p class="dialog-warning">
          ⚠ This will remove <strong>{{ dialogTargets.length }}</strong>
          history entr{{ dialogTargets.length === 1 ? 'y' : 'ies' }}
          AND delete the corresponding file{{ dialogTargets.length === 1 ? '' : 's' }} from disk.
          <strong>This action cannot be undone.</strong>
        </p>

        <label class="dialog-confirm-checkbox" data-testid="history-delete-confirm-checkbox-label">
          <input
            type="checkbox"
            [(ngModel)]="dialogConfirmAcknowledged"
            data-testid="history-delete-confirm-checkbox"
          />
          I understand that the file{{ dialogTargets.length === 1 ? '' : 's' }} on disk will be deleted permanently.
        </label>

        <div class="dialog-actions">
          <button class="btn-cancel" (click)="cancelDialog()" [disabled]="dialogLoading">
            Cancel
          </button>
          <button
            class="btn-confirm"
            (click)="executeBulkDelete()"
            [disabled]="dialogLoading || !dialogConfirmAcknowledged"
            data-testid="history-delete-confirm-button"
          >
            <span *ngIf="!dialogLoading">Delete Permanently</span>
            <span *ngIf="dialogLoading">Deleting {{ dialogProgress }} / {{ dialogTargets.length }}…</span>
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
      background: rgba(106,135,89,0.06);
      border: 1px solid rgba(106,135,89,0.15);
      border-radius: 14px;
      color: #808080;
      font-size: 13px;
      line-height: 1.6;
    }
    .safety-banner strong {
      display: block;
      color: #6a8759;
      font-size: 15px;
      margin-bottom: 6px;
    }
    .safety-banner p { margin: 0 0 6px; }
    .safety-banner .warning-small {
      margin-top: 8px;
      padding-top: 8px;
      border-top: 1px solid rgba(217,164,65,0.15);
      color: #d9a441;
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
    h2 { margin: 0; font-size: 20px; color: #a9b7c6; }
    .header-actions { display: flex; gap: 8px; flex-wrap: wrap; }
    .btn-clear-all,
    .btn-delete-all,
    .btn-batch-clear,
    .btn-batch-delete {
      padding: 8px 14px;
      border-radius: 10px;
      cursor: pointer;
      font-size: 13px;
      font-weight: 600;
      transition: all 0.2s;
    }
    .btn-clear-all,
    .btn-batch-clear {
      border: 1px solid rgba(217,164,65,0.3);
      background: rgba(217,164,65,0.08);
      color: #d9a441;
    }
    .btn-clear-all:hover,
    .btn-batch-clear:hover { background: rgba(217,164,65,0.15); }
    .btn-delete-all,
    .btn-batch-delete {
      border: 1px solid rgba(157,0,30,0.3);
      background: rgba(157,0,30,0.08);
      color: #cc7832;
    }
    .btn-delete-all:hover,
    .btn-batch-delete:hover { background: rgba(157,0,30,0.18); }
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
    .dialog-list {
      max-height: 220px;
      overflow-y: auto;
      margin: 12px 0;
      padding: 8px 12px;
      background: rgba(0,0,0,0.18);
      border: 1px solid rgba(169,183,198,0.10);
      border-radius: 10px;
    }
    .dialog-list-items {
      list-style: none;
      margin: 0;
      padding: 0;
      font-size: 12px;
      color: #a9b7c6;
    }
    .dialog-list-items li {
      padding: 4px 0;
      border-bottom: 1px solid rgba(169,183,198,0.05);
    }
    .dialog-list-items li:last-child { border-bottom: none; }
    .dialog-list-items strong { font-weight: 600; display: block; }
    .dialog-filename { font-family: monospace; font-size: 11px; color: #808080; }
    .dialog-list-more { margin-top: 6px; font-size: 11px; color: #808080; font-style: italic; }
    .dialog-confirm-checkbox {
      display: flex;
      align-items: flex-start;
      gap: 8px;
      margin: 10px 0 16px;
      padding: 10px 12px;
      background: rgba(217,164,65,0.06);
      border: 1px solid rgba(217,164,65,0.20);
      border-radius: 10px;
      color: #d9a441;
      font-size: 13px;
      cursor: pointer;
      user-select: none;
    }
    .dialog-confirm-checkbox input { margin-top: 2px; }
    .empty {
      text-align: center;
      padding: 60px 20px;
      color: #808080;
    }
    .empty-icon { font-size: 48px; margin-bottom: 12px; }
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
    .btn-retry {
      margin-top: 16px;
      padding: 10px 20px;
      border-radius: 10px;
      border: 1px solid rgba(204,120,50,0.3);
      background: rgba(204,120,50,0.08);
      color: #cc7832;
      cursor: pointer;
      font-size: 14px;
      font-weight: 600;
      transition: all 0.2s;
    }
    .btn-retry:hover { background: rgba(204,120,50,0.15); }
    .list { display: flex; flex-direction: column; gap: 12px; }
    .item {
      display: flex;
      align-items: flex-start;
      gap: 14px;
      padding: 14px 18px;
      background: rgba(169,183,198,0.04);
      border: 1px solid rgba(169,183,198,0.06);
      border-radius: 14px;
      transition: background 0.2s;
    }
    .item:hover { background: rgba(169,183,198,0.06); }
    .item.error { border-color: rgba(157,0,30,0.3); background: rgba(157,0,30,0.03); }
    .item.finished { border-color: rgba(106,135,89,0.15); }
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
      margin-top: 4px;
      font-size: 12px;
      color: #808080;
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
    .status.finished { background: rgba(106,135,89,0.12); color: #6a8759; }
    .status.error { background: rgba(157,0,30,0.12); color: #cc7832; }
    .filename {
      margin-top: 6px;
      font-size: 11px;
      color: #808080;
      font-family: monospace;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .url {
      margin-top: 4px;
      font-size: 11px;
      color: #808080;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
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
      background: rgba(217,164,65,0.08);
      color: #d9a441;
    }
    .btn-cleanup:hover { background: rgba(217,164,65,0.2); }
    .btn-refresh {
      background: rgba(104,151,187,0.08);
      color: #6897bb;
    }
    .btn-refresh:hover { background: rgba(104,151,187,0.2); }
    .btn-delete {
      background: rgba(157,0,30,0.08);
      color: #cc7832;
    }
    .btn-delete:hover { background: rgba(157,0,30,0.2); }

    @media (max-width: 640px) {
      .page { padding: 16px; }
      h2 { font-size: 18px; }
      .item { flex-wrap: wrap; gap: 10px; padding: 12px 14px; }
      .info { width: 100%; min-width: auto; }
      .actions { margin-left: auto; gap: 8px; }
      .btn-action { width: 40px; height: 40px; font-size: 16px; }
      .safety-banner { padding: 12px 16px; font-size: 12px; }
      .dialog { padding: 20px; max-width: calc(100% - 32px); border-radius: 12px; }
      .dialog-actions { flex-wrap: wrap; justify-content: stretch; gap: 8px; }
      .dialog-actions button { flex: 1; min-width: 120px; }
    }

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
      background: #2b2b2b;
      border: 1px solid rgba(169,183,198,0.1);
      border-radius: 16px;
      padding: 28px;
      max-width: 420px;
      width: 100%;
    }
    .dialog h3 { margin: 0 0 12px; font-size: 18px; color: #a9b7c6; }
    .dialog p { margin: 0 0 16px; font-size: 14px; color: #808080; }
    .dialog-item {
      background: rgba(169,183,198,0.04);
      border-radius: 10px;
      padding: 12px 14px;
      margin-bottom: 16px;
    }
    .dialog-item strong {
      display: block;
      color: #a9b7c6;
      font-size: 14px;
      margin-bottom: 4px;
    }
    .dialog-item span {
      font-size: 12px;
      color: #808080;
      font-family: monospace;
    }
    .dialog-warning {
      color: #cc7832 !important;
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
      border: 1px solid rgba(169,183,198,0.15);
      background: transparent;
      color: #808080;
      cursor: pointer;
      font-size: 14px;
    }
    .btn-cancel:hover { background: rgba(169,183,198,0.05); }
    .btn-confirm {
      padding: 10px 18px;
      border-radius: 10px;
      border: none;
      background: linear-gradient(90deg, #9d001e, #c4002a);
      color: #a9b7c6;
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
      background: rgba(106,135,89,0.12);
      border: 1px solid rgba(106,135,89,0.2);
      border-radius: 12px;
      color: #6a8759;
      font-size: 14px;
      z-index: 1001;
      animation: toastIn 0.3s ease;
    }
    .toast.error {
      background: rgba(157,0,30,0.12);
      border-color: rgba(157,0,30,0.2);
      color: #cc7832;
    }
    @keyframes toastIn {
      from { opacity: 0; transform: translate(-50%, 20px); }
      to { opacity: 1; transform: translate(-50%, 0); }
    }
  `],
})
export class HistoryComponent implements OnInit, OnDestroy {
  history: DownloadInfo[] = [];
  loading = true;
  error: string | null = null;
  private sub?: Subscription;

  // ----- Multi-scope confirm dialog state -----
  // dialogScope === null  → dialog hidden
  //               'single' → single-item delete (legacy 🗑️ row button)
  //               'selected' → bulk delete from current selection
  //               'all'      → bulk delete every history item
  dialogScope: BulkScope | null = null;
  dialogItem: DownloadInfo | null = null;        // populated for 'single'
  dialogTargets: DownloadInfo[] = [];            // populated for 'selected' / 'all'
  dialogConfirmAcknowledged = false;
  dialogLoading = false;
  dialogProgress = 0;

  // ----- Selection state -----
  selectedIds = new Set<string>();

  toastMsg = '';
  toastError = false;
  private toastTimer?: ReturnType<typeof setTimeout>;

  constructor(private metube: MetubeService) {}

  ngOnInit(): void {
    this.sub = this.metube.getHistoryPolling(1000).subscribe({
      next: (data) => {
        this.loading = false;
        this.error = null;
        this.history = data.done || [];
      },
      error: (err) => {
        this.loading = false;
        this.error = 'Failed to load history. Is the MeTube service running?';
        console.error('History poll error', err);
      },
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

  retry(): void {
    this.loading = true;
    this.error = null;
    this.sub?.unsubscribe();
    this.sub = this.metube.getHistoryPolling(1000).subscribe({
      next: (data) => {
        this.loading = false;
        this.error = null;
        this.history = data.done || [];
      },
      error: (err) => {
        this.loading = false;
        this.error = 'Failed to load history. Is the MeTube service running?';
        console.error('History poll error', err);
      },
    });
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
      next: () => {
        this.history = [];
        this.showToast('History cleared');
      },
      error: (err) => this.showToast('Failed to clear history: ' + (err.error?.msg || err.message), true),
    });
  }

  cleanup(item: DownloadInfo): void {
    this.metube.deleteDownloads([item.url], 'done').subscribe({
      next: () => {
        this.history = this.history.filter(i => i.id !== item.id);
        this.showToast('Removed from history');
      },
      error: (err) => this.showToast('Failed to remove: ' + (err.error?.msg || err.message), true),
    });
  }

  refresh(item: DownloadInfo): void {
    this.metube.retryDownload(item).subscribe({
      next: () => this.showToast('Re-queued for download'),
      error: (err) => this.showToast('Failed to re-queue: ' + (err.error?.msg || err.message), true),
    });
  }

  // ----- Selection helpers -----

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
      this.selectedIds = new Set(this.history.map((i) => i.id));
    }
  }

  get selectedCount(): number {
    // Count only IDs that are still present in history (the polling
    // loop may have removed an item the user had selected).
    let n = 0;
    for (const item of this.history) {
      if (this.selectedIds.has(item.id)) n += 1;
    }
    return n;
  }

  get allSelected(): boolean {
    return this.history.length > 0 && this.selectedCount === this.history.length;
  }

  get someSelected(): boolean {
    return this.selectedCount > 0;
  }

  selectedItems(): DownloadInfo[] {
    return this.history.filter((i) => this.selectedIds.has(i.id));
  }

  // ----- Single-item legacy 🗑️ button -----

  confirmDelete(item: DownloadInfo): void {
    this.dialogScope = 'single';
    this.dialogItem = item;
    this.dialogTargets = [item];
    this.dialogConfirmAcknowledged = false;
    this.dialogLoading = false;
    this.dialogProgress = 0;
  }

  // ----- Bulk dialog opener -----

  openBulkDeleteDialog(scope: 'all' | 'selected'): void {
    const targets = scope === 'all' ? [...this.history] : this.selectedItems();
    if (targets.length === 0) {
      this.showToast(scope === 'all' ? 'History is empty' : 'No items selected', true);
      return;
    }
    this.dialogScope = scope;
    this.dialogItem = null;
    this.dialogTargets = targets;
    this.dialogConfirmAcknowledged = false;
    this.dialogLoading = false;
    this.dialogProgress = 0;
  }

  cancelDialog(): void {
    this.dialogScope = null;
    this.dialogItem = null;
    this.dialogTargets = [];
    this.dialogConfirmAcknowledged = false;
    this.dialogLoading = false;
    this.dialogProgress = 0;
  }

  get dialogTitle(): string {
    switch (this.dialogScope) {
      case 'single':
        return 'Are you sure you want to permanently delete this download?';
      case 'selected':
        return `You are about to permanently delete ${this.dialogTargets.length} selected item${this.dialogTargets.length === 1 ? '' : 's'} and their files from disk.`;
      case 'all':
        return `You are about to permanently delete ALL ${this.dialogTargets.length} history item${this.dialogTargets.length === 1 ? '' : 's'} and their files from disk.`;
      default:
        return '';
    }
  }

  /** First few items shown in the bulk dialog preview. */
  get dialogTargetsPreview(): DownloadInfo[] {
    return this.dialogTargets.slice(0, 5);
  }

  // ----- Bulk delete executor -----

  executeBulkDelete(): void {
    if (this.dialogTargets.length === 0 || !this.dialogConfirmAcknowledged) return;
    this.dialogLoading = true;
    this.dialogProgress = 0;

    this.metube.deleteSelectedWithFiles(this.dialogTargets).subscribe({
      next: (result: BulkDeleteResult) => {
        const deletedIds = new Set(this.dialogTargets.map((i) => i.id));
        this.history = this.history.filter((i) => !deletedIds.has(i.id));
        deletedIds.forEach((id) => this.selectedIds.delete(id));
        this.cancelDialog();
        this.summarizeBulkResult(result);
      },
      error: (err) => {
        this.cancelDialog();
        this.showToast('Bulk delete failed: ' + (err.error?.error || err.message), true);
      },
    });
  }

  // ----- Bulk clear (no files) -----

  clearSelected(): void {
    const items = this.selectedItems();
    if (items.length === 0) {
      this.showToast('No items selected', true);
      return;
    }
    if (!confirm(
      `Remove ${items.length} item${items.length === 1 ? '' : 's'} from history?\n\n` +
      `✅ Files on disk are KEPT.\n` +
      `Press OK to proceed.`
    )) return;
    const urls = items.map((i) => i.url);
    this.metube.clearSelected(urls, 'done').subscribe({
      next: () => {
        const removedIds = new Set(items.map((i) => i.id));
        this.history = this.history.filter((i) => !removedIds.has(i.id));
        removedIds.forEach((id) => this.selectedIds.delete(id));
        this.showToast(`Cleared ${items.length} item${items.length === 1 ? '' : 's'}`);
      },
      error: (err) => this.showToast('Failed to clear: ' + (err.error?.msg || err.message), true),
    });
  }

  private summarizeBulkResult(result: BulkDeleteResult): void {
    if (result.errors.length === 0) {
      const fileCount = result.files_deleted.length;
      this.showToast(
        `Deleted ${result.succeeded} item${result.succeeded === 1 ? '' : 's'}` +
        (fileCount > 0 ? ` (${fileCount} file${fileCount === 1 ? '' : 's'})` : '')
      );
    } else if (result.succeeded === 0) {
      this.showToast(
        `All ${result.errors.length} delete${result.errors.length === 1 ? '' : 's'} failed: ` +
        result.errors[0].error,
        true,
      );
    } else {
      this.showToast(
        `Deleted ${result.succeeded} of ${result.total_requested}; ` +
        `${result.errors.length} failed (${result.errors[0].error})`,
        true,
      );
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
