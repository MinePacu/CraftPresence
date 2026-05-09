import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { KeyRound, Plus, Trash2 } from "lucide-react";
import { useState } from "react";
import { api, jsonBody } from "../api/client";
import { CopyButton } from "../components/CopyButton";
import { Field, TextInput } from "../components/Field";

type Device = { id: string; name: string; platform: string; priority: number; status: string };

export function DevicesPage() {
  const qc = useQueryClient();
  const [form, setForm] = useState({ name: "", platform: "macOS" });
  const [token, setToken] = useState("");
  const devices = useQuery({ queryKey: ["devices"], queryFn: () => api<Device[]>("/api/devices") });
  const invalidate = () => qc.invalidateQueries({ queryKey: ["devices"] });
  const create = useMutation({
    mutationFn: () => api("/api/devices", { method: "POST", ...jsonBody(form) }),
    onSuccess: () => { setForm({ name: "", platform: "macOS" }); void invalidate(); }
  });
  async function move(index: number, direction: -1 | 1) {
    const list = [...(devices.data ?? [])];
    const target = index + direction;
    if (target < 0 || target >= list.length) return;
    [list[index], list[target]] = [list[target], list[index]];
    await api("/api/devices/priorities", { method: "PUT", ...jsonBody({ orderedDeviceIds: list.map((device) => device.id) }) });
    await invalidate();
  }
  return (
    <section>
      <header className="pageHeader">
        <div>
          <p className="eyebrow">Priority routing</p>
          <h1>Devices</h1>
        </div>
      </header>
      <form className="panel inlineForm" onSubmit={(e) => { e.preventDefault(); create.mutate(); }}>
        <Field label="이름"><TextInput value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></Field>
        <Field label="플랫폼">
          <select value={form.platform} onChange={(e) => setForm({ ...form, platform: e.target.value })}>
            {["macOS", "iOS", "Android", "Windows", "Linux"].map((item) => <option key={item}>{item}</option>)}
          </select>
        </Field>
        <button className="primaryButton"><Plus size={16} /> 등록</button>
      </form>
      {token ? <div className="notice"><code>{token}</code><CopyButton value={token} label="토큰 복사" /><button onClick={() => setToken("")}>닫기</button></div> : null}
      <div className="panel dataPanel">
        <div className="tableHeader devicesHeader"><span>Device</span><span>Platform</span><span>Status</span><span>Priority</span><span>Actions</span></div>
        {(devices.data ?? []).map((device, index) => (
          <div className="listRow devicesRow" key={device.id}>
            <strong>{device.name}</strong>
            <span>{device.platform}</span>
            <span className={`badge ${device.status}`}>{device.status}</span>
            <div className="segmented"><button onClick={() => void move(index, -1)}>위</button><button onClick={() => void move(index, 1)}>아래</button></div>
            <div className="rowActions">
              <button onClick={async () => setToken((await api<{ token: string }>(`/api/devices/${device.id}/token`, { method: "POST" })).token)}><KeyRound size={15} /> 토큰</button>
              <button onClick={async () => { await api(`/api/devices/${device.id}`, { method: "DELETE" }); await invalidate(); }} className="danger"><Trash2 size={15} /> 해제</button>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
