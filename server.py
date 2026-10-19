#!/usr/bin/env python3
import json, os, signal, socket, subprocess, sys, time, platform, shutil
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from pathlib import Path

import psutil

ROOT = Path(__file__).resolve().parent
WEB = ROOT / 'web'
PORT = int(os.environ.get('TASKGLASS_PORT', '8765'))
HOST = os.environ.get('TASKGLASS_HOST', '127.0.0.1')

class Monitor:
    def __init__(self):
        self.procs = {}
        psutil.cpu_percent(None)
        for p in psutil.process_iter():
            try: p.cpu_percent(None); self.procs[p.pid] = p
            except Exception: pass
        self.prev_net = psutil.net_io_counters()
        self.prev_disk = psutil.disk_io_counters()
        self.prev_t = time.monotonic()
        self.net_down = self.net_up = self.disk_rate = 0.0
        self.cpu = 0.0

    def _fmt(self, n):
        n=float(n)
        for u in ('B','KB','MB','GB','TB'):
            if n < 1024 or u == 'TB': return f'{n:.1f} {u}'
            n/=1024
        return f'{n:.1f} TB'

    def refresh(self, query='', sort='cpu', desc='1', limit=400):
        now=time.monotonic(); dt=max(.001,now-self.prev_t); self.prev_t=now
        self.cpu=psutil.cpu_percent(None)
        net=psutil.net_io_counters(); disk=psutil.disk_io_counters()
        self.net_down=max(0, net.bytes_recv-self.prev_net.bytes_recv)/dt
        self.net_up=max(0, net.bytes_sent-self.prev_net.bytes_sent)/dt
        total_disk=max(0,(disk.read_bytes+disk.write_bytes)-(self.prev_disk.read_bytes+self.prev_disk.write_bytes))
        self.disk_rate=total_disk/dt
        self.prev_net,self.prev_disk=net,disk
        q=query.lower().strip(); new={}; rows=[]
        for pid in psutil.pids():
            try:
                p=self.procs.get(pid) or psutil.Process(pid); self.procs[pid]=p
                with p.oneshot():
                    name=p.name(); user=p.username() or 'system'; status=p.status(); thr=p.num_threads()
                    cpu=p.cpu_percent(None); mem=p.memory_percent(); cmd=' '.join(p.cmdline())
                item={'pid':pid,'name':name,'user':user.split('\\')[-1].split('/')[-1],'cpu':round(cpu,1),'mem':round(mem,1),'status':status,'threads':thr,'cmd':cmd}
                if q and q not in f"{pid} {name} {user} {cmd}".lower(): continue
                rows.append(item); new[pid]=p
            except (psutil.NoSuchProcess,psutil.AccessDenied,psutil.ZombieProcess):
                continue
        self.procs=new
        key={'cpu':'cpu','mem':'mem','pid':'pid','name':'name','user':'user'}.get(sort,'cpu')
        rows.sort(key=lambda x:x.get(key,0), reverse=(str(desc)!='0'))
        return rows[:limit]

    def process_detail(self,pid):
        p=self.procs.get(pid) or psutil.Process(pid)
        with p.oneshot():
            mi=p.memory_info()
            try: io=p.io_counters()
            except: io=None
            try: conns=p.net_connections(kind='inet')
            except: conns=[]
            try: files=p.open_files()
            except: files=[]
            return {'pid':pid,'name':p.name(),'exe':p.exe(),'user':p.username(),'status':p.status(),'cpu':round(p.cpu_percent(None),1),
                    'mem':round(p.memory_percent(),1),'rss':mi.rss,'vms':mi.vms,'threads':p.num_threads(),'nice':p.nice(),
                    'cwd':p.cwd() if p.cwd() else '—','cmd': ' '.join(p.cmdline()),'read':getattr(io,'read_bytes',0),'write':getattr(io,'write_bytes',0),
                    'openFiles':len(files),'connections':len(conns),'create':p.create_time()}

    def payload(self,query='',sort='cpu',desc='1'):
        vm=psutil.virtual_memory(); du=psutil.disk_usage('/'); sw=psutil.swap_memory(); net=psutil.net_io_counters()
        uptime=max(0,int(time.time()-psutil.boot_time())); d,rr=divmod(uptime,86400); h,rr=divmod(rr,3600); m,_=divmod(rr,60)
        rows=self.refresh(query,sort,desc)
        return {
          'time':time.strftime('%a, %d %b  •  %H:%M:%S'),'hostname':socket.gethostname(),'os':platform.platform(),'kernel':platform.release(),
          'cpu':self.cpu,'mem':vm.percent,'memUsed':vm.used,'memTotal':vm.total,'disk':du.percent,'diskFree':du.free,
          'down':self.net_down,'up':self.net_up,'diskRate':self.disk_rate,'swap':sw.percent,'swapUsed':sw.used,'swapTotal':sw.total,
          'cores':psutil.cpu_count(logical=False) or psutil.cpu_count() or 1,'threads':psutil.cpu_count(logical=True) or 1,
          'load':list(os.getloadavg()) if hasattr(os,'getloadavg') else [],'uptime':f'{d}d {h}h {m}m','processes':rows,'processCount':len(rows),
          'interfaces':sorted(psutil.net_if_addrs().keys()),
          'connections': self.connections(),
          'disks': self.disks(),
          'battery': self.battery(),
        }

    def connections(self):
        out=[]
        try:
            for c in psutil.net_connections(kind='inet')[:120]:
                local=f'{c.laddr.ip}:{c.laddr.port}' if c.laddr else '—'
                remote=f'{c.raddr.ip}:{c.raddr.port}' if c.raddr else '—'
                out.append({'local':local,'remote':remote,'status':c.status,'pid':c.pid or 0})
        except Exception:
            pass
        return out

    def disks(self):
        out=[]
        for p in psutil.disk_partitions(all=False):
            try:
                u=psutil.disk_usage(p.mountpoint)
                out.append({'mount':p.mountpoint,'device':p.device,'fstype':p.fstype,'used':u.percent,'free':self._fmt(u.free),'total':self._fmt(u.total)})
            except Exception:
                pass
        return out

    def battery(self):
        try:
            b=psutil.sensors_battery()
            if b: return {'percent':b.percent,'plugged':b.power_plugged,'secs':b.secsleft}
        except: pass
        return None

monitor=Monitor()

class Handler(BaseHTTPRequestHandler):
    server_version='TaskGlass/neo'
    def log_message(self, *args): pass
    def send_json(self, data, status=200):
        raw=json.dumps(data,separators=(',',':')).encode()
        self.send_response(status); self.send_header('Content-Type','application/json'); self.send_header('Cache-Control','no-store'); self.send_header('Content-Length',str(len(raw))); self.end_headers(); self.wfile.write(raw)
    def body(self):
        n=int(self.headers.get('Content-Length','0')); return json.loads(self.rfile.read(n) or '{}')
    def do_GET(self):
        u=urlparse(self.path)
        if u.path=='/api/state':
            q=parse_qs(u.query); self.send_json(monitor.payload(q.get('q',[''])[0],q.get('sort',['cpu'])[0],q.get('desc',['1'])[0])); return
        if u.path.startswith('/api/process/'):
            try: pid=int(u.path.rsplit('/',1)[1]); self.send_json(monitor.process_detail(pid)); return
            except Exception as e: self.send_json({'error':str(e)},404); return
        path=(WEB/'index.html') if u.path in ('/','') else (WEB/u.path.lstrip('/'))
        if not path.exists() or not path.is_file(): self.send_response(404); self.end_headers(); return
        mime={'.html':'text/html','.js':'application/javascript','.css':'text/css','.svg':'image/svg+xml','.png':'image/png','.webp':'image/webp'}.get(path.suffix,'application/octet-stream')
        raw=path.read_bytes(); self.send_response(200); self.send_header('Content-Type',mime); self.send_header('Content-Length',str(len(raw))); self.end_headers(); self.wfile.write(raw)
    def do_POST(self):
        u=urlparse(self.path)
        if u.path!='/api/action': self.send_json({'error':'not found'},404); return
        d=self.body(); action=d.get('action'); pid=int(d.get('pid',0) or 0)
        try:
            if action=='launch':
                cmd=d.get('command','').strip()
                if not cmd: raise ValueError('empty command')
                subprocess.Popen(cmd,shell=True,start_new_session=True); msg='Command launched'
            else:
                p=psutil.Process(pid)
                if action=='terminate': p.terminate(); msg=f'SIGTERM sent to {pid}'
                elif action=='kill': p.kill(); msg=f'Process {pid} killed'
                elif action=='suspend': p.suspend(); msg=f'Process {pid} suspended'
                elif action=='resume': p.resume(); msg=f'Process {pid} resumed'
                elif action=='nice+': p.nice(min(p.nice()+1,19)); msg=f'Priority lowered for {pid}'
                elif action=='nice-': p.nice(max(p.nice()-1,-20)); msg=f'Priority raised for {pid}'
                else: raise ValueError('unknown action')
            self.send_json({'ok':True,'message':msg})
        except Exception as e: self.send_json({'ok':False,'error':str(e)},400)

if __name__=='__main__':
    httpd=ThreadingHTTPServer((HOST,PORT),Handler)
    print(f'http://{HOST}:{PORT}',flush=True)
    try: httpd.serve_forever()
    except KeyboardInterrupt: pass
