import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideRouter } from '@angular/router';
import { CookiesComponent } from './cookies.component';
import { PlatformCookieBucket } from '../../services/metube.service';

describe('CookiesComponent.buildPlatformRows', () => {
  let component: CookiesComponent;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [CookiesComponent],
      providers: [provideHttpClient(), provideRouter([])],
    });
    component = TestBed.createComponent(CookiesComponent).componentInstance;
  });

  it('returns an empty array when no platforms are present', () => {
    expect(component.buildPlatformRows({})).toEqual([]);
  });

  it('classifies a future-expiry bucket as fresh', () => {
    const farFuture = Math.floor(Date.now() / 1000) + 30 * 24 * 3600; // +30d
    const platforms = {
      youtube: <PlatformCookieBucket>{
        domains_present: ['.youtube.com'],
        session_count: 3,
        max_expiry_unix: farFuture,
        min_expiry_unix: farFuture,
      },
    };
    const rows = component.buildPlatformRows(platforms);
    expect(rows.length).toBe(1);
    expect(rows[0].key).toBe('youtube');
    expect(rows[0].display).toBe('YouTube');
    expect(rows[0].status).toBe('fresh');
    expect(rows[0].expiryHint).toMatch(/expires in/);
  });

  it('classifies an under-24h-expiry bucket as expiring', () => {
    const soon = Math.floor(Date.now() / 1000) + 60 * 60; // +1h
    const platforms = {
      tiktok: <PlatformCookieBucket>{
        domains_present: ['.tiktok.com'],
        session_count: 2,
        max_expiry_unix: soon,
        min_expiry_unix: soon,
      },
    };
    const rows = component.buildPlatformRows(platforms);
    expect(rows[0].status).toBe('expiring');
  });

  it('classifies a past-expiry bucket as expired', () => {
    const past = Math.floor(Date.now() / 1000) - 86400; // -1d
    const platforms = {
      facebook: <PlatformCookieBucket>{
        domains_present: ['.facebook.com'],
        session_count: 1,
        max_expiry_unix: past,
        min_expiry_unix: past,
      },
    };
    const rows = component.buildPlatformRows(platforms);
    expect(rows[0].status).toBe('expired');
    expect(rows[0].expiryHint).toMatch(/expired/);
  });

  it('treats min_expiry_unix=0 (session cookies) as fresh', () => {
    const platforms = {
      reddit: <PlatformCookieBucket>{
        domains_present: ['.reddit.com'],
        session_count: 5,
        max_expiry_unix: 0,
        min_expiry_unix: 0,
      },
    };
    const rows = component.buildPlatformRows(platforms);
    expect(rows[0].status).toBe('fresh');
    expect(rows[0].expiryHint).toMatch(/session cookies/);
  });

  it('uses the canonical platform key for display when no mapping exists', () => {
    const platforms = {
      'unknown-platform': <PlatformCookieBucket>{
        domains_present: ['.example.invalid'],
        session_count: 1,
        max_expiry_unix: 0,
        min_expiry_unix: 0,
      },
    };
    const rows = component.buildPlatformRows(platforms);
    expect(rows[0].display).toBe('unknown-platform');
    expect(rows[0].icon).toBe('🍪');
  });

  it('sorts platforms alphabetically by key', () => {
    const platforms = {
      tiktok:  <PlatformCookieBucket>{ domains_present: [], session_count: 1, max_expiry_unix: 0, min_expiry_unix: 0 },
      youtube: <PlatformCookieBucket>{ domains_present: [], session_count: 1, max_expiry_unix: 0, min_expiry_unix: 0 },
      facebook:<PlatformCookieBucket>{ domains_present: [], session_count: 1, max_expiry_unix: 0, min_expiry_unix: 0 },
    };
    const keys = component.buildPlatformRows(platforms).map((r) => r.key);
    expect(keys).toEqual(['facebook', 'tiktok', 'youtube']);
  });
});
