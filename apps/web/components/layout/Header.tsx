"use client";
import Link from "next/link";
import { Menu, X } from "lucide-react";
import { useState } from "react";
import { WalletButton } from "../ui/WalletButton";
import { BrandImage } from "../brand/BrandImage";
import { Button } from "../ui/Button";

const nav = [["Draw", "/draw"], ["Jackpot", "/jackpot"], ["Playground", "/playground"], ["Tasks", "/tasks"], ["Verify", "/verify"]];

export function Header() {
  const [open, setOpen] = useState(false);
  return (
    <header className="fixed left-0 right-0 top-0 z-50 px-2 pt-2 sm:px-4 sm:pt-4">
      <div className="framer-pill mx-auto max-w-[1250px] px-3 py-2">
        <div className="flex min-h-[56px] items-center justify-between gap-3">
          <Link href="/" className="flex min-w-0 items-center gap-3">
            <span className="relative h-[54px] w-[54px] shrink-0 overflow-hidden rounded-full border-[3px] border-[#020202] bg-[#fff8df] sm:h-[60px] sm:w-[60px]">
              <BrandImage kind="logo" alt="BLOBBIE logo" className="object-cover" />
            </span>
            <span className="display-text truncate text-2xl leading-none tracking-[-0.06em] sm:text-3xl">$BLOBBIE</span>
          </Link>

          <nav className="hidden items-center gap-7 lg:flex">
            {nav.map(([label, href]) => (
              <Link key={href} className="text-[15px] font-black italic hover:underline" href={href}>
                {label}
              </Link>
            ))}
          </nav>

          <div className="hidden items-center gap-2 md:flex">
            <Button href="/tasks" className="px-7 py-3">Airdrop</Button>
            <WalletButton />
          </div>

          <button className="rounded-full border-[3px] border-[#020202] bg-[#fff8df] p-2 md:hidden" onClick={() => setOpen(!open)} aria-label="Open menu">
            {open ? <X /> : <Menu />}
          </button>
        </div>

        {open && (
          <div className="grid gap-2 border-t-2 border-[#020202] pt-3 md:hidden">
            {nav.map(([label, href]) => (
              <Link onClick={() => setOpen(false)} key={href} href={href} className="rounded-2xl bg-white px-4 py-3 font-black italic">
                {label}
              </Link>
            ))}
            <WalletButton />
          </div>
        )}
      </div>
    </header>
  );
}
