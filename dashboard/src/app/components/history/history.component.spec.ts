import { TestBed, ComponentFixture } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';
import { HistoryComponent } from './history.component';
import { DownloadInfo } from '../../services/metube.service';

function mkItem(overrides: Partial<DownloadInfo> = {}): DownloadInfo {
  return {
    id: overrides.id || `id-${Math.random().toString(36).slice(2)}`,
    title: overrides.title || 'Test Title',
    url: overrides.url || `https://example.com/v/${overrides.id || 'x'}`,
    quality: 'best',
    format: 'any',
    folder: '',
    status: 'finished',
    ...overrides,
  } as DownloadInfo;
}

describe('HistoryComponent — selection + bulk operations', () => {
  let fixture: ComponentFixture<HistoryComponent>;
  let component: HistoryComponent;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HistoryComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    fixture = TestBed.createComponent(HistoryComponent);
    component = fixture.componentInstance;
    httpMock = TestBed.inject(HttpTestingController);

    component.history = [
      mkItem({ id: 'a' }),
      mkItem({ id: 'b' }),
      mkItem({ id: 'c' }),
    ];
  });

  afterEach(() => {
    // Drain any polling requests the component fires from ngOnInit
    httpMock.match(() => true).forEach((r) => r.flush({ done: [], queue: [], pending: [] }));
  });

  // ---- Selection state machine ----

  it('starts with no items selected', () => {
    expect(component.selectedCount).toBe(0);
    expect(component.allSelected).toBe(false);
    expect(component.someSelected).toBe(false);
  });

  it('toggleSelected adds an item not in the set', () => {
    component.toggleSelected(component.history[0]);
    expect(component.isSelected(component.history[0])).toBe(true);
    expect(component.selectedCount).toBe(1);
    expect(component.someSelected).toBe(true);
    expect(component.allSelected).toBe(false);
  });

  it('toggleSelected removes an item already in the set', () => {
    component.toggleSelected(component.history[0]);
    component.toggleSelected(component.history[0]);
    expect(component.isSelected(component.history[0])).toBe(false);
    expect(component.selectedCount).toBe(0);
  });

  it('toggleSelectAll selects every history item when none are selected', () => {
    component.toggleSelectAll();
    expect(component.selectedCount).toBe(3);
    expect(component.allSelected).toBe(true);
  });

  it('toggleSelectAll clears selection when all items are selected', () => {
    component.toggleSelectAll();
    component.toggleSelectAll();
    expect(component.selectedCount).toBe(0);
    expect(component.allSelected).toBe(false);
  });

  it('selectedCount ignores stale ids no longer in history (poll-safe)', () => {
    component.selectedIds.add('x-no-longer-here');
    component.selectedIds.add('a');
    expect(component.selectedCount).toBe(1);
  });

  // ---- Confirm dialog gating ----

  it('openBulkDeleteDialog("selected") with empty selection shows a toast and does NOT open the dialog', () => {
    component.openBulkDeleteDialog('selected');
    expect(component.dialogScope).toBeNull();
    expect(component.toastError).toBe(true);
  });

  it('openBulkDeleteDialog("selected") populates dialogTargets from current selection', () => {
    component.toggleSelected(component.history[0]);
    component.toggleSelected(component.history[2]);
    component.openBulkDeleteDialog('selected');
    expect(component.dialogScope).toBe('selected');
    expect(component.dialogTargets.length).toBe(2);
    expect(component.dialogTargets.map((i) => i.id).sort()).toEqual(['a', 'c']);
  });

  it('openBulkDeleteDialog("all") with empty history shows a toast and does NOT open the dialog', () => {
    component.history = [];
    component.openBulkDeleteDialog('all');
    expect(component.dialogScope).toBeNull();
    expect(component.toastError).toBe(true);
  });

  it('openBulkDeleteDialog("all") populates dialogTargets with every history item', () => {
    component.openBulkDeleteDialog('all');
    expect(component.dialogScope).toBe('all');
    expect(component.dialogTargets.length).toBe(3);
  });

  it('confirm checkbox starts unchecked when the dialog opens', () => {
    component.openBulkDeleteDialog('all');
    expect(component.dialogConfirmAcknowledged).toBe(false);
  });

  it('cancelDialog resets every dialog field', () => {
    component.openBulkDeleteDialog('all');
    component.dialogConfirmAcknowledged = true;
    component.dialogLoading = true;
    component.dialogProgress = 5;
    component.cancelDialog();
    expect(component.dialogScope).toBeNull();
    expect(component.dialogTargets).toEqual([]);
    expect(component.dialogConfirmAcknowledged).toBe(false);
    expect(component.dialogLoading).toBe(false);
    expect(component.dialogProgress).toBe(0);
  });

  it('executeBulkDelete is a no-op when checkbox not acknowledged', () => {
    component.openBulkDeleteDialog('all');
    component.dialogConfirmAcknowledged = false;
    component.executeBulkDelete();
    // No HTTP request issued — verify by asking the testing controller.
    httpMock.expectNone((r) => r.url.includes('/delete-download'));
    expect(component.dialogLoading).toBe(false);
  });

  it('executeBulkDelete fires one /delete-download per target and clears history on success', () => {
    component.openBulkDeleteDialog('all');
    component.dialogConfirmAcknowledged = true;
    component.executeBulkDelete();

    const reqs = httpMock.match((r) => r.url === '/api/delete-download');
    expect(reqs.length).toBe(3);
    reqs.forEach((req) =>
      req.flush({ success: true, files_deleted: ['/downloads/x.mp4'] })
    );

    expect(component.history.length).toBe(0);
    expect(component.dialogScope).toBeNull();
  });

  it('executeBulkDelete keeps unrelated history items when only selected ones are deleted', () => {
    component.toggleSelected(component.history[0]);
    component.toggleSelected(component.history[1]);
    component.openBulkDeleteDialog('selected');
    component.dialogConfirmAcknowledged = true;
    component.executeBulkDelete();

    const reqs = httpMock.match((r) => r.url === '/api/delete-download');
    expect(reqs.length).toBe(2);
    reqs.forEach((req) => req.flush({ success: true }));

    expect(component.history.length).toBe(1);
    expect(component.history[0].id).toBe('c');
    expect(component.selectedCount).toBe(0);
  });

  // ---- Title text reflects scope ----

  it('dialogTitle differs per scope', () => {
    component.dialogScope = 'single';
    component.dialogTargets = [component.history[0]];
    expect(component.dialogTitle).toContain('this download');

    component.dialogScope = 'selected';
    component.dialogTargets = [component.history[0], component.history[1]];
    expect(component.dialogTitle).toContain('2 selected');

    component.dialogScope = 'all';
    component.dialogTargets = [...component.history];
    expect(component.dialogTitle).toContain('ALL 3');
  });
});
