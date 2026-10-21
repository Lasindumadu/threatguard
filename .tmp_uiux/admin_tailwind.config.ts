/** @type {import('tailwindcss').Config} */
const config = {
  darkMode: "class",
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        primary: { DEFAULT: "#FF6B00", dark: "#E65F00", light: "#FF8A33" },
        secondary: "#1B1F3B",
        surface: "#F6F7F9",
        brand: {
          50: "#FFF4EC",
          100: "#FFE5D1",
          500: "#FF6B00",
          600: "#E65F00",
          700: "#C44F00",
        },
        success: "#12B76A",
        warning: "#F79009",
        danger: "#F04438",
        info: "#2E90FA",
      },
      fontFamily: {
        sans: ["Inter", "Noto Sans Sinhala", "Noto Sans Tamil", "system-ui", "sans-serif"],
        heading: ["Poppins", "Noto Sans Sinhala", "Noto Sans Tamil", "system-ui", "sans-serif"],
      },
      boxShadow: {
        soft: "0 4px 16px rgba(16,24,40,.08)",
        card: "0 2px 12px rgba(16,24,40,.06)",
        lift: "0 8px 24px rgba(16,24,40,.12)",
      },
    },
  },
  plugins: [],
};
export default config;