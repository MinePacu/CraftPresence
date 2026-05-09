import { Activity, Database, History, Image, LayoutDashboard, LogOut, Smartphone } from "lucide-react";
import { NavLink, Outlet } from "react-router-dom";
import { useAuth } from "../auth/AuthProvider";

const items = [
  { to: "/", label: "Dashboard", icon: LayoutDashboard },
  { to: "/devices", label: "Devices", icon: Smartphone },
  { to: "/assets", label: "Assets", icon: Image },
  { to: "/backups", label: "Backups", icon: Database },
  { to: "/history", label: "History", icon: History }
];

export function AppShell() {
  const auth = useAuth();
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="brandMark"><Activity size={20} /></span>
          <div>
            <span>CraftPresence</span>
            <small>Manager</small>
          </div>
        </div>
        <nav className="navRail">
          {items.map((item) => (
            <NavLink key={item.to} to={item.to} end={item.to === "/"}>
              <item.icon size={17} />
              {item.label}
            </NavLink>
          ))}
        </nav>
        <button className="logout ghostButton" onClick={() => void auth.logout()}>
          <LogOut size={17} /> Logout
        </button>
      </aside>
      <main>
        <Outlet />
      </main>
    </div>
  );
}
