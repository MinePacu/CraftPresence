import { useQuery } from "@tanstack/react-query";
import { Image, MoveDownLeft, MoveUpRight } from "lucide-react";
import { api } from "../api/client";
import { CopyButton } from "./CopyButton";
import { EmptyState } from "./EmptyState";

type Asset = {
  id: string;
  title: string;
  key: string;
  imageText: string;
  imageUrl: string;
};

export function AssetPicker({
  onApply
}: {
  onApply: (fields: { largeImageKey?: string; largeImageText?: string; smallImageKey?: string; smallImageText?: string }) => void;
}) {
  const { data } = useQuery({ queryKey: ["assets"], queryFn: () => api<{ assets: Asset[] }>("/api/assets") });
  const assets = data?.assets ?? [];
  if (assets.length === 0) return <EmptyState title="저장된 이미지 자산이 없습니다" detail="Assets 페이지에서 먼저 이미지를 등록하세요." />;
  return (
    <div className="assetPicker">
      {assets.map((asset) => (
        <div className="assetRow" key={asset.id}>
          <img src={asset.imageUrl} alt="" />
          <div>
            <strong>{asset.title}</strong>
            <code>{asset.key}</code>
            <span>{asset.imageText}</span>
          </div>
          <CopyButton value={asset.key} label="키" />
          <CopyButton value={asset.imageText} label="텍스트" />
          <button onClick={() => onApply({ largeImageKey: asset.key, largeImageText: asset.imageText })}>
            <MoveUpRight size={15} /> 큰 이미지
          </button>
          <button onClick={() => onApply({ smallImageKey: asset.key, smallImageText: asset.imageText })}>
            <MoveDownLeft size={15} /> 작은 이미지
          </button>
        </div>
      ))}
    </div>
  );
}
