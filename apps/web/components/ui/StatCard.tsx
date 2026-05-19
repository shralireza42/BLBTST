import { Card } from "./Card";
export function StatCard({ label, value, hint }: { label: string; value: React.ReactNode; hint?: string }) { return <Card className="p-4"><p className="text-xs uppercase tracking-widest opacity-70">{label}</p><div className="display-text mt-2 text-2xl md:text-3xl">{value}</div>{hint&&<p className="mt-1 text-xs opacity-70">{hint}</p>}</Card>; }
