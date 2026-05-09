import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { api } from "../api/client";

export function HistoryPage() {
  const [status, setStatus] = useState("");
  const events = useQuery({ queryKey: ["presence-events", status], queryFn: () => api<{ events: any[] }>(`/api/presence/events${status ? `?status=${status}` : ""}`) });
  return (
    <section>
      <header className="pageHeader">
        <div>
          <p className="eyebrow">Presence timeline</p>
          <h1>History</h1>
        </div>
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">전체</option>
          <option value="applied">applied</option>
          <option value="ignored">ignored</option>
        </select>
      </header>
      <div className="panel dataPanel">
        <div className="tableHeader historyHeader"><span>Status</span><span>Reason</span><span>Device</span><span>Presence</span></div>
        {(events.data?.events ?? []).map((event) => (
          <div className="listRow historyTableRow" key={event.id}>
            <strong>{event.status}</strong>
            <span>{event.reason}</span>
            <code>{event.deviceId}</code>
            <span>{event.payload?.details ?? event.payload?.name ?? "Presence"}</span>
          </div>
        ))}
      </div>
    </section>
  );
}
