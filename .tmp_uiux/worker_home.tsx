"use client";
import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { motion, AnimatePresence } from "framer-motion";
import {
  AlertTriangle,
  Banknote,
  BatteryCharging,
  Briefcase,
  CalendarClock,
  ChevronRight,
  MapPinOff,
  Power,
  RefreshCw,
  Star,
  TrendingUp,
  Wallet,
} from "lucide-react";
import { api, unwrap, apiError } from "@/lib/api";
import { getSocket } from "@/lib/socket";
import { Header, HeaderBell } from "@/components/shared/Header";
import { Button, Card, StatTile, Badge, Skeleton } from "@/components/ui/primitives";
import { JobCard } from "@/components/shared/Cards";
import { MapView, COLOMBO } from "@/components/shared/MapView";
import { useAuthStore } from "@/stores/auth";
import { useToast } from "@/components/ui/toaster";
import { useWakeLock, useLocationWatcher, vibrate } from "@/hooks/useWorkerRuntime";
import { formatLkr, formatTime, timeAgo } from "@/lib/format";
import { t } from "@/i18n";
import { cn } from "@/lib/cn";
import type { Booking } from "@/lib/types";

export default function JobsHomePage() {
  const router = useRouter();
  const toast = useToast();
  const queryClient = useQueryClient();
  const { user, setUser } = useAuthStore();
  const [swiped, setSwiped] = useState(false);

  const { data: profile, isLoading } = useQuery({
    queryKey: ["worker-me"],
    queryFn: async () => unwrap<any>(await api.get("/worker/me")),
    refetchInterval: 30000,
  });

  const { data: activeBookings } = useQuery({
    queryKey: ["worker-bookings", "active"],
    queryFn: async () => unwrap<Booking[]>(await api.get("/bookings?status=active&limit=20")),
    refetchInterval: 20000,
  });

  const { data: notifications } = useQuery({
    queryKey: ["notifications"],
    queryFn: async () => unwrap<any[]>(await api.get("/notifications?unread=true")),
  });

  const isOnline: boolean = profile?.isOnline ?? user?.worker?.isOnline ?? false;
  const isBusy: boolean = profile?.isBusy ?? user?.worker?.isBusy ?? false;
  const status = profile?.status ?? user?.worker?.status;

  // Keep the auth store in sync with the freshest profile.
  useEffect(() => {
    if (profile && user) setUser({ ...user, worker: { ...user.worker, ...profile } });
  }, [profile]); // eslint-disable-line react-hooks/exhaustive-deps

  // Keep the screen awake while online so offers aren't missed.
  useWakeLock(isOnline);

  // Stream location to the backend while online.
  const { permission, lastFix, lowAccuracy } = useLocationWatcher({
    enabled: isOnline,
    intervalMs: isBusy ? 3000 : 5000,
    onPosition: (pos) => {
      const socket = getSocket();
      socket.emit("worker:location", {
        lat: pos.lat,
        lng: pos.lng,
        heading: pos.heading,
      });
    },
  });

  const toggleOnline = useMutation({
    mutationFn: async (online: boolean) => {
      const payload: any = { online };
      if (online && lastFix) {
        payload.lat = lastFix.lat;
        payload.lng = lastFix.lng;
      }
      return unwrap<any>(await api.post("/worker/online", payload));
    },
    onSuccess: (res, online) => {
      vibrate(online ? [0, 40, 60, 40] : 30);
      queryClient.invalidateQueries({ queryKey: ["worker-me"] });
      if (user) setUser({ ...user, worker: { ...user.worker, ...res, isOnline: online } });
      toast.success(online ? "You're online — offers will come in" : "You're offline");
    },
    onError: (e) => toast.error(apiError(e)),
  });

  // Realtime: refresh the job list whenever anything changes.
  useEffect(() => {
    const socket = getSocket();
    const refresh = () => {
      queryClient.invalidateQueries({ queryKey: ["worker-bookings"] });
      queryClient.invalidateQueries({ queryKey: ["worker-me"] });
    };
    socket.on("booking:updated", refresh);
    socket.on("worker:approved", refresh);
    socket.on("payout:paid", refresh);
    return () => {
      socket.off("booking:updated", refresh);
      socket.off("worker:approved", refresh);
      socket.off("payout:paid", refresh);
    };
  }, [queryClient]);

  const activeJob = useMemo(
    () =>
      (activeBookings ?? []).find((b) =>
        ["ACCEPTED", "EN_ROUTE", "ARRIVED", "IN_PROGRESS"].includes(b.status)
      ),
    [activeBookings]
  );

  const scheduled = useMemo(
    () => (activeBookings ?? []).filter((b) => b.status === "SCHEDULED"),
    [activeBookings]
  );

  const balance = profile?.wallet?.balance ?? user?.wallet?.balance ?? 0;
  const minWallet = profile?.minWalletForCashJobs ?? 0;
  const walletWarning = minWallet > 0 && balance < minWallet;
  const unread = notifications?.length ?? 0;

  const center: [number, number] = lastFix
    ? [lastFix.lat, lastFix.lng]
    : profile?.lat && profile?.lng
      ? [profile.lat, profile.lng]
      : COLOMBO;

  return (
    <>
      <Header
        title={`Hi, ${(user?.name ?? "Worker").split(" ")[0]}`}
        subtitle={status === "APPROVED" ? "Verified professional" : status}
        right={<HeaderBell unread={unread} />}
      />

      <div className="px-4 pt-4 space-y-5">
        {/* ---------- Big online toggle ---------- */}
        <motion.div
          layout
          className={cn(
            "relative rounded-3xl border-2 p-5 overflow-hidden transition-colors",
            isOnline ? "border-primary/50 bg-primary/8" : "border-border bg-surface"
          )}
        >
          {isOnline && (
            <div className="absolute inset-0 pointer-events-none">
              <div className="absolute -top-10 -right-10 w-40 h-40 rounded-full bg-primary/15 blur-3xl" />
            </div>
          )}
          <div className="relative flex items-center justify-between">
            <div className="min-w-0">
              <div className="flex items-center gap-2">
                <span
                  className={cn(
                    "w-2.5 h-2.5 rounded-full",
                    isOnline ? "bg-primary animate-pulse" : "bg-[#3A3F47]"
                  )}
                />
                <p className="font-heading font-bold text-xl text-text">
                  {isOnline ? t("you_are_online") : t("you_are_offline")}
                </p>
              </div>
              <p className="text-sm text-muted mt-1 max-w-[220px]">
                {isBusy
                  ? "You're on a job — finish it to go offline"
                  : isOnline
                    ? t("online_hint")
                    : t("offline_hint")}
              </p>
            </div>

            {/* Swipe / tap power toggle */}
            <motion.button
              whileTap={{ scale: 0.94 }}
              onClick={() => {
                if (isBusy && isOnline) {
                  toast.error("Finish your active job first");
                  return;
                }
                toggleOnline.mutate(!isOnline);
              }}
              disabled={toggleOnline.isPending}
              aria-label={isOnline ? "Go offline" : "Go online"}
              className={cn(
                "relative w-24 h-14 rounded-full flex items-center px-1.5 transition-colors flex-shrink-0",
                isOnline ? "bg-primary shadow-glow" : "bg-[#2A2E36]"
              )}
            >
              <motion.span
                layout
                transition={{ type: "spring", stiffness: 500, damping: 32 }}
                className={cn(
                  "w-11 h-11 rounded-full bg-white flex items-center justify-center shadow-lift",
                  isOnline ? "ml-auto" : "ml-0"
                )}
              >
                {toggleOnline.isPending ? (
                  <span className="w-5 h-5 rounded-full border-2 border-primary border-t-transparent animate-spin" />
                ) : (
                  <Power className={cn("w-5 h-5", isOnline ? "text-primary" : "text-[#667085]")} />
                )}
              </motion.span>
            </motion.button>
          </div>

          {/* Warnings */}
          <div className="relative mt-4 space-y-2">
            {isOnline && permission === "denied" && (
              <Warning
                icon={MapPinOff}
                tone="danger"
                text={t("location_needed")}
              />
            )}
            {isOnline && lowAccuracy && permission === "granted" && (
              <Warning
                icon={AlertTriangle}
                tone="warning"
                text="Weak GPS signal — move to an open area for better matches"
              />
            )}
            {isOnline && (
              <Warning icon={BatteryCharging} tone="info" text={t("keep_app_open")} />
            )}
            {walletWarning && (
              <Warning
                icon={Wallet}
                tone="warning"
                text={`Top up to ${formatLkr(minWallet)} to accept cash jobs`}
              />
            )}
          </div>
        </motion.div>

        {/* ---------- Today's mini stats ---------- */}
        {isLoading ? (
          <div className="grid grid-cols-2 gap-3">
            <Skeleton className="h-20" />
            <Skeleton className="h-20" />
          </div>
        ) : (
          <div className="grid grid-cols-2 gap-3">
            <StatTile
              label={t("jobs_done")}
              value={profile?.completedJobs ?? 0}
              icon={Briefcase}
              tone="primary"
            />
            <StatTile
              label={t("rating")}
              value={Number(profile?.ratingAvg ?? 0).toFixed(1)}
              icon={Star}
              tone="amber"
              hint={`${profile?.ratingCount ?? 0} reviews`}
            />
            <StatTile
              label={t("wallet")}
              value={formatLkr(balance)}
              icon={Wallet}
              tone="amber"
            />
            <StatTile
              label={t("level")}
              value={profile?.level ?? "BRONZE"}
              icon={TrendingUp}
              tone="info"
            />
          </div>
        )}

        {/* ---------- Active job ---------- */}
        {activeJob && (
          <section>
            <SectionTitle
              title={t("active_job")}
              action={
                <button
                  onClick={() => router.push(`/app/job/${activeJob.id}`)}
                  className="text-sm font-semibold text-primary-light flex items-center min-h-[44px]"
                >
                  Open <ChevronRight className="w-4 h-4" />
                </button>
              }
            />
            <JobCard booking={activeJob} onClick={() => router.push(`/app/job/${activeJob.id}`)} />
          </section>
        )}

        {/* ---------- Live map when online ---------- */}
        {isOnline && (
          <section>
            <SectionTitle title="Your area" />
            <MapView
              center={center}
              zoom={13}
              height={200}
              markers={[
                ...(lastFix ? [{ lat: lastFix.lat, lng: lastFix.lng, kind: "me" as const }] : []),
                ...(activeJob?.address
                  ? [
                    {
                      lat: activeJob.address.lat,
                      lng: activeJob.address.lng,
                      kind: "pin" as const,
                      color: "#FFC933",
                    },
                  ]
                  : []),
              ]}
              circles={
                profile?.serviceRadiusKm
                  ? [
                    {
                      lat: center[0],
                      lng: center[1],
                      radiusM: profile.serviceRadiusKm * 1000,
                    },
                  ]
                  : undefined
              }
              className="border border-border"
            />
            <p className="text-xs text-muted mt-2 text-center">
              {lastFix
                ? `Location updated ${formatTime(new Date().toISOString())}`
                : "Acquiring your location…"}
            </p>
          </section>
        )}

        {/* ---------- Scheduled ---------- */}
        {scheduled.length > 0 && (
          <section>
            <SectionTitle
              title={t("scheduled_jobs")}
              action={
                <button
                  onClick={() => router.push("/app/schedule")}
                  className="text-sm font-semibold text-primary-light flex items-center min-h-[44px]"
                >
                  {t("see_all")} <ChevronRight className="w-4 h-4" />
                </button>
              }
            />
            <div className="space-y-3">
              {scheduled.slice(0, 3).map((b) => (
                <JobCard key={b.id} booking={b} onClick={() => router.push(`/app/job/${b.id}`)} />
              ))}
            </div>
          </section>
        )}

        {/* ---------- Open quote jobs ---------- */}
        <button
          onClick={() => router.push("/app/open-jobs")}
          className="w-full flex items-center gap-3 bg-surface rounded-2xl p-4 border border-border min-h-[64px]"
        >
          <div className="w-11 h-11 rounded-xl bg-info/12 text-info flex items-center justify-center flex-shrink-0">
            <CalendarClock className="w-5 h-5" />
          </div>
          <div className="flex-1 text-left">
            <p className="font-semibold text-sm text-text">{t("open_jobs")}</p>
            <p className="text-xs text-muted">Browse jobs and send your own quote</p>
          </div>
          <ChevronRight className="w-5 h-5 text-muted" />
        </button>

        {/* ---------- Empty state ---------- */}
        <AnimatePresence>
          {!isLoading && !activeJob && scheduled.length === 0 && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="flex flex-col items-center py-10 text-center"
            >
              <div className="w-20 h-20 rounded-full bg-elevated flex items-center justify-center mb-4">
                <RefreshCw
                  className={cn(
                    "w-9 h-9 text-muted",
                    isOnline ? "text-primary-light" : ""
                  )}
                />
              </div>
              <p className="font-heading font-semibold text-text">
                {isOnline ? t("finding_jobs") : t("no_active_job")}
              </p>
              <p className="text-sm text-muted mt-1 max-w-[260px]">
                {isOnline
                  ? "You'll be alerted the moment a job appears — no need to keep watching this screen."
                  : "Go online to start receiving job offers near you."}
              </p>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </>
  );
}

function SectionTitle({ title, action }: { title: string; action?: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between mb-3">
      <h2 className="font-heading font-semibold text-lg text-text">{title}</h2>
      {action}
    </div>
  );
}

function Warning({
  icon: Icon,
  text,
  tone,
}: {
  icon: React.ElementType;
  text: string;
  tone: "danger" | "warning" | "info";
}) {
  const tones = {
    danger: "bg-danger/10 text-danger",
    warning: "bg-warning/10 text-warning",
    info: "bg-info/10 text-info",
  };
  return (
    <div className={cn("flex items-start gap-2 rounded-xl px-3 py-2.5", tones[tone])}>
      <Icon className="w-4 h-4 flex-shrink-0 mt-0.5" />
      <p className="text-xs font-medium leading-snug">{text}</p>
    </div>
  );
}