"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { MapPin, Star, ShieldCheck, Zap, ChevronRight, Hammer, Droplets, Zap as ZapIcon, Wind, Wrench } from "lucide-react";
import { cn } from "@/lib/cn";

const features = [
  { icon: Zap, title: "Instant booking", desc: "Nearby verified workers in minutes" },
  { icon: MapPin, title: "Live tracking", desc: "Watch your worker arrive in real time" },
  { icon: ShieldCheck, title: "Verified pros", desc: "NIC-verified technicians, rated by customers" },
];

const categories = [
  { icon: Hammer, name: "Carpenter", color: "bg-amber-100 text-amber-600" },
  { icon: Droplets, name: "Plumber", color: "bg-blue-100 text-blue-600" },
  { icon: ZapIcon, name: "Electrician", color: "bg-yellow-100 text-yellow-600" },
  { icon: Wind, name: "AC Repair", color: "bg-cyan-100 text-cyan-600" },
];

const slides = [
  {
    emoji: "⚡",
    title: "Home services, on demand",
    desc: "Electricians, plumbers, carpenters and more — booked in under a minute.",
  },
  {
    emoji: "📍",
    title: "Track in real time",
    desc: "See your worker approaching on the map, chat instantly, pay cash or card.",
  },
  {
    emoji: "⭐",
    title: "Rated & verified",
    desc: "Every worker is NIC-verified and rated by the community.",
  },
];

export default function LandingPage() {
  const [slide, setSlide] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setSlide((s) => (s + 1) % slides.length), 5000);
    return () => clearInterval(id);
  }, []);
  return (
    <div className="min-h-dvh bg-white dark:bg-[#0F1115]">
      <div className="max-w-lg mx-auto">
        <div className="relative bg-gradient-to-b from-brand-50 to-white dark:from-[#1A1D23] dark:to-[#0F1115] px-5 pt-12 pb-8 overflow-hidden">
          <div className="absolute top-16 right-4 flex gap-2">
            <Link href="/login" className="text-sm font-semibold text-text dark:text-[#F2F4F7] px-4 py-2">
              Log in
            </Link>
            <Link
              href="/login"
              className="text-sm font-semibold bg-primary text-white px-4 py-2 rounded-full"
            >
              Book now
            </Link>
          </div>
          <div className="flex items-center gap-2 mb-8">
            <div className="w-9 h-9 rounded-xl bg-primary flex items-center justify-center">
              <Zap className="w-5 h-5 text-white" />
            </div>
            <span className="font-heading font-bold text-2xl text-text dark:text-[#F2F4F7]">FixGo</span>
          </div>

          <h1 className="font-heading font-bold text-4xl leading-tight text-text dark:text-[#F2F4F7]">
            Trusted pros,
            <br />
            <span className="text-primary">at your door.</span>
          </h1>
          <p className="text-muted dark:text-[#98A2B3] mt-3 text-base max-w-[300px]">
            Book skilled technicians, carpenters and cleaners — instantly or on your schedule.
          </p>

          <div className="flex gap-3 mt-6">
            <Link
              href="/login"
              className="flex-1 bg-primary text-white font-semibold h-[52px] rounded-xl flex items-center justify-center gap-2 shadow-soft active:scale-[0.98] transition-transform"
            >
              Book a service
              <ChevronRight className="w-5 h-5" />
            </Link>
          </div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
            className="mt-8 grid grid-cols-2 gap-3"
          >
            {categories.map((c) => (
              <div
                key={c.name}
                className="bg-white dark:bg-[#1A1D23] rounded-2xl p-4 shadow-card flex items-center gap-3"
              >
                <div className={`w-11 h-11 rounded-xl ${c.color} flex items-center justify-center`}>
                  <c.icon className="w-6 h-6" />
                </div>
                <span className="font-semibold text-sm text-text dark:text-[#F2F4F7]">{c.name}</span>
              </div>
            ))}
          </motion.div>
        </div>

        <div className="px-5 py-8 space-y-8">
          {/* Value-prop highlight — one slide at a time, auto-rotating (reduced-motion safe). */}
          <section aria-label="Why FixGo" className="text-center">
            <p className="text-3xl" aria-hidden="true">{slides[slide]?.emoji}</p>
            <h2 className="font-heading font-semibold text-lg text-text dark:text-[#F2F4F7] mt-1">
              {slides[slide]?.title}
            </h2>
            <p className="text-sm text-muted dark:text-[#98A2B3] mt-1 max-w-[300px] mx-auto">
              {slides[slide]?.desc}
            </p>
            <div className="flex gap-2 justify-center mt-3">
              {slides.map((s, i) => (
                <button
                  key={i}
                  onClick={() => setSlide(i)}
                  aria-label={`Show slide ${i + 1}: ${s.title}`}
                  aria-current={i === slide}
                  className={cn(
                    "h-2 rounded-full transition-all min-h-0",
                    i === slide ? "w-5 bg-primary" : "w-2 bg-primary/30"
                  )}
                />
              ))}
            </div>
          </section>

          <div className="space-y-4">
            {features.map((f, i) => (
              <motion.div
                key={f.title}
                initial={{ opacity: 0, x: -20 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.1 }}
                className="flex gap-4 items-start bg-surface dark:bg-[#1A1D23] rounded-2xl p-4"
              >
                <div className="w-12 h-12 rounded-xl bg-brand-50 dark:bg-white/5 text-primary flex items-center justify-center flex-shrink-0">
                  <f.icon className="w-6 h-6" />
                </div>
                <div>
                  <h3 className="font-semibold text-text dark:text-[#F2F4F7]">{f.title}</h3>
                  <p className="text-sm text-muted dark:text-[#98A2B3] mt-0.5">{f.desc}</p>
                </div>
              </motion.div>
            ))}
          </div>

          <div className="bg-secondary rounded-3xl p-6 text-white text-center">
            <div className="flex justify-center gap-1 mb-3">
              {[1, 2, 3, 4, 5].map((s) => (
                <Star key={s} className="w-5 h-5 fill-warning text-warning" />
              ))}
            </div>
            <p className="font-heading font-semibold text-xl">4.8 · 10,000+ jobs done</p>
            <p className="text-white/70 text-sm mt-1">across Colombo, Negombo and suburbs</p>
            <Link
              href="/login"
              className="inline-flex items-center gap-2 bg-primary text-white font-semibold px-8 h-[52px] rounded-xl mt-5 active:scale-[0.98] transition-transform"
            >
              Get the app <ChevronRight className="w-5 h-5" />
            </Link>
          </div>

          {/* Become a worker — links to the separate FixGo Pro worker app */}
          <div className="bg-brand-50 dark:bg-[#1A1D23] border border-primary/20 rounded-3xl p-6">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 rounded-xl bg-primary/15 flex items-center justify-center flex-shrink-0">
                <Wrench className="w-6 h-6 text-primary" />
              </div>
              <div className="flex-1">
                <h3 className="font-heading font-semibold text-text dark:text-[#F2F4F7]">
                  Are you a skilled worker?
                </h3>
                <p className="text-sm text-muted dark:text-[#98A2B3] mt-0.5">
                  Join FixGo Pro and get jobs near you.
                </p>
              </div>
            </div>
            <a
              href={process.env.NEXT_PUBLIC_WORKER_APP_URL || "http://localhost:3001"}
              className="mt-4 flex items-center justify-center gap-2 w-full bg-primary text-white font-semibold h-[52px] rounded-xl active:scale-[0.98] transition-transform"
            >
              Become a FixGo Pro worker <ChevronRight className="w-5 h-5" />
            </a>
          </div>

          <p className="text-center text-xs text-muted dark:text-[#667085] pb-8">
            FixGo · Colombo, Sri Lanka · Cash · Card · Wallet
          </p>
        </div>
      </div>
    </div>
  );
}
