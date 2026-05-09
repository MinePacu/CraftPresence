import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Upload } from "lucide-react";
import { FormEvent, useState } from "react";
import { api, jsonBody } from "../api/client";
import { CopyButton } from "../components/CopyButton";
import { Field, TextInput } from "../components/Field";

type Asset = { id: string; title: string; key: string; imageText: string; role: string; imageUrl: string };

export function AssetsPage() {
  const qc = useQueryClient();
  const [file, setFile] = useState<File | null>(null);
  const [form, setForm] = useState({ title: "", key: "", imageText: "", role: "both" });
  const assets = useQuery({ queryKey: ["assets"], queryFn: () => api<{ assets: Asset[] }>("/api/assets") });
  const upload = useMutation({
    mutationFn: async () => {
      const body = new FormData();
      if (file) body.set("file", file);
      for (const [key, value] of Object.entries(form)) if (value) body.set(key, value);
      return api("/api/assets", { method: "POST", body });
    },
    onSuccess: () => { setFile(null); setForm({ title: "", key: "", imageText: "", role: "both" }); void qc.invalidateQueries({ queryKey: ["assets"] }); }
  });
  function submit(event: FormEvent) {
    event.preventDefault();
    upload.mutate();
  }
  return (
    <section>
      <header className="pageHeader">
        <div>
          <p className="eyebrow">Discord Rich Presence</p>
          <h1>Assets</h1>
        </div>
      </header>
      <p className="hint">이미지 키는 native 앱에서 사용하는 Discord 애플리케이션의 Rich Presence asset key와 일치해야 합니다.</p>
      <form className="panel formGrid assetUpload" onSubmit={submit}>
        <Field label="이미지"><input type="file" accept="image/png,image/jpeg,image/webp" onChange={(event) => setFile(event.target.files?.[0] ?? null)} /></Field>
        <Field label="이름"><TextInput value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></Field>
        <Field label="키"><TextInput placeholder="비워두면 자동 생성" value={form.key} onChange={(e) => setForm({ ...form, key: e.target.value })} /></Field>
        <Field label="이미지 텍스트"><TextInput value={form.imageText} onChange={(e) => setForm({ ...form, imageText: e.target.value })} /></Field>
        <Field label="역할"><select value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })}><option>both</option><option>large</option><option>small</option></select></Field>
        <button className="primaryButton"><Upload size={16} /> 업로드</button>
      </form>
      <div className="assetGrid">
        {(assets.data?.assets ?? []).map((asset) => (
          <div className="assetCard" key={asset.id}>
            <img src={asset.imageUrl} alt="" />
            <strong>{asset.title}</strong>
            <code>{asset.key}</code>
            <span>{asset.imageText}</span>
            <span className="assetRole">{asset.role}</span>
            <div className="actions">
              <CopyButton value={asset.key} label="키" />
              <CopyButton value={asset.imageText} label="텍스트" />
              <CopyButton value={JSON.stringify({ largeImageKey: asset.key, largeImageText: asset.imageText })} label="큰 이미지 JSON" />
              <CopyButton value={JSON.stringify({ smallImageKey: asset.key, smallImageText: asset.imageText })} label="작은 이미지 JSON" />
            </div>
            <button className="danger" onClick={async () => { await api(`/api/assets/${asset.id}`, { method: "DELETE" }); await qc.invalidateQueries({ queryKey: ["assets"] }); }}>삭제</button>
          </div>
        ))}
      </div>
    </section>
  );
}
