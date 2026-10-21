import React, { ButtonHTMLAttributes, forwardRef, InputHTMLAttributes, TextareaHTMLAttributes } from "react";
import { motion } from "framer-motion";
import { Loader2 } from "lucide-react";
import { cn } from "@/lib/cn";

type Variant = "primary" | "secondary" | "ghost" | "danger" | "danger-outline" | "outline" | "success";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: "sm" | "md" | "lg";
  loading?: boolean;
  full?: boolean;
}

const variantClasses: Record<Variant, string> = {
  primary:
    "bg-primary text-white shadow-soft hover:bg-primary-dark active:scale-[0.97] disabled:bg-primary/40",
  secondary: "bg-secondary text-white hover:bg-secondary/90 active:scale-[0.97]",
  ghost: "bg-transparent text-primary hover:bg-brand-50 dark:hover:bg-white/5",
  danger: "bg-danger text-white hover:bg-danger/90 active:scale-[0.97]",
  "danger-outline":
    "border-2 border-danger/40 bg-white dark:bg-[#1A1D23] text-danger hover:bg-danger/5 active:scale-[0.97]",
  outline: "border-2 border-border bg-white dark:bg-[#1A1D23] dark:border-[#2A2E36] text-text dark:text-[#F2F4F7] hover:bg-surface dark:hover:bg-[#22262e]",
  success: "bg-success text-white hover:bg-success/90 active:scale-[0.97]",
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ variant = "primary", size = "md", loading, full, className, children, disabled, ...props }, ref) => {
    return (
      <motion.button
        ref={ref as any}
        whileTap={{ scale: 0.97 }}
        disabled={disabled || loading}
        className={cn(
          "inline-flex items-center justify-center gap-2 font-semibold rounded-xl transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 min-h-[44px]",
          size === "sm" && "h-10 px-4 text-sm min-h-[40px]",
          size === "md" && "h-[52px] px-6 text-base",
          size === "lg" && "h-[56px] px-8 text-lg",
          full && "w-full",
          variantClasses[variant],
          className
        )}
        {...(props as any)}
      >
        {loading && <Loader2 className="w-5 h-5 animate-spin" />}
        {children}
      </motion.button>
    );
  }
);
Button.displayName = "Button";

export function Card({ className, children, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "bg-white dark:bg-[#1A1D23] rounded-2xl shadow-card border border-[#E6E8EC] dark:border-[#2A2E36]",
        className
      )}
      {...props}
    >
      {children}
    </div>
  );
}

export function Chip({
  active,
  onClick,
  children,
  className,
}: {
  active?: boolean;
  onClick?: () => void;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-all min-h-[40px] border",
        active
          ? "bg-primary text-white border-primary"
          : "bg-white dark:bg-[#1A1D23] text-text dark:text-[#F2F4F7] border-[#E6E8EC] dark:border-[#2A2E36]",
        className
      )}
    >
      {children}
    </button>
  );
}

export function Badge({
  children,
  tone = "info",
  className,
}: {
  children: React.ReactNode;
  tone?: "info" | "success" | "warning" | "danger" | "neutral";
  className?: string;
}) {
  const tones = {
    info: "bg-info/10 text-info",
    success: "bg-success/10 text-success",
    warning: "bg-warning/10 text-warning",
    danger: "bg-danger/10 text-danger",
    neutral: "bg-surface dark:bg-[#22262e] text-muted dark:text-[#98A2B3]",
  };
  return (
    <span className={cn("inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold", tones[tone], className)}>
      {children}
    </span>
  );
}

export function Avatar({
  src,
  name,
  size = 48,
  className,
}: {
  src?: string | null;
  name?: string | null;
  size?: number;
  className?: string;
}) {
  const initials = (name ?? "?")
    .split(" ")
    .map((p) => p[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
  if (src) {
    return (
      <img
        src={src}
        alt={name ?? "avatar"}
        width={size}
        height={size}
        loading="lazy"
        className={cn("rounded-full object-cover bg-surface", className)}
        style={{ width: size, height: size }}
      />
    );
  }
  return (
    <div
      className={cn(
        "rounded-full bg-primary/10 text-primary font-heading font-semibold flex items-center justify-center",
        className
      )}
      style={{ width: size, height: size, fontSize: size * 0.36 }}
      aria-label={name ?? "avatar"}
    >
      {initials}
    </div>
  );
}

export function EmptyState({
  icon: Icon,
  title,
  subtitle,
  action,
}: {
  icon?: React.ElementType;
  title: string;
  subtitle?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center py-16 px-8 text-center">
      {Icon && (
        <div className="w-20 h-20 rounded-full bg-brand-50 dark:bg-white/5 flex items-center justify-center mb-4">
          <Icon className="w-10 h-10 text-primary" />
        </div>
      )}
      <h3 className="font-heading font-semibold text-lg text-text dark:text-[#F2F4F7]">{title}</h3>
      {subtitle && <p className="text-sm text-muted dark:text-[#98A2B3] mt-1 max-w-[260px]">{subtitle}</p>}
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return <div className={cn("animate-pulse rounded-xl bg-surface dark:bg-[#22262e]", className)} />;
}

export function SegmentedControl<T extends string>({
  options,
  value,
  onChange,
}: {
  options: { value: T; label: string }[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <div className="flex bg-surface dark:bg-[#22262e] rounded-xl p-1 gap-1">
      {options.map((opt) => (
        <button
          key={opt.value}
          onClick={() => onChange(opt.value)}
          className={cn(
            "flex-1 py-2.5 rounded-lg text-sm font-semibold transition-all min-h-[40px]",
            value === opt.value
              ? "bg-white dark:bg-[#1A1D23] text-primary shadow-card"
              : "text-muted dark:text-[#98A2B3]"
          )}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}

export function Toggle({ checked, onChange, label }: { checked: boolean; onChange: (v: boolean) => void; label?: string }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      onClick={() => onChange(!checked)}
      className={cn(
        "relative h-7 w-12 shrink-0 rounded-full transition-colors",
        "before:absolute before:inset-0 before:-inset-y-2.5 before:content-['']", // extended, invisible 44px touch target
        checked ? "bg-primary" : "bg-[#D0D5DD] dark:bg-[#3A3F47]"
      )}
    >
      <span
        className="absolute top-1/2 h-5 w-5 -translate-y-1/2 rounded-full bg-white shadow transition-all"
        style={{ left: checked ? 24 : 4 }}
      />
    </button>
  );
}

export const Input = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(
  ({ className, ...props }, ref) => (
    <input
      ref={ref}
      className={cn(
        "w-full h-[52px] px-4 rounded-xl border border-[#E6E8EC] dark:border-[#2A2E36] bg-white dark:bg-[#1A1D23] text-text dark:text-[#F2F4F7] placeholder:text-muted dark:placeholder:text-[#667085] focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent transition-all text-base",
        className
      )}
      {...props}
    />
  )
);
Input.displayName = "Input";

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaHTMLAttributes<HTMLTextAreaElement>>(
  ({ className, ...props }, ref) => (
    <textarea
      ref={ref}
      className={cn(
        "w-full px-4 py-3 rounded-xl border border-[#E6E8EC] dark:border-[#2A2E36] bg-white dark:bg-[#1A1D23] text-text dark:text-[#F2F4F7] placeholder:text-muted focus:outline-none focus:ring-2 focus:ring-primary transition-all text-base min-h-[110px]",
        className
      )}
      {...props}
    />
  )
);
Textarea.displayName = "Textarea";

export function Label({
  children,
  htmlFor,
  className,
}: {
  children: React.ReactNode;
  htmlFor?: string;
  className?: string;
}) {
  return (
    <label
      htmlFor={htmlFor}
      className={cn("block text-sm font-semibold text-text dark:text-[#F2F4F7] mb-2", className)}
    >
      {children}
    </label>
  );
}
