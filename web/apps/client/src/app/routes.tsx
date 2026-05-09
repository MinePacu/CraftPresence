import { Navigate, Route, Routes } from "react-router-dom";
import { useAuth } from "../auth/AuthProvider";
import { AppShell } from "../components/AppShell";
import { AssetsPage } from "../pages/AssetsPage";
import { BackupDetailPage } from "../pages/BackupDetailPage";
import { BackupsPage } from "../pages/BackupsPage";
import { DashboardPage } from "../pages/DashboardPage";
import { DevicesPage } from "../pages/DevicesPage";
import { HistoryPage } from "../pages/HistoryPage";
import { LoginPage } from "../pages/LoginPage";
import { SetupPage } from "../pages/SetupPage";

export function AppRoutes() {
  const auth = useAuth();
  if (auth.loading) return <div className="loading">Loading</div>;
  if (auth.requiresSetup) {
    return (
      <Routes>
        <Route path="/setup" element={<SetupPage />} />
        <Route path="*" element={<Navigate to="/setup" replace />} />
      </Routes>
    );
  }
  if (!auth.user) {
    return (
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    );
  }
  return (
    <Routes>
      <Route element={<AppShell />}>
        <Route index element={<DashboardPage />} />
        <Route path="/devices" element={<DevicesPage />} />
        <Route path="/assets" element={<AssetsPage />} />
        <Route path="/backups" element={<BackupsPage />} />
        <Route path="/backups/:id" element={<BackupDetailPage />} />
        <Route path="/history" element={<HistoryPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
