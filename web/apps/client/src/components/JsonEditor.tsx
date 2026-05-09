export function JsonEditor({ value, onChange }: { value: unknown; onChange: (value: string) => void }) {
  return <textarea className="jsonEditor" value={JSON.stringify(value, null, 2)} onChange={(event) => onChange(event.target.value)} spellCheck={false} />;
}
