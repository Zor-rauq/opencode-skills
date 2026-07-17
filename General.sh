#!/usr/bin/env bash
# generate-all.sh — génère toute l’arborescence + fichiers
# Usage : chmod +x generate-all.sh && ./generate-all.sh

set -euo pipefail

ROOT="angular-uom-mfe-demo"
mkdir -p "$ROOT"
cd "$ROOT"

# ------------------------------------------------------------------
# 1. Fichiers racine
# ------------------------------------------------------------------
cat > package.json <<'PKG'
{
  "name": "angular-uom-mfe-demo",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "start": "nx serve demo-app",
    "start:shell": "nx serve shell",
    "start:settings": "nx serve settings-mfe",
    "start:feature": "nx serve feature-mfe",
    "storybook": "nx storybook shared-uom",
    "build-storybook": "nx build-storybook shared-uom",
    "build": "nx run-many --target=build --projects=shell,settings-mfe,feature-mfe",
    "build:lib": "nx build shared-uom",
    "test": "nx test shared-uom",
    "lint": "nx lint shared-uom"
  },
  "dependencies": {
    "@angular/animations": "^21.0.0",
    "@angular/common": "^21.0.0",
    "@angular/compiler": "^21.0.0",
    "@angular/core": "^21.0.0",
    "@angular/forms": "^21.0.0",
    "@angular/platform-browser": "^21.0.0",
    "@angular/platform-browser-dynamic": "^21.0.0",
    "@angular/router": "^21.0.0",
    "@angular-architects/module-federation": "^21.0.0",
    "ngx-mask": "^20.0.3",
    "rxjs": "^7.8.2",
    "tslib": "^2.8.1",
    "zone.js": "^0.15.0"
  },
  "devDependencies": {
    "@angular-devkit/build-angular": "^21.0.0",
    "@angular/cli": "^21.0.0",
    "@angular/compiler-cli": "^21.0.0",
    "@nx/angular": "^21.0.0",
    "@nx/eslint": "^21.0.0",
    "@nx/js": "^21.0.0",
    "@nx/storybook": "^21.0.0",
    "@nx/web": "^21.0.0",
    "@storybook/addon-essentials": "^9.1.6",
    "@storybook/addon-interactions": "^9.1.6",
    "@storybook/angular": "^9.1.6",
    "@storybook/test": "^9.1.6",
    "@types/node": "^22.15.30",
    "eslint": "^9.30.1",
    "nx": "^21.0.0",
    "storybook": "^9.1.6",
    "typescript": "^5.9.2"
  },
  "engines": { "node": ">=22.0.0" }
}
PKG

cat > nx.json <<'NX'
{
  "$schema": "./node_modules/nx/schemas/nx-schema.json",
  "namedInputs": {
    "default": ["{projectRoot}/**/*", "sharedGlobals"],
    "production": ["default", "!{projectRoot}/**/*.stories.ts", "!{projectRoot}/.storybook/**/*"],
    "sharedGlobals": []
  },
  "plugins": []
}
NX

cat > tsconfig.base.json <<'TSBASE'
{
  "compileOnSave": false,
  "compilerOptions": {
    "rootDir": ".",
    "sourceMap": true,
    "declaration": false,
    "moduleResolution": "bundler",
    "emitDecoratorMetadata": false,
    "experimentalDecorators": true,
    "importHelpers": true,
    "target": "ES2022",
    "module": "ES2022",
    "lib": ["ES2022", "DOM"],
    "skipLibCheck": true,
    "skipDefaultLibCheck": true,
    "baseUrl": ".",
    "paths": {
      "@demo/shared-uom": ["libs/shared-uom/src/index.ts"]
    }
  },
  "exclude": ["node_modules", "tmp"]
}
TSBASE

# ------------------------------------------------------------------
# 2. Lib shared-uom
# ------------------------------------------------------------------
LIB="libs/shared-uom"
mkdir -p "$LIB/src/lib/config" "$LIB/src/lib/pipes" "$LIB/src/lib/directives" \
         "$LIB/src/lib/components/unit-input" "$LIB/src/lib/components/coordinate-input" \
         "$LIB/src/lib/providers" "$LIB/.storybook"

cat > "$LIB/project.json" <<'LIBPROJ'
{
  "name": "shared-uom",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "projectType": "library",
  "sourceRoot": "libs/shared-uom/src",
  "targets": {
    "build": {
      "executor": "@nx/angular:package",
      "options": {
        "project": "libs/shared-uom/tsconfig.lib.json",
        "outputPath": "dist/libs/shared-uom"
      }
    },
    "lint": { "executor": "@nx/eslint:lint" },
    "test": { "executor": "@nx/jest:jest" },
    "storybook": { "executor": "@nx/storybook:storybook", "options": { "configDir": "libs/shared-uom/.storybook" } },
    "build-storybook": { "executor": "@nx/storybook:build", "options": { "configDir": "libs/shared-uom/.storybook" } }
  }
}
LIBPROJ

cat > "$LIB/tsconfig.json" <<'LIBTSC'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "module": "ES2022" } }
LIBTSC

cat > "$LIB/tsconfig.lib.json" <<'LIBTSCLIB'
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "outDir": "../../dist/out-tsc",
    "declaration": true,
    "declarationMap": true,
    "inlineSources": true,
    "types": []
  },
  "include": ["src/**/*.ts"],
  "exclude": ["**/*.stories.ts", "**/*.spec.ts", ".storybook/**/*"]
}
LIBTSCLIB

cat > "$LIB/tsconfig.spec.json" <<'LIBTSCSPEC'
{ "extends": "./tsconfig.json", "compilerOptions": { "module": "ES2022", "types": ["jest", "node"] }, "include": ["**/*.spec.ts", "**/*.test.ts", "**/*.d.ts"] }
LIBTSCSPEC

# --- Config models ---
cat > "$LIB/src/lib/config/unit.models.ts" <<'MODELS'
export interface DisplayUnit {
  id: string;
  label: string;
  factor: number;
  offset?: number;
  formatPipe?: string;
  mask?: string;
  patterns?: Record<string, RegExp>;
}

export interface UnitDefinition {
  key: string;
  label: string;
  siUnit: string;
  defaultDisplayUnit: string;
  displayUnits: DisplayUnit[];
}

export interface UnitConfig {
  displayUnitId: string;
  precision?: number;
  locale?: string;
}

export type GlobalUnitConfig = Record<string, UnitConfig>;
MODELS

cat > "$LIB/src/lib/config/unit-config.token.ts" <<'TOKEN'
import { InjectionToken } from '@angular/core';
import { GlobalUnitConfig, UnitDefinition } from './unit.models';

export const UNIT_DEFINITIONS = new InjectionToken<UnitDefinition[]>('UNIT_DEFINITIONS');
export const DEFAULT_UNIT_CONFIG = new InjectionToken<GlobalUnitConfig>('DEFAULT_UNIT_CONFIG');
TOKEN

cat > "$LIB/src/lib/config/default-unit-config.ts" <<'DEFAULTS'
import { GlobalUnitConfig, UnitDefinition } from './unit.models';

export const DEFAULT_UNIT_DEFINITIONS: UnitDefinition[] = [
  { key: 'speed', label: 'Vitesse', siUnit: 'm/s', defaultDisplayUnit: 'km/h', displayUnits: [
    { id: 'm/s', label: 'm/s', factor: 1 },
    { id: 'km/h', label: 'km/h', factor: 3.6 },
    { id: 'mph', label: 'mph', factor: 2.23694 },
    { id: 'kn', label: 'nœuds', factor: 1.94384 }
  ]},
  { key: 'distance', label: 'Distance', siUnit: 'm', defaultDisplayUnit: 'km', displayUnits: [
    { id: 'm', label: 'm', factor: 1 },
    { id: 'km', label: 'km', factor: 0.001 },
    { id: 'mi', label: 'miles', factor: 0.000621371 },
    { id: 'nm', label: 'milles marins', factor: 0.000539957 }
  ]},
  { key: 'volume', label: 'Volume', siUnit: 'm³', defaultDisplayUnit: 'L', displayUnits: [
    { id: 'm³', label: 'm³', factor: 1 },
    { id: 'L', label: 'L', factor: 1000 },
    { id: 'mL', label: 'mL', factor: 1000000 },
    { id: 'gal', label: 'gal US', factor: 264.172 }
  ]},
  { key: 'coordinateLat', label: 'Latitude', siUnit: 'deg', defaultDisplayUnit: 'DMS', displayUnits: [
    { id: 'DD', label: 'DD', factor: 1, mask: 'separator.6' },
    { id: 'DMS', label: 'DMS', factor: 1, formatPipe: 'coordinateDMS' }
  ]},
  { key: 'coordinateLon', label: 'Longitude', siUnit: 'deg', defaultDisplayUnit: 'DMS', displayUnits: [
    { id: 'DD', label: 'DD', factor: 1, mask: 'separator.6' },
    { id: 'DMS', label: 'DMS', factor: 1, formatPipe: 'coordinateDMS' }
  ]}
];

export const DEFAULT_CONFIG: GlobalUnitConfig = {
  speed: { displayUnitId: 'km/h', precision: 1, locale: 'fr-FR' },
  distance: { displayUnitId: 'km', precision: 2, locale: 'fr-FR' },
  volume: { displayUnitId: 'L', precision: 2, locale: 'fr-FR' },
  coordinateLat: { displayUnitId: 'DMS', precision: 0, locale: 'fr-FR' },
  coordinateLon: { displayUnitId: 'DMS', precision: 0, locale: 'fr-FR' }
};
DEFAULTS

cat > "$LIB/src/lib/config/unit-config.service.ts" <<'SERVICE'
import { inject, Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';
import { DEFAULT_UNIT_CONFIG, UNIT_DEFINITIONS } from './unit-config.token';
import { DisplayUnit, GlobalUnitConfig, UnitConfig, UnitDefinition } from './unit.models';

@Injectable({ providedIn: 'platform' })
export class UnitConfigService {
  private readonly definitions = inject(UNIT_DEFINITIONS);
  private readonly defaults = inject(DEFAULT_UNIT_CONFIG);

  private readonly state = new BehaviorSubject<GlobalUnitConfig>(this.defaults);

  getConfig(key: string): UnitConfig {
    const def = this.definitions.find(d => d.key === key);
    const current = this.state.value[key];
    return {
      displayUnitId: current?.displayUnitId ?? def?.defaultDisplayUnit ?? '',
      precision: current?.precision ?? 2,
      locale: current?.locale ?? 'fr-FR'
    };
  }

  setConfig(key: string, partial: Partial<UnitConfig>): void {
    const next = { ...this.state.value, [key]: { ...this.getConfig(key), ...partial } };
    this.state.next(next);
  }

  getDisplayUnit(key: string): DisplayUnit | undefined {
    const cfg = this.getConfig(key);
    const def = this.definitions.find(d => d.key === key);
    return def?.displayUnits.find(u => u.id === cfg.displayUnitId);
  }

  convertToDisplay(key: string, siValue: number): number {
    const unit = this.getDisplayUnit(key);
    if (!unit) return siValue;
    return siValue * unit.factor + (unit.offset ?? 0);
  }

  convertToSI(key: string, displayValue: number): number {
    const unit = this.getDisplayUnit(key);
    if (!unit) return displayValue;
    return (displayValue - (unit.offset ?? 0)) / unit.factor;
  }

  formatValue(key: string, siValue: number): string {
    const cfg = this.getConfig(key);
    const unit = this.getDisplayUnit(key);
    if (!unit) return String(siValue);

    if (unit.formatPipe === 'coordinateDMS') {
      return this.formatCoordinateDms(siValue, key.includes('Lat'));
    }

    const displayValue = this.convertToDisplay(key, siValue);
    return new Intl.NumberFormat(cfg.locale, {
      minimumFractionDigits: cfg.precision ?? 0,
      maximumFractionDigits: cfg.precision ?? 0
    }).format(displayValue) + ` ${unit.label}`;
  }

  private formatCoordinateDms(decimal: number, isLat: boolean): string {
    const abs = Math.abs(decimal);
    const deg = Math.floor(abs);
    const minutesFloat = (abs - deg) * 60;
    const min = Math.floor(minutesFloat);
    const sec = Math.round((minutesFloat - min) * 60);
    const positive = isLat ? 'N' : 'E';
    const negative = isLat ? 'S' : 'W';
    const dir = decimal >= 0 ? positive : negative;
    return `${deg}°${min}'${sec}"${dir}`;
  }
}
SERVICE

# --- Pipes ---
cat > "$LIB/src/lib/pipes/unit-display.pipe.ts" <<'PIPE1'
import { Pipe, PipeTransform, inject } from '@angular/core';
import { UnitConfigService } from '../config/unit-config.service';

@Pipe({ name: 'unitDisplay', standalone: true, pure: false })
export class UnitDisplayPipe implements PipeTransform {
  private readonly units = inject(UnitConfigService);
  transform(value: number | null | undefined, unitKey: string): string {
    if (value == null) return '—';
    return this.units.formatValue(unitKey, value);
  }
}
PIPE1

cat > "$LIB/src/lib/pipes/coordinate-display.pipe.ts" <<'PIPE2'
import { Pipe, PipeTransform, inject } from '@angular/core';
import { UnitConfigService } from '../config/unit-config.service';

@Pipe({ name: 'coordinateDisplay', standalone: true, pure: false })
export class CoordinateDisplayPipe implements PipeTransform {
  private readonly units = inject(UnitConfigService);
  transform(value: { lat: number; lon: number } | null | undefined): string {
    if (!value) return '—';
    return `${this.units.formatValue('coordinateLat', value.lat)}, ${this.units.formatValue('coordinateLon', value.lon)}`;
  }
}
PIPE2

# --- Directive mask ---
cat > "$LIB/src/lib/directives/unit-mask.directive.ts" <<'MASK'
import { Directive, Input, OnInit, inject } from '@angular/core';
import { NgxMaskDirective, provideNgxMask } from 'ngx-mask';
import { UnitConfigService } from '../config/unit-config.service';

@Directive({
  selector: '[unitMask]',
  standalone: true,
  providers: [provideNgxMask()],
  hostDirectives: [{ directive: NgxMaskDirective }]
})
export class UnitMaskDirective implements OnInit {
  @Input() unitMask!: string;
  private readonly unitConfig = inject(UnitConfigService);
  private readonly mask = inject(NgxMaskDirective);
  ngOnInit(): void {
    const displayUnit = this.unitConfig.getDisplayUnit(this.unitMask);
    if (!displayUnit?.mask) return;
    this.mask.mask = displayUnit.mask;
  }
}
MASK

# --- Unit Input Component ---
cat > "$LIB/src/lib/components/unit-input/unit-input.component.ts" <<'UINTS'
import { Component, Input, Output, EventEmitter, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { UnitConfigService } from '../../config/unit-config.service';
import { UnitMaskDirective } from '../../directives/unit-mask.directive';

@Component({
  selector: 'lib-unit-input',
  standalone: true,
  imports: [FormsModule, UnitMaskDirective],
  templateUrl: './unit-input.component.html',
  styleUrl: './unit-input.component.scss'
})
export class UnitInputComponent {
  private readonly units = inject(UnitConfigService);
  @Input({ required: true }) unitKey!: string;
  @Input() label = '';
  @Input() value: number | null = null;
  @Output() valueChange = new EventEmitter<number | null>();
  displayValue = '';

  ngOnChanges(): void {
    this.displayValue = this.value == null ? '' : this.toDisplayString(this.value);
  }

  onInput(raw: string): void {
    this.displayValue = raw;
    const parsed = Number(raw.replace(',', '.').replace(/[^d.-]/g, ''));
    if (Number.isNaN(parsed)) { this.valueChange.emit(null); return; }
    this.valueChange.emit(this.units.convertToSI(this.unitKey, parsed));
  }

  private toDisplayString(siValue: number): string {
    return String(this.units.convertToDisplay(this.unitKey, siValue));
  }

  get unitLabel(): string { return this.units.getDisplayUnit(this.unitKey)?.label ?? ''; }
}
UINTS

cat > "$LIB/src/lib/components/unit-input/unit-input.component.html" <<'UINTH'
<div class="wrapper">
  @if (label) { <label class="label">{{ label }}</label> }
  <div class="input-row">
    <input class="input" [unitMask]="unitKey" [ngModel]="displayValue" (ngModelChange)="onInput($event)" />
    <span class="suffix">{{ unitLabel }}</span>
  </div>
</div>
UINTH

cat > "$LIB/src/lib/components/unit-input/unit-input.component.scss" <<'UINTCSS'
.wrapper { display: flex; flex-direction: column; gap: 6px; }
.label { font-size: 14px; color: #444; }
.input-row { display: flex; align-items: stretch; }
.input { flex: 1; border: 1px solid #cfd3d8; border-right: 0; border-radius: 8px 0 0 8px; padding: 10px 12px; font-size: 14px; }
.suffix { display: inline-flex; align-items: center; padding: 0 12px; background: #f2f4f7; border: 1px solid #cfd3d8; border-radius: 0 8px 8px 0; font-size: 13px; color: #555; }
UINTCSS

cat > "$LIB/src/lib/components/unit-input/unit-input.component.stories.ts" <<'UINSTORY'
import type { Meta, StoryObj } from '@storybook/angular';
import { applicationConfig } from '@storybook/angular';
import { UnitInputComponent } from './unit-input.component';
import { provideSharedUom } from '../../providers/provide-shared-uom';

const meta: Meta<UnitInputComponent> = {
  title: 'Shared UOM/Unit Input',
  component: UnitInputComponent,
  decorators: [applicationConfig({ providers: [provideSharedUom()] })],
  args: { label: 'Vitesse', unitKey: 'speed', value: 13.89 }
};
export default meta;
type Story = StoryObj<UnitInputComponent>;
export const Speed: Story = {};
export const Distance: Story = { args: { label: 'Distance', unitKey: 'distance', value: 15000 } };
export const Volume: Story = { args: { label: 'Volume', unitKey: 'volume', value: 0.003 } };
UINSTORY

# --- Coordinate Input Component ---
cat > "$LIB/src/lib/components/coordinate-input/coordinate-input.component.ts" <<'COORDTS'
import { Component, EventEmitter, Input, Output } from '@angular/core';
import { UnitInputComponent } from '../unit-input/unit-input.component';

@Component({
  selector: 'lib-coordinate-input',
  standalone: true,
  imports: [UnitInputComponent],
  templateUrl: './coordinate-input.component.html',
  styleUrl: './coordinate-input.component.scss'
})
export class CoordinateInputComponent {
  @Input() lat: number | null = null;
  @Input() lon: number | null = null;
  @Output() coordinatesChange = new EventEmitter<{ lat: number; lon: number } | null>();
  private currentLat: number | null = null;
  private currentLon: number | null = null;
  ngOnInit(): void { this.currentLat = this.lat; this.currentLon = this.lon; }
  onLat(value: number | null): void { this.currentLat = value; this.emit(); }
  onLon(value: number | null): void { this.currentLon = value; this.emit(); }
  private emit(): void {
    if (this.currentLat == null || this.currentLon == null) { this.coordinatesChange.emit(null); return; }
    this.coordinatesChange.emit({ lat: this.currentLat, lon: this.currentLon });
  }
}
COORDTS

cat > "$LIB/src/lib/components/coordinate-input/coordinate-input.component.html" <<'COORDHTML'
<div style="display:grid; grid-template-columns:1fr 1fr; gap:16px;">
  <lib-unit-input unitKey="coordinateLat" label="Latitude" [value]="lat" (valueChange)="onLat($event)" />
  <lib-unit-input unitKey="coordinateLon" label="Longitude" [value]="lon" (valueChange)="onLon($event)" />
</div>
COORDHTML

cat > "$LIB/src/lib/components/coordinate-input/coordinate-input.component.scss" <<'COORDCSS'
/* styles optionnels */
COORDCSS

# --- Provider barrel ---
cat > "$LIB/src/lib/providers/provide-shared-uom.ts" <<'PROVIDE'
import { EnvironmentProviders, makeEnvironmentProviders } from '@angular/core';
import { provideNgxMask } from 'ngx-mask';
import { DEFAULT_CONFIG, DEFAULT_UNIT_DEFINITIONS } from '../config/default-unit-config';
import { DEFAULT_UNIT_CONFIG, UNIT_DEFINITIONS } from '../config/unit-config.token';

export function provideSharedUom(): EnvironmentProviders {
  return makeEnvironmentProviders([
    provideNgxMask(),
    { provide: UNIT_DEFINITIONS, useValue: DEFAULT_UNIT_DEFINITIONS },
    { provide: DEFAULT_UNIT_CONFIG, useValue: DEFAULT_CONFIG }
  ]);
}
PROVIDE

# --- Public API ---
cat > "$LIB/src/index.ts" <<'INDEX'
export * from './lib/config/unit.models';
export * from './lib/config/unit-config.service';
export * from './lib/config/unit-config.token';
export * from './lib/config/default-unit-config';
export * from './lib/pipes/unit-display.pipe';
export * from './lib/pipes/coordinate-display.pipe';
export * from './lib/directives/unit-mask.directive';
export * from './lib/components/unit-input/unit-input.component';
export * from './lib/components/coordinate-input/coordinate-input.component';
export * from './lib/providers/provide-shared-uom';
INDEX

# --- Storybook config ---
cat > "$LIB/.storybook/main.ts" <<'STORYMAIN'
import type { StorybookConfig } from '@storybook/angular';
const config: StorybookConfig = {
  stories: ['../src/lib/**/*.stories.ts'],
  addons: ['@storybook/addon-essentials', '@storybook/addon-interactions'],
  framework: { name: '@storybook/angular', options: {} }
};
export default config;
STORYMAIN

cat > "$LIB/.storybook/preview.ts" <<'STORYPREV'
import type { Preview } from '@storybook/angular';
const preview: Preview = { parameters: { layout: 'centered' } };
export default preview;
STORYPREV


# ------------------------------------------------------------------
# 3. Apps
# ------------------------------------------------------------------

# ---- demo-app ----
APP="apps/demo-app"
mkdir -p "$APP/src/app"

cat > "$APP/project.json" <<'DEMOPROJ'
{
  "name": "demo-app",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "projectType": "application",
  "sourceRoot": "apps/demo-app/src",
  "targets": {
    "build": { "executor": "@angular-devkit/build-angular:application", "options": { "outputPath": "dist/apps/demo-app", "index": "apps/demo-app/src/index.html", "browser": "apps/demo-app/src/main.ts", "tsConfig": "apps/demo-app/tsconfig.app.json", "styles": ["apps/demo-app/src/styles.scss"] } },
    "serve": { "executor": "@angular-devkit/build-angular:dev-server", "options": { "buildTarget": "demo-app:build" } }
  }
}
DEMOPROJ

cat > "$APP/tsconfig.json" <<'DEMOTSC'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "module": "ES2022" } }
DEMOTSC

cat > "$APP/tsconfig.app.json" <<'DEMOTSCAPP'
{ "extends": "./tsconfig.json", "compilerOptions": { "outDir": "../../dist/out-tsc", "types": [] }, "include": ["src/**/*.ts"], "exclude": ["**/*.spec.ts", "**/*.stories.ts"] }
DEMOTSCAPP

cat > "$APP/tsconfig.spec.json" <<'DEMOTSCSPEC'
{ "extends": "./tsconfig.json", "compilerOptions": { "module": "ES2022", "types": ["jest", "node"] }, "include": ["**/*.spec.ts", "**/*.test.ts", "**/*.d.ts"] }
DEMOTSCSPEC

cat > "$APP/src/index.html" <<'DEMOHTML'
<!doctype html>
<html lang="fr"><head><meta charset="utf-8"/><title>Demo UOM</title><meta name="viewport" content="width=device-width, initial-scale=1"/></head><body><demo-root></demo-root></body></html>
DEMOHTML

cat > "$APP/src/styles.scss" <<'DEMOCSS'
html,body{margin:0;font-family:Arial,sans-serif;background:#f7f7f8;color:#222}
DEMOCSS

cat > "$APP/src/main.ts" <<'DEMOMAIN'
import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { AppComponent } from './app/app.component';
bootstrapApplication(AppComponent, appConfig).catch(console.error);
DEMOMAIN

cat > "$APP/src/app/app.config.ts" <<'DEMOAPPCFG'
import { ApplicationConfig } from '@angular/core';
import { provideSharedUom } from '@demo/shared-uom';
export const appConfig: ApplicationConfig = { providers: [provideSharedUom()] };
DEMOAPPCFG

cat > "$APP/src/app/app.component.ts" <<'DEMOCOMP'
import { Component, signal } from '@angular/core';
import { UnitInputComponent, CoordinateInputComponent, UnitDisplayPipe, CoordinateDisplayPipe, UnitConfigService } from '@demo/shared-uom';

@Component({
  selector: 'demo-root',
  standalone: true,
  imports: [UnitInputComponent, CoordinateInputComponent, UnitDisplayPipe, CoordinateDisplayPipe],
  templateUrl: './app.component.html',
  styleUrl: './app.component.scss'
})
export class AppComponent {
  speed = signal<number | null>(13.89);
  distance = signal<number | null>(12000);
  volume = signal<number | null>(0.003);
  lat = signal<number | null>(43.7102);
  lon = signal<number | null>(7.2620);
  constructor(private readonly unitConfig: UnitConfigService) {}
  setMetric(): void {
    this.unitConfig.setConfig('speed', { displayUnitId: 'km/h', precision: 1 });
    this.unitConfig.setConfig('distance', { displayUnitId: 'km', precision: 2 });
    this.unitConfig.setConfig('volume', { displayUnitId: 'L', precision: 2 });
    this.unitConfig.setConfig('coordinateLat', { displayUnitId: 'DMS', precision: 0 });
    this.unitConfig.setConfig('coordinateLon', { displayUnitId: 'DMS', precision: 0 });
  }
  setNautic(): void {
    this.unitConfig.setConfig('speed', { displayUnitId: 'kn', precision: 1 });
    this.unitConfig.setConfig('distance', { displayUnitId: 'nm', precision: 2 });
    this.unitConfig.setConfig('volume', { displayUnitId: 'gal', precision: 2 });
    this.unitConfig.setConfig('coordinateLat', { displayUnitId: 'DMS', precision: 0 });
    this.unitConfig.setConfig('coordinateLon', { displayUnitId: 'DMS', precision: 0 });
  }
  onCoordChange(value: { lat: number; lon: number } | null): void {
    this.lat.set(value?.lat ?? null); this.lon.set(value?.lon ?? null);
  }
}
DEMOCOMP

cat > "$APP/src/app/app.component.html" <<'DEMOHTMLC'
<div style="max-width:1100px;margin:24px auto;padding:24px;background:white;border-radius:12px;">
  <h1>Demo shared-uom</h1>
  <section style="margin-bottom:24px;">
    <h2>Configuration runtime</h2>
    <button (click)="setMetric()">Métrique (km/h, km, L, DMS)</button>
    <button (click)="setNautic()" style="margin-left:8px;">Nautique (kn, nm, gal, DMS)</button>
  </section>
  <section style="margin-bottom:24px;">
    <h2>Inputs</h2>
    <div style="display:grid; gap:16px;">
      <lib-unit-input unitKey="speed" label="Vitesse" [value]="speed()" (valueChange)="speed.set($event)" />
      <lib-unit-input unitKey="distance" label="Distance" [value]="distance()" (valueChange)="distance.set($event)" />
      <lib-unit-input unitKey="volume" label="Volume" [value]="volume()" (valueChange)="volume.set($event)" />
      <lib-coordinate-input [lat]="lat()" [lon]="lon()" (coordinatesChange)="onCoordChange($event)" />
    </div>
  </section>
  <section>
    <h2>Affichage via pipes</h2>
    <p>Speed SI: {{ speed() }}</p>
    <p>Speed display: {{ speed() | unitDisplay:'speed' }}</p>
    <p>Distance display: {{ distance() | unitDisplay:'distance' }}</p>
    <p>Volume display: {{ volume() | unitDisplay:'volume' }}</p>
    <p>Coordinates: {{ { lat: lat()!, lon: lon()! } | coordinateDisplay }}</p>
  </section>
</div>
DEMOHTMLC

cat > "$APP/src/app/app.component.scss" <<'DEMOCOMPCSS'
/* styles additionnels si besoin */
DEMOCOMPCSS

# ---- shell (MFE Host) ----
SHELL="apps/shell"
mkdir -p "$SHELL/src/app"

cat > "$SHELL/project.json" <<'SHELLPROJ'
{
  "name": "shell",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "projectType": "application",
  "sourceRoot": "apps/shell/src",
  "targets": {
    "build": { "executor": "@angular-devkit/build-angular:application", "options": { "outputPath": "dist/apps/shell", "index": "apps/shell/src/index.html", "browser": "apps/shell/src/main.ts", "tsConfig": "apps/shell/tsconfig.app.json", "styles": ["apps/shell/src/styles.scss"] } },
    "serve": { "executor": "@angular-devkit/build-angular:dev-server", "options": { "buildTarget": "shell:build", "port": 4200 } }
  }
}
SHELLPROJ

cat > "$SHELL/tsconfig.json" <<'SHELLTSC'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "module": "ES2022" } }
SHELLTSC

cat > "$SHELL/tsconfig.app.json" <<'SHELLTSCAPP'
{ "extends": "./tsconfig.json", "compilerOptions": { "outDir": "../../dist/out-tsc", "types": [] }, "include": ["src/**/*.ts"], "exclude": ["**/*.spec.ts", "**/*.stories.ts"] }
SHELLTSCAPP

cat > "$SHELL/webpack.config.js" <<'SHELLWP'
const { shareAll, withModuleFederationPlugin } = require('@angular-architects/module-federation/webpack');
module.exports = withModuleFederationPlugin({
  name: 'shell',
  remotes: {
    settingsMFE: 'http://localhost:4201/remoteEntry.js',
    featureMFE: 'http://localhost:4202/remoteEntry.js'
  },
  shared: { ...shareAll({ singleton: true, strictVersion: true, requiredVersion: 'auto' }), '@demo/shared-uom': { singleton: true, eager: true } }
});
SHELLWP

cat > "$SHELL/src/index.html" <<'SHELLHTML'
<!doctype html><html lang="fr"><head><meta charset="utf-8"/><title>Shell MFE</title><meta name="viewport" content="width=device-width, initial-scale=1"/></head><body><shell-root></shell-root></body></html>
SHELLHTML

cat > "$SHELL/src/styles.scss" <<'SHELLCSS'
html,body{margin:0;font-family:Arial,sans-serif;background:#f7f7f8}
SHELLCSS

cat > "$SHELL/src/main.ts" <<'SHELLMAIN'
import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { ShellComponent } from './app/shell.component';
bootstrapApplication(ShellComponent, appConfig).catch(console.error);
SHELLMAIN

cat > "$SHELL/src/app/app.config.ts" <<'SHELLAPPCFG'
import { ApplicationConfig } from '@angular/core';
import { provideSharedUom } from '@demo/shared-uom';
export const appConfig: ApplicationConfig = { providers: [provideSharedUom()] };
SHELLAPPCFG

cat > "$SHELL/src/app/routes.ts" <<'SHELLROUTES'
export const routes = [
  { path: 'settings', loadChildren: () => import('settingsMFE/Routes').then(m => m.settingsRoutes) },
  { path: 'feature', loadChildren: () => import('featureMFE/Routes').then(m => m.featureRoutes) },
  { path: '', redirectTo: 'feature', pathMatch: 'full' }
];
SHELLROUTES

cat > "$SHELL/src/app/shell.component.ts" <<'SHELLCOMP'
import { Component } from '@angular/core';
import { RouterOutlet, RouterLink } from '@angular/router';

@Component({
  selector: 'shell-root',
  standalone: true,
  imports: [RouterOutlet, RouterLink],
  template: `
    <nav style="padding:16px;background:#fff;border-bottom:1px solid #ddd;display:flex;gap:16px;">
      <a routerLink="/feature" routerLinkActive="active">Feature MFE</a>
      <a routerLink="/settings" routerLinkActive="active">Settings MFE</a>
    </nav>
    <router-outlet></router-outlet>
  `
})
export class ShellComponent {}
SHELLCOMP

# ---- settings-mfe (Remote) ----
SETTINGS="apps/settings-mfe"
mkdir -p "$SETTINGS/src/app/settings"

cat > "$SETTINGS/project.json" <<'SETTINGSPROJ'
{
  "name": "settings-mfe",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "projectType": "application",
  "sourceRoot": "apps/settings-mfe/src",
  "targets": {
    "build": { "executor": "@angular-devkit/build-angular:application", "options": { "outputPath": "dist/apps/settings-mfe", "index": "apps/settings-mfe/src/index.html", "browser": "apps/settings-mfe/src/main.ts", "tsConfig": "apps/settings-mfe/tsconfig.app.json", "styles": ["apps/settings-mfe/src/styles.scss"] } },
    "serve": { "executor": "@angular-devkit/build-angular:dev-server", "options": { "buildTarget": "settings-mfe:build", "port": 4201 } }
  }
}
SETTINGSPROJ

cat > "$SETTINGS/tsconfig.json" <<'SETTINGSTSC'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "module": "ES2022" } }
SETTINGSTSC

cat > "$SETTINGS/tsconfig.app.json" <<'SETTINGSTSCAPP'
{ "extends": "./tsconfig.json", "compilerOptions": { "outDir": "../../dist/out-tsc", "types": [] }, "include": ["src/**/*.ts"], "exclude": ["**/*.spec.ts", "**/*.stories.ts"] }
SETTINGSTSCAPP

cat > "$SETTINGS/webpack.config.js" <<'SETTINGSWP'
const { shareAll, withModuleFederationPlugin } = require('@angular-architects/module-federation/webpack');
module.exports = withModuleFederationPlugin({
  name: 'settingsMFE',
  exposes: { './Routes': './src/app/routes.ts', './SettingsComponent': './src/app/settings/settings.component.ts' },
  shared: { ...shareAll({ singleton: true, strictVersion: true, requiredVersion: 'auto' }), '@demo/shared-uom': { singleton: true, eager: true } }
});
SETTINGSWP

cat > "$SETTINGS/src/main.ts" <<'SETTINGSMAIN'
import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { SettingsComponent } from './app/settings/settings.component';
bootstrapApplication(SettingsComponent, appConfig).catch(console.error);
SETTINGSMAIN

cat > "$SETTINGS/src/app/app.config.ts" <<'SETTINGSAPPCFG'
import { ApplicationConfig } from '@angular/core';
import { provideSharedUom } from '@demo/shared-uom';
export const appConfig: ApplicationConfig = { providers: [provideSharedUom()] };
SETTINGSAPPCFG

cat > "$SETTINGS/src/app/routes.ts" <<'SETTINGSROUTES'
import { Routes } from '@angular/router';
export const settingsRoutes: Routes = [{ path: '', component: (await import('./settings/settings.component')).SettingsComponent }];
SETTINGSROUTES

cat > "$SETTINGS/src/app/settings/settings.component.ts" <<'SETTINGSCOMP'
import { Component, inject, computed } from '@angular/core';
import { UnitConfigService, UnitDefinition, UNIT_DEFINITIONS } from '@demo/shared-uom';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'lib-settings',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './settings.component.html'
})
export class SettingsComponent {
  private unitConfig = inject(UnitConfigService);
  definitions = inject(UNIT_DEFINITIONS);
  unitKeys = computed(() => this.definitions().map(d => d.key));
  getConfig(key: string) { return this.unitConfig.getConfig(key); }
  onChange(key: string, unitId: string) { this.unitConfig.setConfig(key, { displayUnitId: unitId }); }
  getDisplayUnits(key: string) {
    const def = this.definitions().find(d => d.key === key);
    return def?.displayUnits ?? [];
  }
}
SETTINGSCOMP

cat > "$SETTINGS/src/app/settings/settings.component.html" <<'SETTINGSHTML'
<div style="padding:24px;max-width:900px;margin:0 auto;">
  <h1>Paramétrage Unités (Singleton Partagé)</h1>
  <p>Les changements ici impactent immédiatement les autres MFEs.</p>
  @for (key of unitKeys(); track key) {
    <section style="margin-bottom:24px;padding:16px;border:1px solid #ddd;border-radius:8px;background:#fff;">
      <h3>{{ key }}</h3>
      <label style="display:block;margin-top:8px;">
        Unité d'affichage :
        <select [value]="getConfig(key).displayUnitId" (change)="onChange(key, $event.target.value)" style="margin-left:8px;padding:4px 8px;">
          @for (u of getDisplayUnits(key); track u.id) {
            <option [value]="u.id">{{ u.label }} ({{ u.id }})</option>
          }
        </select>
      </label>
      <label style="display:block;margin-top:8px;">
        Précision :
        <input type="number" [value]="getConfig(key).precision" (input)="onChange(key, { precision: Number($event.target.value) })" style="margin-left:8px;width:60px;" />
      </label>
    </section>
  }
</div>
SETTINGSHTML

# ---- feature-mfe (Remote) ----
FEATURE="apps/feature-mfe"
mkdir -p "$FEATURE/src/app/feature"

cat > "$FEATURE/project.json" <<'FEATUREPROJ'
{
  "name": "feature-mfe",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "projectType": "application",
  "sourceRoot": "apps/feature-mfe/src",
  "targets": {
    "build": { "executor": "@angular-devkit/build-angular:application", "options": { "outputPath": "dist/apps/feature-mfe", "index": "apps/feature-mfe/src/index.html", "browser": "apps/feature-mfe/src/main.ts", "tsConfig": "apps/feature-mfe/tsconfig.app.json", "styles": ["apps/feature-mfe/src/styles.scss"] } },
    "serve": { "executor": "@angular-devkit/build-angular:dev-server", "options": { "buildTarget": "feature-mfe:build", "port": 4202 } }
  }
}
FEATUREPROJ

cat > "$FEATURE/tsconfig.json" <<'FEATURETSC'
{ "extends": "../../tsconfig.base.json", "compilerOptions": { "module": "ES2022" } }
FEATURETSC

cat > "$FEATURE/tsconfig.app.json" <<'FEATURETSCAPP'
{ "extends": "./tsconfig.json", "compilerOptions": { "outDir": "../../dist/out-tsc", "types": [] }, "include": ["src/**/*.ts"], "exclude": ["**/*.spec.ts", "**/*.stories.ts"] }
FEATURETSCAPP

cat > "$FEATURE/webpack.config.js" <<'FEATUREWP'
const { shareAll, withModuleFederationPlugin } = require('@angular-architects/module-federation/webpack');
module.exports = withModuleFederationPlugin({
  name: 'featureMFE',
  exposes: { './Routes': './src/app/routes.ts', './FeatureComponent': './src/app/feature/feature.component.ts' },
  shared: { ...shareAll({ singleton: true, strictVersion: true, requiredVersion: 'auto' }), '@demo/shared-uom': { singleton: true, eager: true } }
});
FEATUREWP

cat > "$FEATURE/src/main.ts" <<'FEATUREMAIN'
import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { FeatureComponent } from './app/feature/feature.component';
bootstrapApplication(FeatureComponent, appConfig).catch(console.error);
FEATUREMAIN

cat > "$FEATURE/src/app/app.config.ts" <<'FEATUREAPPCFG'
import { ApplicationConfig } from '@angular/core';
import { provideSharedUom } from '@demo/shared-uom';
export const appConfig: ApplicationConfig = { providers: [provideSharedUom()] };
FEATUREAPPCFG

cat > "$FEATURE/src/app/routes.ts" <<'FEATUREROUTES'
import { Routes } from '@angular/router';
export const featureRoutes: Routes = [{ path: '', component: (await import('./feature/feature.component')).FeatureComponent }];
FEATUREROUTES

cat > "$FEATURE/src/app/feature/feature.component.ts" <<'FEATURECOMP'
import { Component, signal } from '@angular/core';
import { UnitInputComponent, CoordinateInputComponent, UnitDisplayPipe, CoordinateDisplayPipe, UnitConfigService } from '@demo/shared-uom';

@Component({
  selector: 'lib-feature',
  standalone: true,
  imports: [UnitInputComponent, CoordinateInputComponent, UnitDisplayPipe, CoordinateDisplayPipe],
  templateUrl: './feature.component.html',
  styleUrl: './feature.component.scss'
})
export class FeatureComponent {
  speed = signal<number | null>(13.89);
  distance = signal<number | null>(12000);
  volume = signal<number | null>(0.003);
  lat = signal<number | null>(43.7102);
  lon = signal<number | null>(7.2620);
  constructor(private readonly unitConfig: UnitConfigService) {}
  onCoordChange(v: { lat: number; lon: number } | null) { this.lat.set(v?.lat ?? null); this.lon.set(v?.lon ?? null); }
}
FEATURECOMP

cat > "$FEATURE/src/app/feature/feature.component.html" <<'FEATUREHTML'
<div style="padding:24px;max-width:900px;margin:0 auto;">
  <h1>Feature MFE — Consommateur shared-uom</h1>
  <p>Cette MFE utilise la config globale définie dans Settings MFE.</p>
  <section style="margin-bottom:24px;">
    <h2>Saisie</h2>
    <div style="display:grid;gap:16px;">
      <lib-unit-input unitKey="speed" label="Vitesse" [value]="speed()" (valueChange)="speed.set($event)" />
      <lib-unit-input unitKey="distance" label="Distance" [value]="distance()" (valueChange)="distance.set($event)" />
      <lib-unit-input unitKey="volume" label="Volume" [value]="volume()" (valueChange)="volume.set($event)" />
      <lib-coordinate-input [lat]="lat()" [lon]="lon()" (coordinatesChange)="onCoordChange($event)" />
    </div>
  </section>
  <section>
    <h2>Affichage (pipes)</h2>
    <p>Speed: {{ speed() | unitDisplay:'speed' }}</p>
    <p>Distance: {{ distance() | unitDisplay:'distance' }}</p>
    <p>Volume: {{ volume() | unitDisplay:'volume' }}</p>
    <p>Coords: {{ { lat: lat()!, lon: lon()! } | coordinateDisplay }}</p>
  </section>
</div>
FEATUREHTML

cat > "$FEATURE/src/app/feature/feature.component.scss" <<'FEATURECSS'
/* styles optionnels */
FEATURECSS

echo "✅ Arborescence complète générée dans $ROOT"
