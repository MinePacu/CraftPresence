import { Copy } from "lucide-react";
import { useState } from "react";

export function CopyButton({ value, label = "복사" }: { value: string; label?: string }) {
  const [state, setState] = useState(label);
  async function copy() {
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(value);
      } else {
        const textarea = document.createElement("textarea");
        textarea.value = value;
        textarea.style.position = "fixed";
        textarea.style.opacity = "0";
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand("copy");
        textarea.remove();
      }
      setState("복사됨");
      window.setTimeout(() => setState(label), 1400);
    } catch {
      setState("실패");
    }
  }
  return (
    <button className="iconButton" onClick={copy} title={label}>
      <Copy size={15} />
      {state}
    </button>
  );
}
