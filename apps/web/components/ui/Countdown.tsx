"use client";
import { useEffect, useState } from "react";
export function Countdown({ target }: { target?: string | Date | null }) { const [now,setNow]=useState(Date.now()); useEffect(()=>{const id=setInterval(()=>setNow(Date.now()),1000); return()=>clearInterval(id)},[]); if(!target) return <span>--:--:--</span>; const diff=Math.max(0,new Date(target).getTime()-now); const h=Math.floor(diff/3600000), m=Math.floor(diff%3600000/60000), s=Math.floor(diff%60000/1000); return <span>{String(h).padStart(2,"0")}:{String(m).padStart(2,"0")}:{String(s).padStart(2,"0")}</span>; }
