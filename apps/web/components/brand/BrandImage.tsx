"use client";

import { useState } from "react";
import { cn } from "../../lib/utils";

type BrandImageProps = {
  kind: "logo" | "mascot";
  alt: string;
  className?: string;
  fallbackClassName?: string;
};

const candidates = {
  logo: ["/LOGO.png", "/logo.png", "/Logo.png", "/assets/LOGO.png", "/assets/logo.png"],
  mascot: ["/blobbie1.png", "/BLOBBIE1.png", "/Blobbie1.png", "/assets/blobbie1.png", "/assets/BLOBBIE1.png"]
};

export function BrandImage({ kind, alt, className, fallbackClassName }: BrandImageProps) {
  const [index, setIndex] = useState(0);
  const [failed, setFailed] = useState(false);
  const src = candidates[kind][index];

  if (failed || !src) {
    return (
      <div className={cn("grid h-full w-full place-items-center bg-[#fff8df] text-center", fallbackClassName)}>
        <span className="display-text text-[10px] leading-none sm:text-xs">{kind === "logo" ? "$BLOBBIE" : "BLOBBIE"}</span>
      </div>
    );
  }

  return (
    <img
      src={src}
      alt={alt}
      className={cn("h-full w-full object-contain", className)}
      onError={() => {
        if (index < candidates[kind].length - 1) setIndex(index + 1);
        else setFailed(true);
      }}
    />
  );
}
