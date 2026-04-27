import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import {
  HttpTestingController,
  provideHttpClientTesting,
} from '@angular/common/http/testing';
import { MetubeService } from './metube.service';

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
});
