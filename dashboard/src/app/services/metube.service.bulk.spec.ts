import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';
import { MetubeService, DownloadInfo, BulkDeleteResult } from './metube.service';

function mkItem(id: string, url: string): DownloadInfo {
  return {
    id,
    title: 'T-' + id,
    url,
    quality: 'best',
    format: 'any',
    folder: '',
    status: 'finished',
  } as DownloadInfo;
}

describe('MetubeService — bulk operations', () => {
  let service: MetubeService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [MetubeService, provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(MetubeService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => httpMock.verify());

  it('clearSelected with empty list returns ok WITHOUT issuing a request', () => {
    let result: any = null;
    service.clearSelected([], 'done').subscribe((r) => (result = r));
    expect(result).toEqual({ status: 'ok' });
    httpMock.expectNone((r) => r.url === '/api/delete');
  });

  it('clearSelected POSTs /delete with the URL list + where', () => {
    let result: any = null;
    service.clearSelected(['https://a', 'https://b'], 'done').subscribe((r) => (result = r));
    const req = httpMock.expectOne('/api/delete');
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual({ ids: ['https://a', 'https://b'], where: 'done' });
    req.flush({ status: 'ok' });
    expect(result).toEqual({ status: 'ok' });
  });

  it('deleteSelectedWithFiles aggregates per-item results', () => {
    const items = [mkItem('a', 'https://a'), mkItem('b', 'https://b'), mkItem('c', 'https://c')];
    let res: any = null;
    service.deleteSelectedWithFiles(items).subscribe((r) => (res = r));

    const reqs = httpMock.match((r) => r.url === '/api/delete-download');
    expect(reqs.length).toBe(3);
    reqs[0].flush({ success: true, files_deleted: ['/x.mp4'] });
    reqs[1].flush({ success: false, error: 'nope' });
    reqs[2].flush({ success: true, files_deleted: ['/y.mp4', '/y.json'] });

    expect(res!.total_requested).toBe(3);
    expect(res!.succeeded).toBe(2);
    expect(res!.files_deleted.sort()).toEqual(['/x.mp4', '/y.json', '/y.mp4']);
    expect(res!.errors.length).toBe(1);
    expect(res!.errors[0].error).toBe('nope');
  });

  it('deleteSelectedWithFiles handles network errors per item without aborting the batch', () => {
    const items = [mkItem('a', 'https://a'), mkItem('b', 'https://b')];
    let res: any = null;
    service.deleteSelectedWithFiles(items).subscribe((r) => (res = r));

    const reqs = httpMock.match((r) => r.url === '/api/delete-download');
    reqs[0].flush({ success: true });
    reqs[1].error(new ProgressEvent('error'), { status: 502, statusText: 'Bad Gateway' });

    expect(res!.total_requested).toBe(2);
    expect(res!.succeeded).toBe(1);
    expect(res!.errors.length).toBe(1);
  });

  it('deleteSelectedWithFiles with empty list completes synchronously with zero counts', () => {
    let res: any = null;
    service.deleteSelectedWithFiles([]).subscribe((r) => (res = r));
    expect(res).toEqual({ total_requested: 0, succeeded: 0, files_deleted: [], errors: [] });
    httpMock.expectNone(() => true);
  });

  it('deleteAllHistoryWithFiles fetches /history then deletes every done item', () => {
    let res: any = null;
    service.deleteAllHistoryWithFiles().subscribe((r) => (res = r));

    const histReq = httpMock.expectOne('/api/history');
    expect(histReq.request.method).toBe('GET');
    histReq.flush({
      done: [mkItem('a', 'https://a'), mkItem('b', 'https://b')],
      queue: [],
      pending: [],
    });

    const delReqs = httpMock.match((r) => r.url === '/api/delete-download');
    expect(delReqs.length).toBe(2);
    delReqs.forEach((r) => r.flush({ success: true }));

    expect(res!.succeeded).toBe(2);
    expect(res!.errors).toEqual([]);
  });

  it('clearAllQueue collects pending + queue URLs and POSTs /delete with where=queue', () => {
    let res: any = null;
    service.clearAllQueue().subscribe((r) => (res = r));

    const histReq = httpMock.expectOne('/api/history');
    histReq.flush({
      done: [mkItem('z', 'https://z')],
      queue: [mkItem('a', 'https://a')],
      pending: [mkItem('p', 'https://p')],
    });

    const delReq = httpMock.expectOne('/api/delete');
    expect(delReq.request.body.where).toBe('queue');
    expect(delReq.request.body.ids.sort()).toEqual(['https://a', 'https://p']);
    delReq.flush({ status: 'ok' });

    expect(res).toEqual({ status: 'ok' });
  });

  it('clearAllQueue with empty queue + empty pending completes WITHOUT a /delete request', () => {
    let res: any = null;
    service.clearAllQueue().subscribe((r) => (res = r));

    const histReq = httpMock.expectOne('/api/history');
    histReq.flush({ done: [], queue: [], pending: [] });

    httpMock.expectNone((r) => r.url === '/api/delete');
    expect(res).toEqual({ status: 'ok' });
  });
});
