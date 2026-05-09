import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthProvider";
import { Field, TextInput } from "../components/Field";

export function LoginPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ email: "", password: "" });
  async function submit(event: FormEvent) {
    event.preventDefault();
    await auth.login(form.email, form.password);
    navigate("/");
  }
  return (
    <section className="authPage">
      <div className="authIntro">
        <span className="authMark">CP</span>
        <h1>CraftPresence Manager</h1>
        <p>등록된 기기, Presence 기록, Discord 이미지 자산과 설정 백업을 한 곳에서 관리합니다.</p>
      </div>
      <form className="authPanel" onSubmit={submit}>
        <p className="eyebrow">Welcome back</p>
        <h2>로그인</h2>
        <Field label="이메일"><TextInput type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></Field>
        <Field label="비밀번호"><TextInput type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} /></Field>
        <button className="primaryButton" type="submit">로그인</button>
      </form>
    </section>
  );
}
