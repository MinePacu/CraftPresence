import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthProvider";
import { Field, TextInput } from "../components/Field";

export function SetupPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ displayName: "", email: "", password: "", confirmPassword: "" });
  async function submit(event: FormEvent) {
    event.preventDefault();
    await auth.setup(form);
    navigate("/");
  }
  return (
    <section className="authPage">
      <div className="authIntro">
        <span className="authMark">CP</span>
        <h1>CraftPresence Manager</h1>
        <p>첫 관리자 계정을 만든 뒤 기기 등록과 Presence 동기화를 시작할 수 있습니다.</p>
      </div>
      <form className="authPanel" onSubmit={submit}>
        <p className="eyebrow">First run setup</p>
        <h2>관리자 계정 생성</h2>
        <Field label="이름"><TextInput value={form.displayName} onChange={(e) => setForm({ ...form, displayName: e.target.value })} /></Field>
        <Field label="이메일"><TextInput type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></Field>
        <Field label="비밀번호"><TextInput type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} /></Field>
        <Field label="비밀번호 확인"><TextInput type="password" value={form.confirmPassword} onChange={(e) => setForm({ ...form, confirmPassword: e.target.value })} /></Field>
        <button className="primaryButton" type="submit">생성</button>
      </form>
    </section>
  );
}
