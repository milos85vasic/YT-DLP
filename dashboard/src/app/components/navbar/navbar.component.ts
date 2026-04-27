import { Component, OnDestroy, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { Subscription } from 'rxjs';
import { MetubeService, ProfileStatusResponse } from '../../services/metube.service';

@Component({
  selector: 'app-navbar',
  standalone: true,
  imports: [CommonModule, RouterLink, RouterLinkActive],
  template: `
    <nav class="navbar">
      <div class="brand">
        <span class="logo">📥</span>
        <span class="title">YT-DLP Dashboard</span>
        <span
          class="profile-badge"
          *ngIf="profile"
          [class.vpn]="profile.vpn_active"
          [class.no-vpn]="profile.profile === 'no-vpn'"
          [class.unknown]="profile.profile !== 'vpn' && profile.profile !== 'no-vpn'"
          [attr.title]="profileTooltip"
        >
          <ng-container *ngIf="profile.vpn_active">🔒 VPN</ng-container>
          <ng-container *ngIf="profile.profile === 'no-vpn'">⚠ No VPN</ng-container>
          <ng-container *ngIf="profile.profile !== 'vpn' && profile.profile !== 'no-vpn'">? unknown</ng-container>
        </span>
        <span
          class="profile-badge unreach"
          *ngIf="profile && profile.metube_reachable === false"
          title="MeTube backend was not reachable from the landing proxy at the time this badge loaded — downloads will fail until it comes back."
        >
          ⚠ MeTube unreachable
        </span>
      </div>
      <div class="links">
        <a routerLink="/download" routerLinkActive="active">Download</a>
        <a routerLink="/queue" routerLinkActive="active">Queue</a>
        <a routerLink="/history" routerLinkActive="active">History</a>
      </div>
    </nav>
  `,
  styles: [`
    .navbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 24px;
      height: 56px;
      background: linear-gradient(90deg, #2b2b2b 0%, #3c3f41 100%);
      border-bottom: 1px solid rgba(169,183,198,0.08);
      position: sticky;
      top: 0;
      z-index: 100;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .logo { font-size: 22px; }
    .title {
      font-size: 18px;
      font-weight: 600;
      background: linear-gradient(90deg, #9d001e, #d9a441);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .profile-badge {
      font-size: 11px;
      padding: 3px 9px;
      border-radius: 999px;
      font-weight: 600;
      letter-spacing: 0.3px;
      cursor: help;
      border: 1px solid transparent;
    }
    .profile-badge.vpn      { background: rgba(106,135,89,0.15);  color: #6a8759; border-color: rgba(106,135,89,0.30); }
    .profile-badge.no-vpn   { background: rgba(217,164,65,0.12);  color: #d9a441; border-color: rgba(217,164,65,0.25); }
    .profile-badge.unknown  { background: rgba(169,183,198,0.08); color: #808080; border-color: rgba(169,183,198,0.15); }
    .profile-badge.unreach  { background: rgba(157,0,30,0.12);    color: #cc7832; border-color: rgba(157,0,30,0.30); }
    .links {
      display: flex;
      gap: 6px;
    }
    .links a {
      color: #808080;
      text-decoration: none;
      padding: 6px 16px;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 500;
      transition: all 0.2s ease;
    }
    .links a:hover {
      color: #a9b7c6;
      background: rgba(169,183,198,0.06);
    }
    .links a.active {
      color: #a9b7c6;
      background: rgba(157,0,30,0.15);
    }
  `],
})
export class NavbarComponent implements OnInit, OnDestroy {
  profile: ProfileStatusResponse | null = null;
  profileTooltip = '';
  private sub?: Subscription;

  constructor(private metube: MetubeService) {}

  ngOnInit(): void {
    this.sub = this.metube.getProfileStatus().subscribe({
      next: (p) => {
        this.profile = p;
        this.profileTooltip = this.buildTooltip(p);
      },
      error: () => {
        // Endpoint missing (older landing image) or network error — leave
        // the badge hidden rather than show a broken state.
        this.profile = null;
      },
    });
  }

  ngOnDestroy(): void {
    this.sub?.unsubscribe();
  }

  private buildTooltip(p: ProfileStatusResponse): string {
    if (p.vpn_active) {
      return 'Active compose profile: vpn. Downloads tunnel through openvpn-yt-dlp; metube shares its network namespace. Public entry on :8087.';
    }
    if (p.profile === 'no-vpn') {
      return 'Active compose profile: no-vpn. Downloads use the host network directly — TikTok / Bilibili / Rumble may IP-block or geo-block. Switch on the vpn profile (./start with USE_VPN=true) for residential or region-appropriate egress.';
    }
    return `Active compose profile: ${p.profile} (unrecognised — landing container may be from an older image without ACTIVE_PROFILE env).`;
  }
}
