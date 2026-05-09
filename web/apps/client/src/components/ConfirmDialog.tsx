export function ConfirmDialog({ message, onConfirm }: { message: string; onConfirm: () => void }) {
  return (
    <button className="danger" onClick={() => window.confirm(message) && onConfirm()}>
      삭제
    </button>
  );
}
