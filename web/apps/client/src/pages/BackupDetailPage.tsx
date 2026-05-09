import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { api, jsonBody } from "../api/client";
import { AssetPicker } from "../components/AssetPicker";
import { JsonEditor } from "../components/JsonEditor";

export function BackupDetailPage() {
  const { id = "" } = useParams();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [draft, setDraft] = useState("");
  const backup = useQuery({
    queryKey: ["backup", id],
    queryFn: async () => {
      const result = await api<{ backup: any }>(`/api/backups/${id}`);
      setDraft(JSON.stringify(result.backup.rawJson, null, 2));
      return result.backup;
    }
  });
  const save = useMutation({
    mutationFn: () => api(`/api/backups/${id}`, { method: "PATCH", ...jsonBody({ rawJson: JSON.parse(draft) }) }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["backup", id] })
  });
  const raw = draft ? JSON.parse(draft) : backup.data?.rawJson;
  const firstPreset = raw?.settings?.presencePresets?.[0];
  return (
    <section>
      <header className="pageHeader">
        <div>
          <p className="eyebrow">Remote settings</p>
          <h1>Backup Detail</h1>
        </div>
        <div className="actions"><button className="primaryButton" onClick={() => save.mutate()}>저장</button><button className="danger" onClick={async () => { await api(`/api/backups/${id}`, { method: "DELETE" }); navigate("/backups"); }}>삭제</button></div>
      </header>
      <div className="grid">
        <div className="panel">
          <div className="sectionTitle"><h2>요약</h2></div>
          <pre>{JSON.stringify(backup.data?.summary ?? {}, null, 2)}</pre>
          <div className="sectionTitle"><h2>이미지 자산 적용</h2></div>
          <AssetPicker onApply={(fields) => {
            const next = JSON.parse(draft);
            next.settings.presencePresets[0] = { ...next.settings.presencePresets[0], ...fields };
            setDraft(JSON.stringify(next, null, 2));
          }} />
          {firstPreset ? <pre>{JSON.stringify(firstPreset, null, 2)}</pre> : null}
        </div>
        <div className="panel">
          <div className="sectionTitle"><h2>Raw JSON</h2></div>
          <JsonEditor value={raw ?? {}} onChange={setDraft} />
        </div>
      </div>
    </section>
  );
}
