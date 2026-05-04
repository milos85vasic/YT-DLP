import { TestBed, fakeAsync, tick } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import {
  HttpTestingController,
  provideHttpClientTesting,
} from '@angular/common/http/testing';
import { MetubeService, DownloadInfo } from './metube.service';

describe('MetubeService', () => {
  let service: MetubeService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        MetubeService,
        provideHttpClient(),
        provideHttpClientTesting(),
      ],
    });
    service = TestBed.inject(MetubeService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => httpMock.verify());

  it('GETs /api/cookie-status with the new platforms field passed through', () => {
    let received: unknown = null;
    service.getCookieStatus().subscribe((r) => (received = r));

    const req = httpMock.expectOne('/api/cookie-status');
    expect(req.request.method).toBe('GET');
    req.flush({
      status: 'ok',
      has_cookies: true,
      cookie_age_minutes: 12.3,
      metube_reachable: true,
      platforms: {
        youtube: {
          domains_present: ['.youtube.com'],
          session_count: 3,
          max_expiry_unix: 2000000000,
          min_expiry_unix: 1900000000,
        },
      },
    });

    expect((received as any).has_cookies).toBe(true);
    expect((received as any).platforms.youtube.session_count).toBe(3);
  });

  it('GETs /api/profile-status', () => {
    let received: any = null;
    service.getProfileStatus().subscribe((r) => (received = r));

    const req = httpMock.expectOne('/api/profile-status');
    expect(req.request.method).toBe('GET');
    req.flush({
      profile: 'no-vpn',
      vpn_active: false,
      metube_url: 'http://metube-direct:8081',
      metube_reachable: true,
    });

    expect(received.profile).toBe('no-vpn');
    expect(received.vpn_active).toBe(false);
  });

  it('POSTs /api/add with the request body', () => {
    service
      .addDownload({ url: 'https://example.com/v', quality: 'best', format: 'any', folder: '' })
      .subscribe();

    const req = httpMock.expectOne('/api/add');
    expect(req.request.method).toBe('POST');
    expect(req.request.body.url).toBe('https://example.com/v');
    req.flush({ status: 'ok' });
  });

  it('getHistoryPolling survives a 502 error and continues emitting', fakeAsync(() => {
    const emissions: any[] = [];
    const sub = service.getHistoryPolling(100).subscribe((r) => emissions.push(r));
    tick(0);

    // First poll succeeds
    const req1 = httpMock.expectOne('/api/history');
    req1.flush({ done: [], queue: [], pending: [] });

    // Second poll returns 502
    tick(100);
    const req2 = httpMock.expectOne('/api/history');
    req2.error(new ProgressEvent('error'), { status: 502, statusText: 'Bad Gateway' });

    // Third poll succeeds again — stream must still be alive
    tick(100);
    const req3 = httpMock.expectOne('/api/history');
    req3.flush({ done: [{ id: '1', title: 'T', url: 'u', quality: 'best', format: 'any', folder: '', status: 'finished' }], queue: [], pending: [] });

    expect(emissions.length).toBe(2);
    expect(emissions[0].done.length).toBe(0);
    expect(emissions[1].done.length).toBe(1);
    sub.unsubscribe();
  }));

  it('retryDownload deletes from queue when where=queue', () => {
    service.retryDownload({ id: '1', title: 'T', url: 'https://example.com/v', quality: 'best', format: 'any', folder: '', status: 'error' }, 'queue').subscribe();

    const delReq = httpMock.expectOne('/api/delete');
    expect(delReq.request.body.where).toBe('queue');
    delReq.flush({ status: 'ok' });

    const addReq = httpMock.expectOne('/api/add');
    expect(addReq.request.body.url).toBe('https://example.com/v');
    addReq.flush({ status: 'ok' });
  });

  it('pollForItem survives a 502 error and continues polling', fakeAsync(() => {
    const emissions: (DownloadInfo | null)[] = [];
    const sub = service.pollForItem('https://example.com/v', 5, 100).subscribe((r) => emissions.push(r));
    tick(0);

    // First poll: 502 error
    const req1 = httpMock.expectOne('/api/history');
    req1.error(new ProgressEvent('error'), { status: 502, statusText: 'Bad Gateway' });

    // Second poll: success but no match
    tick(100);
    const req2 = httpMock.expectOne('/api/history');
    req2.flush({ done: [], queue: [], pending: [] });

    // Third poll: match found
    tick(100);
    const req3 = httpMock.expectOne('/api/history');
    req3.flush({ done: [], queue: [{ id: '1', title: 'T', url: 'https://example.com/v', quality: 'best', format: 'any', folder: '', status: 'downloading', percent: 50 }], pending: [] });

    expect(emissions.length).toBe(2);
    expect(emissions[0]).toBeNull();
    expect(emissions[1]?.status).toBe('downloading');
    sub.unsubscribe();
  }));
});
