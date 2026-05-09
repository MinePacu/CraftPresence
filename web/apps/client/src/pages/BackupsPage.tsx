import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ChangeEvent } from "react";
import { Upload } from "lucide-react";
import { Link } from "react-router-dom";
import { api, jsonBody } from "../api/client";

type Backup = { id: string; platform: string; summary: any; updatedAt: string };

export function BackupsPage() {
  const qc = useQueryClient();
  const backups = useQuery({ queryKey: ["backups"], queryFn: () => api<{ backups: Backup[] }>("/api/backups") });
  const upload = useMutation({
    mutationFn: (rawJson: unknown) => api("/api/backups/upload", { method: "POST", ...jsonBody({ rawJson }) }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["backups"] })
  });
  async function onFile(event: ChangeEvent<HTMLInputElement>) {
    const selected = event.target.files?.[0];
    if (!selected) return;
    upload.mutate(JSON.parse(await selected.text()));
  }
  return (
    <section>
      <header className="pageHeader">
        <div>
          <p className="eyebrow">Remote settings</p>
          <h1>Backups</h1>
        </div>
        <label className="fileButton"><Upload size={16} /> JSON 업로드<input type="file" accept=".json,application/json" onChange={onFile} /></label>
      </header>
      <div className="panel dataPanel">
        <div className="tableHeader backupsHeader"><span>Platform</span><span>Presets</span><span>Programs</span><span>Updated</span></div>
        {(backups.data?.backups ?? []).map((backup) => (
          <Link className="listRow backupsRow" key={backup.id} to={`/backups/${backup.id}`}>
            <strong>{backup.platform}</strong>
            <span>{backup.summary?.presetCount ?? 0} presets</span>
            <span>{backup.summary?.trackedProgramCount ?? 0} programs</span>
            <time>{new Date(backup.updatedAt).toLocaleString()}</time>
          </Link>
        ))}
      </div>
    </section>
  );
}
