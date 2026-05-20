import { HTMLAttributes } from "react";
import { cn } from "../../lib/utils";
export function Card({ className, ...props }: HTMLAttributes<HTMLDivElement>) { return <div className={cn("blobbie-soft rounded-[2rem] bg-[#fff8df] p-5", className)} {...props} />; }
