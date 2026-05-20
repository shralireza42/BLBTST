import type { Metadata } from "next";
import { Bricolage_Grotesque, Dela_Gothic_One } from "next/font/google";
import "./globals.css";
import { Providers } from "./providers";
import { Header } from "../components/layout/Header";
import { Footer } from "../components/layout/Footer";

const bricolage = Bricolage_Grotesque({ subsets: ["latin"], variable: "--font-bricolage", weight: ["400", "700", "800"] });
const dela = Dela_Gothic_One({ subsets: ["latin"], variable: "--font-dela", weight: "400" });

export const metadata: Metadata = { title: "BLOBBIE", description: "BLOBBIE Daily Draw, Jackpot, Playground, and Rewards" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en" className={`${bricolage.variable} ${dela.variable}`}><body className="body-text"><Providers><Header />{children}<Footer /></Providers></body></html>;
}
