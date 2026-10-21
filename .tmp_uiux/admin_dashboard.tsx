"use client";
import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import {
  CalendarCheck,
  Wallet,
  HardHat,
  Users,
  AlertTriangle,
  Banknote,
  Activity,
  ChevronRight,
} from "lucide-react";
import { api, unwrap } from "@/lib/api";
import { Badge, Card, EmptyState, Skeleton, StatCard, Table, Td, Th } from "@/components/ui";
import { formatLkr, timeAgo } from "@/lib/utils";
import { statusTone } from "@/lib/status";

export default function DashboardPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["admin-dashboard"],
    queryFn: async () => unwrap<any>(await api.get("/admin/dashboard")),
    refetchInterval: 30000,
  });

  const t = data?.today;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-heading font-bold text-2xl text-slate-900 dark:text-white">Dashboard</h1>
          <p className="text-sm text-slate-500 dark:text-slate-400">Live marketplace overview</p>
        </div>
        <Badge tone="success">
          <Activity className="w-3 h-3" /> Live
        </Badge>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {Array.from({ length: 8 }).map((_, i) => (
            <Skeleton key={i} className="h-28" />
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard label="Today's bookings" value={t?.bookings ?? 0} icon={CalendarCheck} tone="primary" />
          <StatCard label="Today's revenue" value={formatLkr(t?.revenue ?? 0)} icon={Wallet} tone="success" />
          <StatCard label="Active bookings" value={t?.activeBookings ?? 0} icon={Activity} tone="info" />
          <StatCard label="Workers online" value={t?.activeWorkers ?? 0} icon={HardHat} tone="primary" />
          <StatCard label="Total users" value={t?.totalUsers ?? 0} icon={Users} tone="info" />
          <StatCard
            label="Pending approvals"
            value={t?.pendingWorkers ?? 0}
            icon={HardHat}
            tone="warning"
            hint="Workers awaiting review"
          />
          <StatCard label="Open disputes" value={t?.openDisputes ?? 0} icon={AlertTriangle} tone="danger" />
          <StatCard label="Payout requests" value={t?.pendingPayouts ?? 0} icon={Banknote} tone="warning" />
        </div>
      )}

      <div className="grid lg:grid-cols-3 gap-6">
        <Card className="p-5 lg:col-span-1">
          <p className="text-sm font-medium text-slate-500 dark:text-slate-400">Revenue (last 7 days)</p>
          <p className="font-heading font-bold text-3xl text-slate-900 dark:text-white mt-2">
            {formatLkr(data?.weeklyRevenue ?? 0)}
          </p>
          <Link
            href="/bookings"
            className="inline-flex items-center gap-1 text-sm font-semibold text-primary mt-4"
          >
            View bookings <ChevronRight className="w-4 h-4" />
          </Link>
        </Card>

        <Card className="lg:col-span-2">
          <div className="px-5 py-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between">
            <h2 className="font-heading font-semibold text-slate-900 dark:text-white">Recent bookings</h2>
            <Link href="/bookings" className="text-sm font-semibold text-primary">
              View all
            </Link>
          </div>
          <Table>
            <thead>
              <tr>
                <Th>Code</Th>
                <Th>Service</Th>
                <Th>Customer</Th>
                <Th>Status</Th>
                <Th className="text-right">When</Th>
              </tr>
            </thead>
            <tbody>
              {(data?.recentBookings ?? []).map((b: any) => (
                <tr key={b.id} className="hover:bg-slate-50 dark:hover:bg-white/5">
                  <Td className="font-mono text-xs">{b.code}</Td>
                  <Td>{b.service?.name ?? "—"}</Td>
                  <Td>{b.customer?.name ?? "—"}</Td>
                  <Td>
                    <Badge tone={statusTone(b.status)}>{b.status.replace(/_/g, " ")}</Badge>
                  </Td>
                  <Td className="text-right text-slate-400">{timeAgo(b.createdAt)}</Td>
                </tr>
              ))}
              {!data?.recentBookings?.length && (
                <tr>
                  <Td className="py-0">
                    <EmptyState
                      icon={CalendarCheck}
                      title="No bookings yet"
                      subtitle="Bookings appear here as customers start booking services."
                    />
                  </Td>
                </tr>
              )}
            </tbody>
          </Table>
        </Card>
      </div>
    </div>
  );
}