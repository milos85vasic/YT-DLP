import { TestBed, ComponentFixture } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';
import { QueueComponent } from './queue.component';
import { DownloadInfo } from '../../services/metube.service';

function mkItem(overrides: Partial<DownloadInfo> = {}): DownloadInfo {
  return {
    id: overrides.id || `id-${Math.random().toString(36).slice(2)}`,
    title: overrides.title || 'Test',
    url: overrides.url || `https://example.com/q/${overrides.id || 'x'}`,
    quality: 'best',
    format: 'any',
    folder: '',
    status: 'downloading',
    ...overrides,
  } as DownloadInfo;
}

describe('QueueComponent — selection + bulk operations', () => {
  let fixture: ComponentFixture<QueueComponent>;
  let component: QueueComponent;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [QueueComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    fixture = TestBed.createComponent(QueueComponent);
    component = fixture.componentInstance;
    httpMock = TestBed.inject(HttpTestingController);

    component.pending = [
      mkItem({ id: 'p1', status: 'pending' }),
      mkItem({ id: 'p2', status: 'pending' }),
    ];
    component.queue = [
      mkItem({ id: 'q1' }),
      mkItem({ id: 'q2' }),
    ];
  });

  afterEach(() => {
    httpMock.match(() => true).forEach((r) => r.flush({ done: [], queue: [], pending: [] }));
  });

  it('allItems concatenates pending + queue', () => {
    expect(component.allItems.length).toBe(4);
    expect(component.allItems.map((i) => i.id)).toEqual(['p1', 'p2', 'q1', 'q2']);
  });

  it('toggleSelectAll selects every pending and queue item', () => {
    component.toggleSelectAll();
    expect(component.selectedCount).toBe(4);
    expect(component.allSelected).toBe(true);
  });

  it('toggleSelected toggles a single item', () => {
    component.toggleSelected(component.queue[0]);
    expect(component.isSelected(component.queue[0])).toBe(true);
    expect(component.selectedCount).toBe(1);
    expect(component.someSelected).toBe(true);
    expect(component.allSelected).toBe(false);
  });

  it('selectedCount ignores stale ids no longer in queue or pending', () => {
    component.selectedIds.add('not-here');
    component.selectedIds.add('p1');
    expect(component.selectedCount).toBe(1);
  });

  it('clearSelected with empty selection is a no-op (no HTTP request)', () => {
    component.selectedIds.clear();
    component.clearSelected();
    httpMock.expectNone((r) => r.url === '/api/delete');
  });

  it('clearSelected fires /delete with the selected URLs and where=queue (after confirm)', () => {
    spyOn(window, 'confirm').and.returnValue(true);
    component.toggleSelected(component.pending[0]);
    component.toggleSelected(component.queue[1]);
    component.clearSelected();

    const req = httpMock.expectOne('/api/delete');
    expect(req.request.method).toBe('POST');
    expect(req.request.body.where).toBe('queue');
    expect(req.request.body.ids.length).toBe(2);
    req.flush({ status: 'ok' });

    expect(component.pending.length).toBe(1);
    expect(component.queue.length).toBe(1);
    expect(component.selectedCount).toBe(0);
  });

  it('clearAllQueue (confirmed) fires /history then /delete with all URLs', () => {
    spyOn(window, 'confirm').and.returnValue(true);
    component.clearAllQueue();

    // First a /history GET to snapshot the URLs.
    const histReq = httpMock.expectOne('/api/history');
    expect(histReq.request.method).toBe('GET');
    histReq.flush({
      done: [],
      pending: [{ url: 'https://example.com/q/p1' }],
      queue: [{ url: 'https://example.com/q/q1' }, { url: 'https://example.com/q/q2' }],
    });

    const delReq = httpMock.expectOne('/api/delete');
    expect(delReq.request.body.where).toBe('queue');
    expect(delReq.request.body.ids.length).toBe(3);
    delReq.flush({ status: 'ok' });

    expect(component.pending.length).toBe(0);
    expect(component.queue.length).toBe(0);
  });

  it('clearAllQueue cancelled by confirm prompt does NOT call backend', () => {
    spyOn(window, 'confirm').and.returnValue(false);
    component.clearAllQueue();
    httpMock.expectNone((r) => r.url === '/api/delete');
    httpMock.expectNone((r) => r.url === '/api/history');
  });
});
