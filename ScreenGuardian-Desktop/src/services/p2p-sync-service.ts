/**
 * P2P Sync Service - mDNS/Bonjour-based LAN sync
 *
 * Discovery: Uses mDNS (multicast DNS) to advertise and discover
 * ScreenGuardian devices on the local network. No IP scanning.
 *
 * Protocol:
 *   1. Each device advertises _screenguardian._tcp via mDNS
 *   2. Discovered devices appear as "pending" in device list
 *   3. User approves + enters pairing code to enable encrypted sync
 *   4. Only approved + paired devices exchange data
 */

import * as dgram from 'dgram';
import * as dns from 'dns';
import * as http from 'http';
import * as crypto from 'crypto';
import { EventEmitter } from 'events';
import { LocalStore } from './local-store';
import { todayDate } from '../utils/time-utils';
import { StopReason, ScreenSession, DailySummary } from './types';

const MDNS_GROUP = '224.0.0.251';
const MDNS_PORT = 5353;
const SERVICE_TYPE = '_screenguardian._tcp.local';
const SYNC_PORT = 19090; // HTTP sync port
const SYNC_INTERVAL_MS = 60 * 1000; // 1 minute
const ADVERTISE_INTERVAL_MS = 30 * 1000; // re-advertise every 30s

interface DiscoveredDevice {
  deviceId: string;
  deviceName: string;
  platform: string;
  ip: string;
  port: number;
  version: string;
  discoveredAt: string;
  approved: boolean;
  paired: boolean;
}

export class P2PSyncService extends EventEmitter {
  private store: LocalStore;
  private httpServer: http.Server | null = null;
  private mdnsSocket: dgram.Socket | null = null;
  private syncTimer: NodeJS.Timeout | null = null;
  private advertiseTimer: NodeJS.Timeout | null = null;
  private _running = false;
  private _paired = false;
  private _pairingCode: string | null = null;

  private devices = new Map<string, DiscoveredDevice>();

  constructor(store: LocalStore) {
    super();
    this.store = store;
  }

  // ============================================================
  // Lifecycle
  // ============================================================

  async start(pairingCode?: string): Promise<void> {
    if (this._running) return;

    if (pairingCode) {
      this._pairingCode = pairingCode;
      this._paired = true;
    }

    // Start HTTP server for sync
    this.httpServer = http.createServer((req, res) => this.handleRequest(req, res));
    this.httpServer.listen(SYNC_PORT, '0.0.0.0', () => {
      console.log(`[P2P] HTTP sync server on port ${SYNC_PORT}`);
    });

    // Start mDNS
    await this.startMdns();

    // Periodic sync
    this.syncTimer = setInterval(() => this.syncWithAll(), SYNC_INTERVAL_MS);

    // Re-advertise periodically
    this.advertiseTimer = setInterval(() => this.advertise(), ADVERTISE_INTERVAL_MS);

    this._running = true;
    console.log('[P2P] Service started with mDNS discovery');
  }

  stop(): void {
    if (this.httpServer) {
      this.httpServer.close();
      this.httpServer = null;
    }
    if (this.mdnsSocket) {
      try { this.mdnsSocket.close(); } catch {}
      this.mdnsSocket = null;
    }
    if (this.syncTimer) { clearInterval(this.syncTimer); this.syncTimer = null; }
    if (this.advertiseTimer) { clearInterval(this.advertiseTimer); this.advertiseTimer = null; }
    this._running = false;
  }

  // ============================================================
  // mDNS Discovery
  // ============================================================

  private async startMdns(): Promise<void> {
    this.mdnsSocket = dgram.createSocket({ type: 'udp4', reuseAddr: true });

    this.mdnsSocket.on('message', (msg, rinfo) => {
      this.handleMdnsMessage(msg, rinfo.address);
    });

    this.mdnsSocket.on('error', (err) => {
      console.error('[P2P] mDNS socket error:', err);
    });

    // Bind and join multicast group
    await new Promise<void>((resolve, reject) => {
      this.mdnsSocket!.bind(MDNS_PORT, () => {
        try {
          this.mdnsSocket!.addMembership(MDNS_GROUP);
          this.mdnsSocket!.setMulticastTTL(255);
          this.mdnsSocket!.setMulticastLoopback(true);
          resolve();
        } catch (e) {
          reject(e);
        }
      });
    });

    // Initial advertisement
    this.advertise();

    // Send query to discover existing devices
    this.sendQuery();

    console.log('[P2P] mDNS listener started');
  }

  private advertise(): void {
    if (!this.mdnsSocket) return;

    const deviceId = this.store.deviceId;
    const deviceName = this.store.deviceName;
    const platform = this.store.deviceInfo.platform;
    const instanceName = `${deviceId}.${SERVICE_TYPE}`;

    // Build mDNS response packet (simplified)
    // In production, use a proper DNS packet builder
    const records: Buffer[] = [];

    // PTR record: _screenguardian._tcp.local -> <instance>
    records.push(this.buildDnsRecord(SERVICE_TYPE, 'PTR', instanceName));

    // SRV record: <instance> -> hostname port
    records.push(this.buildDnsRecord(instanceName, 'SRV', `${SYNC_PORT} ${this.getLocalIP()}`));

    // TXT record: device info
    const txtData = [
      `id=${deviceId}`,
      `name=${deviceName}`,
      `platform=${platform}`,
      `version=${require('../../../package.json').version}`,
    ];
    records.push(this.buildDnsRecord(instanceName, 'TXT', txtData.join(',')));

    const packet = this.buildMdnsPacket(records);

    this.mdnsSocket.send(packet, 0, packet.length, MDNS_PORT, MDNS_GROUP, (err) => {
      if (err) console.error('[P2P] mDNS advertise error:', err);
    });
  }

  private sendQuery(): void {
    if (!this.mdnsSocket) return;

    // Send a simple mDNS query for _screenguardian._tcp.local
    const packet = this.buildMdnsQuery(SERVICE_TYPE);
    this.mdnsSocket.send(packet, 0, packet.length, MDNS_PORT, MDNS_GROUP);
  }

  private handleMdnsMessage(msg: Buffer, fromIP: string): void {
    // Skip our own messages
    const localIP = this.getLocalIP();
    if (fromIP === localIP) return;

    try {
      // Parse mDNS response to extract device info
      const deviceInfo = this.parseMdnsResponse(msg);
      if (!deviceInfo || deviceInfo.deviceId === this.store.deviceId) return;

      // Register or update discovered device
      const existing = this.devices.get(deviceInfo.deviceId);
      if (existing) {
        existing.ip = fromIP;
        existing.port = deviceInfo.port || SYNC_PORT;
        existing.deviceName = deviceInfo.deviceName || existing.deviceName;
        existing.platform = deviceInfo.platform || existing.platform;
      } else {
        this.devices.set(deviceInfo.deviceId, {
          deviceId: deviceInfo.deviceId,
          deviceName: deviceInfo.deviceName || 'Unknown Device',
          platform: deviceInfo.platform || 'unknown',
          ip: fromIP,
          port: deviceInfo.port || SYNC_PORT,
          version: deviceInfo.version || '1.0.0',
          discoveredAt: new Date().toISOString(),
          approved: false,
          paired: false,
        });
        console.log(`[P2P] Discovered device: ${deviceInfo.deviceName} (${fromIP})`);
        this.emit('deviceDiscovered', deviceInfo);
      }
    } catch (e) {
      // Ignore parse errors (might be other mDNS traffic)
    }
  }

  // ============================================================
  // HTTP Sync Server
  // ============================================================

  private async handleRequest(req: http.IncomingMessage, res: http.ServerResponse): Promise<void> {
    const url = new URL(req.url || '/', `http://${req.headers.host}`);
    const path = url.pathname;

    // Ping (for discovery verification)
    if (path === '/api/ping' && req.method === 'GET') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        deviceId: this.store.deviceId,
        deviceName: this.store.deviceName,
        platform: this.store.deviceInfo.platform,
        version: require('../../../package.json').version,
      }));
      return;
    }

    // Pairing verification
    if (path === '/api/pair' && req.method === 'POST') {
      const body = await this.readBody(req);
      const { pairingCode, deviceId } = JSON.parse(body);
      if (pairingCode === this._pairingCode && this._pairingCode) {
        this.devices.get(deviceId)?.paired = true;
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'paired' }));
      } else {
        res.writeHead(403);
        res.end(JSON.stringify({ status: 'invalid_code' }));
      }
      return;
    }

    // Auth check for sync endpoints
    const deviceId = req.headers['x-sg-device'] as string;
    const authHmac = req.headers['x-sg-auth'] as string;
    const timestamp = req.headers['x-sg-time'] as string;

    if (!deviceId || !this.isApproved(deviceId)) {
      res.writeHead(403);
      res.end(JSON.stringify({ error: 'device not trusted' }));
      return;
    }

    if (!this.verifyHmac(authHmac, timestamp, deviceId)) {
      res.writeHead(403);
      res.end(JSON.stringify({ error: 'auth failed' }));
      return;
    }

    // Sync endpoints
    if (path === '/api/sync/sessions' && req.method === 'GET') {
      const month = url.searchParams.get('month') || this.currentMonth();
      const sessions = this.store.loadSessions(month);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(this.encrypt(JSON.stringify(sessions.map(s => s.toJson ? s : s))));
      return;
    }

    if (path === '/api/sync/sessions' && req.method === 'POST') {
      const raw = await this.readBody(req);
      const data = this.decrypt(raw);
      if (!data) { res.writeHead(400); return; }
      await this.mergeSessions(JSON.parse(data));
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{"status":"ok"}');
      return;
    }

    if (path === '/api/sync/summaries' && req.method === 'GET') {
      const month = url.searchParams.get('month') || this.currentMonth();
      const summaries = this.store.loadSummaries(month);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(this.encrypt(JSON.stringify(summaries)));
      return;
    }

    if (path === '/api/sync/summaries' && req.method === 'POST') {
      const raw = await this.readBody(req);
      const data = this.decrypt(raw);
      if (!data) { res.writeHead(400); return; }
      await this.mergeSummaries(JSON.parse(data));
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{"status":"ok"}');
      return;
    }

    res.writeHead(404);
    res.end('{"error":"not found"}');
  }

  // ============================================================
  // Sync Logic
  // ============================================================

  async syncWithAll(): Promise<{ uploaded: number; downloaded: number }> {
    if (!this._paired) return { uploaded: 0, downloaded: 0 };

    let totalUp = 0, totalDown = 0;
    for (const [deviceId, device] of this.devices) {
      if (!device.approved || !device.paired) continue;
      try {
        const result = await this.syncWithDevice(device);
        totalUp += result.uploaded;
        totalDown += result.downloaded;
      } catch (e) {
        console.error(`[P2P] Sync with ${device.deviceName} failed:`, e);
      }
    }

    if (totalUp > 0 || totalDown > 0) {
      console.log(`[P2P] Sync complete: ↑${totalUp} ↓${totalDown}`);
    }
    return { uploaded: totalUp, downloaded: totalDown };
  }

  private async syncWithDevice(device: DiscoveredDevice): Promise<{ uploaded: number; downloaded: number }> {
    const month = this.currentMonth();
    let uploaded = 0, downloaded = 0;

    // Pull sessions
    const remoteSessions = await this.httpGet(`http://${device.ip}:${device.port}/api/sync/sessions?month=${month}`, device.deviceId);
    if (remoteSessions) {
      downloaded += await this.mergeSessions(JSON.parse(remoteSessions));
    }

    // Push sessions
    const localSessions = this.store.loadSessions(month);
    await this.httpPost(`http://${device.ip}:${device.port}/api/sync/sessions`, JSON.stringify(localSessions), device.deviceId);
    uploaded += localSessions.length;

    // Pull summaries
    const remoteSummaries = await this.httpGet(`http://${device.ip}:${device.port}/api/sync/summaries?month=${month}`, device.deviceId);
    if (remoteSummaries) {
      await this.mergeSummaries(JSON.parse(remoteSummaries));
    }

    // Push summaries
    const localSummaries = this.store.loadSummaries(month);
    await this.httpPost(`http://${device.ip}:${device.port}/api/sync/summaries`, JSON.stringify(localSummaries), device.deviceId);

    return { uploaded, downloaded };
  }

  private async mergeSessions(remoteData: any[]): Promise<number> {
    const month = this.currentMonth();
    const local = this.store.loadSessions(month);
    const map = new Map<string, any>();
    for (const s of local) map.set(s.id, s);

    let newCount = 0;
    for (const r of remoteData) {
      const existing = map.get(r.id);
      if (!existing) {
        map.set(r.id, r);
        newCount++;
      } else if (new Date(r.updatedAt).getTime() > new Date(existing.updatedAt).getTime()) {
        map.set(r.id, r);
      }
    }

    const merged = Array.from(map.values()).sort((a, b) => a.startTime.localeCompare(b.startTime));
    this.store.writeRawJson(`sessions/${month}.json`, merged);

    // Update summaries for affected dates
    const dates = new Set(merged.map(s => s.date));
    for (const date of dates) {
      this.store.updateDailySummary(date);
    }

    return newCount;
  }

  private async mergeSummaries(remoteData: any[]): Promise<void> {
    const month = this.currentMonth();
    const local = this.store.loadSummaries(month);
    const map = new Map<string, any>();
    for (const s of local) map.set(s.date, s);

    for (const r of remoteData) {
      const existing = map.get(r.date);
      if (!existing || new Date(r.updatedAt).getTime() > new Date(existing.updatedAt).getTime()) {
        map.set(r.date, r);
      }
    }

    const merged = Array.from(map.values()).sort((a, b) => a.date.localeCompare(b.date));
    this.store.writeRawJson(`summaries/${month}.json`, merged);
  }

  // ============================================================
  // Device Management
  // ============================================================

  approveDevice(deviceId: string): void {
    const device = this.devices.get(deviceId);
    if (device) {
      device.approved = true;
      console.log(`[P2P] Approved device: ${device.deviceName}`);
    }
  }

  async pairDevice(deviceId: string, code: string): Promise<boolean> {
    if (code !== this._pairingCode) return false;
    const device = this.devices.get(deviceId);
    if (device) {
      device.paired = true;
      // Also tell the remote device
      try {
        await this.httpPost(
          `http://${device.ip}:${device.port}/api/pair`,
          JSON.stringify({ pairingCode: code, deviceId: this.store.deviceId })
        );
      } catch {}
      return true;
    }
    return false;
  }

  getDiscoveredDevices(): DiscoveredDevice[] {
    return Array.from(this.devices.values());
  }

  private isApproved(deviceId: string): boolean {
    return this.devices.get(deviceId)?.approved === true;
  }

  // ============================================================
  // HTTP Helpers
  // ============================================================

  private httpGet(url: string, deviceId?: string): Promise<string | null> {
    return new Promise((resolve) => {
      const req = http.get(url, { timeout: 5000 }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          if (res.statusCode === 200) resolve(this.decrypt(data));
          else resolve(null);
        });
      });
      req.on('error', () => resolve(null));
      req.on('timeout', () => { req.destroy(); resolve(null); });
      if (deviceId) {
        const ts = Math.floor(Date.now() / 1000).toString();
        req.setHeader('X-SG-Device', this.store.deviceId);
        req.setHeader('X-SG-Time', ts);
        req.setHeader('X-SG-Auth', this.hmac(this.store.deviceId, ts));
      }
    });
  }

  private httpPost(url: string, body: string, deviceId?: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const urlObj = new URL(url);
      const req = http.request({
        hostname: urlObj.hostname,
        port: urlObj.port,
        path: urlObj.pathname,
        method: 'POST',
        timeout: 5000,
        headers: { 'Content-Type': 'application/json' },
      }, (res) => {
        res.resume();
        res.on('end', resolve);
      });
      req.on('error', reject);
      req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
      if (deviceId) {
        const ts = Math.floor(Date.now() / 1000).toString();
        req.setHeader('X-SG-Device', this.store.deviceId);
        req.setHeader('X-SG-Time', ts);
        req.setHeader('X-SG-Auth', this.hmac(this.store.deviceId, ts));
      }
      req.write(this.encrypt(body));
      req.end();
    });
  }

  private readBody(req: http.IncomingMessage): Promise<string> {
    return new Promise((resolve) => {
      let data = '';
      req.on('data', chunk => data += chunk);
      req.on('end', () => resolve(data));
    });
  }

  // ============================================================
  // Auth & Encryption
  // ============================================================

  private verifyHmac(hmac: string | undefined, timestamp: string | undefined, deviceId: string): boolean {
    if (!this._pairingCode || !hmac || !timestamp) return false;
    const ts = parseInt(timestamp);
    if (isNaN(ts)) return false;
    const now = Math.floor(Date.now() / 1000);
    if (Math.abs(now - ts) > 30) return false;
    return hmac === this.hmac(deviceId, timestamp);
  }

  private hmac(deviceId: string, timestamp: string): string {
    if (!this._pairingCode) return '';
    return crypto.createHmac('sha256', this._pairingCode)
      .update(`${deviceId}:${timestamp}`)
      .digest('hex')
      .substring(0, 32);
  }

  private encrypt(plaintext: string): string {
    if (!this._paired || !this._pairingCode) return plaintext;
    const key = crypto.createHash('sha256').update(this._pairingCode).digest();
    const iv = crypto.randomBytes(16);
    const data = Buffer.from(plaintext, 'utf-8');
    const encrypted = Buffer.alloc(data.length);
    for (let i = 0; i < data.length; i++) {
      encrypted[i] = data[i] ^ key[i % key.length] ^ iv[i % iv.length];
    }
    const hmacKey = crypto.createHash('sha256').update(Buffer.concat([key, Buffer.from([0x01])])).digest();
    const hmac = crypto.createHmac('sha256', hmacKey).update(Buffer.concat([iv, encrypted])).digest();
    return Buffer.concat([iv, encrypted, hmac]).toString('base64');
  }

  private decrypt(ciphertext: string): string | null {
    if (!this._paired || !this._pairingCode) return ciphertext;
    try {
      const key = crypto.createHash('sha256').update(this._pairingCode).digest();
      const payload = Buffer.from(ciphertext, 'base64');
      if (payload.length < 48) return null;
      const iv = payload.subarray(0, 16);
      const hmac = payload.subarray(payload.length - 32);
      const encrypted = payload.subarray(16, payload.length - 32);
      const hmacKey = crypto.createHash('sha256').update(Buffer.concat([key, Buffer.from([0x01])])).digest();
      const expectedHmac = crypto.createHmac('sha256', hmacKey).update(Buffer.concat([iv, encrypted])).digest();
      if (!hmac.equals(expectedHmac)) return null;
      const decrypted = Buffer.alloc(encrypted.length);
      for (let i = 0; i < encrypted.length; i++) {
        decrypted[i] = encrypted[i] ^ key[i % key.length] ^ iv[i % iv.length];
      }
      return decrypted.toString('utf-8');
    } catch {
      return null;
    }
  }

  // ============================================================
  // mDNS Packet Helpers (simplified implementation)
  // ============================================================

  private buildDnsRecord(name: string, type: string, data: string): Buffer {
    // Simplified DNS record builder
    // In production, use a proper DNS library like `dns-packet`
    const nameBuf = this.encodeDnsName(name);
    let typeNum = 12; // PTR
    if (type === 'SRV') typeNum = 33;
    if (type === 'TXT') typeNum = 16;

    const dataBuf = Buffer.from(data, 'utf-8');
    const record = Buffer.alloc(nameBuf.length + 10 + dataBuf.length);
    nameBuf.copy(record);
    let offset = nameBuf.length;
    record.writeUInt16BE(typeNum, offset); offset += 2;
    record.writeUInt16BE(1, offset); offset += 2; // class IN
    record.writeUInt32BE(120, offset); offset += 4; // TTL 120s
    record.writeUInt16BE(dataBuf.length, offset); offset += 2;
    dataBuf.copy(record, offset);

    return record;
  }

  private buildMdnsPacket(records: Buffer[]): Buffer {
    // Header: ID=0, flags=0x8400 (response), QDCOUNT=0, ANCOUNT=N
    const header = Buffer.alloc(12);
    header.writeUInt16BE(0, 0); // ID
    header.writeUInt16BE(0x8400, 2); // Flags (response)
    header.writeUInt16BE(0, 4); // QDCOUNT
    header.writeUInt16BE(records.length, 6); // ANCOUNT
    header.writeUInt16BE(0, 8); // NSCOUNT
    header.writeUInt16BE(0, 10); // ARCOUNT

    return Buffer.concat([header, ...records]);
  }

  private buildMdnsQuery(serviceType: string): Buffer {
    const header = Buffer.alloc(12);
    header.writeUInt16BE(0, 0);
    header.writeUInt16BE(0, 2); // Flags (query)
    header.writeUInt16BE(1, 4); // QDCOUNT=1

    const nameBuf = this.encodeDnsName(serviceType);
    const question = Buffer.alloc(nameBuf.length + 4);
    nameBuf.copy(question);
    question.writeUInt16BE(12, nameBuf.length); // PTR
    question.writeUInt16BE(1, nameBuf.length + 2); // IN

    return Buffer.concat([header, question]);
  }

  private encodeDnsName(name: string): Buffer {
    const parts = name.split('.');
    const buf = Buffer.alloc(name.length + 2);
    let offset = 0;
    for (const part of parts) {
      buf.writeUInt8(part.length, offset); offset++;
      buf.write(part, offset, 'ascii'); offset += part.length;
    }
    buf.writeUInt8(0, offset);
    return buf.subarray(0, offset + 1);
  }

  private parseMdnsResponse(msg: Buffer): { deviceId: string; deviceName: string; platform: string; port: number; version: string } | null {
    // Simplified parser - look for TXT record with device info
    try {
      const str = msg.toString('utf-8');
      const idMatch = str.match(/id=([^\x00,\s]+)/);
      const nameMatch = str.match(/name=([^\x00,\s]+)/);
      const platformMatch = str.match(/platform=([^\x00,\s]+)/);
      const versionMatch = str.match(/version=([^\x00,\s]+)/);
      const portMatch = str.match(/(\d{4,5})/);

      if (idMatch) {
        return {
          deviceId: idMatch[1],
          deviceName: nameMatch?.[1] || 'Unknown',
          platform: platformMatch?.[1] || 'unknown',
          port: portMatch ? parseInt(portMatch[1]) : SYNC_PORT,
          version: versionMatch?.[1] || '1.0.0',
        };
      }
    } catch {}
    return null;
  }

  // ============================================================
  // Helpers
  // ============================================================

  private getLocalIP(): string {
    const os = require('os');
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
      for (const iface of interfaces[name]) {
        if (iface.family === 'IPv4' && !iface.internal) {
          return iface.address;
        }
      }
    }
    return '127.0.0.1';
  }

  private currentMonth(): string {
    return new Date().toISOString().substring(0, 7);
  }

  get isRunning(): boolean { return this._running; }
  get isPaired(): boolean { return this._paired; }
  get serverPort(): number { return SYNC_PORT; }
}
