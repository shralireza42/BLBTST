import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
export function cn(...inputs: ClassValue[]) { return twMerge(clsx(inputs)); }
export function shortAddress(address?: string) { return address ? `${address.slice(0, 6)}...${address.slice(-4)}` : ""; }
export function formatToken(value?: string | number | null) { if (value == null) return "--"; const n = Number(value) / 1e18; return Number.isFinite(n) ? n.toLocaleString(undefined,{maximumFractionDigits:2}) : String(value); }
