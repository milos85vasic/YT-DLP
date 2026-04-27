import { TestBed, ComponentFixture } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';
import { provideRouter } from '@angular/router';
import { DownloadFormComponent } from './download-form.component';

describe('DownloadFormComponent — form re-enable after /add', () => {
  let fixture: ComponentFixture<DownloadFormComponent>;
  let component: DownloadFormComponent;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [DownloadFormComponent],
      providers: [provideHttpClient(), provideHttpClientTesting(), provideRouter([])],
    });
    fixture = TestBed.createComponent(DownloadFormComponent);
    component = fixture.componentInstance;
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    // Drain any pollForItem requests
    httpMock.match(() => true).forEach((r) => r.flush({ done: [], queue: [], pending: [] }));
  });

  it('does not submit an empty URL', () => {
    component.url = '   ';
    component.addDownload();
    httpMock.expectNone((r) => r.url === '/api/add');
    expect(component.loading).toBe(false);
  });

  it('sets loading=true while the /add POST is in flight', () => {
    component.url = 'https://example.com/v';
    component.addDownload();
    expect(component.loading).toBe(true);
    const req = httpMock.expectOne('/api/add');
    req.flush({ status: 'ok' });
  });

  it('clears loading=false AND empties the URL field as soon as /add returns ok (does NOT wait for tracker)', () => {
    component.url = 'https://example.com/v';
    component.addDownload();
    const req = httpMock.expectOne('/api/add');
    req.flush({ status: 'ok' });
    expect(component.loading).toBe(false);
    expect(component.url).toBe('');
  });

  it('keeps loading=true and tracker error when /add returns status:error', () => {
    component.url = 'https://example.com/v';
    component.addDownload();
    const req = httpMock.expectOne('/api/add');
    req.flush({ status: 'error', msg: 'extractor failed' });
    expect(component.loading).toBe(false);
    expect(component.tracker.state).toBe('error');
    expect(component.tracker.item?.msg).toContain('extractor failed');
    // URL field NOT cleared on error so the user can edit and retry
    expect(component.url).toBe('https://example.com/v');
  });

  it('on transport error sets loading=false and tracker.state=error', () => {
    component.url = 'https://example.com/v';
    component.addDownload();
    const req = httpMock.expectOne('/api/add');
    req.error(new ProgressEvent('error'), { status: 502, statusText: 'Bad Gateway' });
    expect(component.loading).toBe(false);
    expect(component.tracker.state).toBe('error');
  });

  it('a second addDownload while a previous tracker is active is allowed (form is no longer disabled)', () => {
    // First submit
    component.url = 'https://example.com/v1';
    component.addDownload();
    httpMock.expectOne('/api/add').flush({ status: 'ok' });
    expect(component.loading).toBe(false);

    // Second submit immediately after (form re-enabled)
    component.url = 'https://example.com/v2';
    component.addDownload();
    expect(component.loading).toBe(true);  // briefly true again
    httpMock.expectOne('/api/add').flush({ status: 'ok' });
    expect(component.loading).toBe(false);
    expect(component.url).toBe('');
  });
});
