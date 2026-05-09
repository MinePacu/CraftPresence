import { useQuery } from "@tanstack/react-query";
import { Database, Image, ListOrdered, Radio } from "lucide-react";
import { Link } from "react-router-dom";
import { api } from "../api/client";

export function DashboardPage() {
  const current = useQuery({ queryKey: ["presence-current"], queryFn: () => api<{ currentPresence: any }>("/api/presence/current") });
  const devices = useQuery({ queryKey: ["devices"], queryFn: () => api<any[]>("/api/devices") });
  const history = useQuery({ queryKey: ["presence-events"], queryFn: () => api<{ events: any[] }>("/api/presence/events") });
  const online = (devices.data ?? []).filter((device: any) => device.status === "online").length;
  const payload = current.data?.currentPresence?.payload;
  return (
    <section>
      <header className="pageHeader">
        <div>
          <p className="eyebrow">Control Center</p>
          <h1>Dashboard</h1>
        </div>
        <div className="actions">
          <Link to="/devices"><ListOrdered size={16} /> 기기 우선순위</Link>
          <Link to="/assets"><Image size={16} /> 이미지 자산</Link>
          <Link to="/backups"><Database size={16} /> 백업</Link>
        </div>
      </header>
      <div className="metricGrid">
        <div className="metricCard">
          <span>Online devices</span>
          <strong>{online}</strong>
          <small>{(devices.data ?? []).length} registered</small>
        </div>
        <div className="metricCard">
          <span>Presence events</span>
          <strong>{history.data?.events?.length ?? 0}</strong>
          <small>latest 200 loaded</small>
        </div>
        <div className="metricCard accent">
          <span>Current source</span>
          <strong>{current.data?.currentPresence?.deviceId ? "Synced" : "Idle"}</strong>
          <small>{current.data?.currentPresence?.deviceId ?? "No active device"}</small>
        </div>
      </div>
      <div className="grid">
        <div className="panel presencePanel">
          <div className="sectionTitle">
            <Radio size={17} />
            <h2>현재 Presence</h2>
          </div>
          {payload ? (
            <div className="presencePreview">
              <strong>{payload.name ?? payload.details ?? "Presence"}</strong>
              <span>{payload.details ?? "No details"}</span>
              <span>{payload.state ?? "No state"}</span>
              <code>{payload.activityType}</code>
            </div>
          ) : (
            <div className="empty compact"><strong>아직 반영된 Presence가 없습니다</strong><span>기기에서 Presence 이벤트를 보내면 여기에 표시됩니다.</span></div>
          )}
        </div>
        <div className="panel">
          <div className="sectionTitle">
            <ListOrdered size={17} />
            <h2>기기 상태</h2>
          </div>
          {(devices.data ?? []).slice(0, 5).map((device: any) => (
            <div className="compactRow" key={device.id}>
              <strong>{device.name}</strong>
              <span>{device.platform}</span>
              <span className={`badge ${device.status}`}>{device.status}</span>
            </div>
          ))}
        </div>
      </div>
      <div className="panel">
        <div className="sectionTitle"><h2>최근 기록</h2></div>
        {(history.data?.events ?? []).slice(0, 5).map((event) => (
          <div className="listRow historyRow" key={event.id}><strong>{event.status}</strong><span>{event.reason}</span><code>{event.deviceId}</code></div>
        ))}
      </div>
    </section>
  );
}
