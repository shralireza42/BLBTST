import { ButtonHTMLAttributes, AnchorHTMLAttributes } from "react";
import Link from "next/link";
import { cn } from "../../lib/utils";

type Props = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary"|"secondary"|"ghost"; href?: string };
export function Button({ className, variant="primary", href, ...props }: Props) {
  const classes = cn("inline-flex items-center justify-center rounded-full border-[3px] border-[#020202] px-5 py-3 text-sm font-black italic transition active:translate-y-1 disabled:opacity-50", variant==="primary"&&"bg-[#fff8df] shadow-[4px_4px_0_#020202] hover:bg-white", variant==="secondary"&&"bg-[#bc352a] text-[#fff8df] shadow-[4px_4px_0_#020202]", variant==="ghost"&&"border-transparent shadow-none hover:bg-black/5", className);
  if (href) return <Link className={classes} href={href}>{props.children}</Link>;
  return <button className={classes} {...props} />;
}
