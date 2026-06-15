import { BrandImage } from "../components/brand/BrandImage";
import { Button } from "../components/ui/Button";
import { Card } from "../components/ui/Card";
import { Container } from "../components/layout/Container";
import { GameCard } from "../components/playground/GameCard";
import { JackpotStatusCard } from "../components/jackpot/JackpotStatusCard";

export default function Home() {
  return (
    <main className="pt-28 sm:pt-32">
      <Container>
        <section className="grid min-h-[calc(100vh-8rem)] items-center gap-10 py-8 lg:grid-cols-[1fr_0.9fr]">
          <div>
            <h6 className="text-[#f7f8df] mb-2 text-lg uppercase tracking-[.35em]">ITS</h6>
            <h1 className="marquee-word display-text text-[4.4rem] leading-[0.82] sm:text-[7rem] lg:text-[9rem]">
              BLOBBIE
            </h1>
            <h6 className="mt-5 max-w-2xl text-2xl text-[#f7f8df]">
              transparent experience without the flaws of traditional systems.
            </h6>
            <div className="mt-8 flex flex-wrap gap-4">
              <Button href="/playground" variant="secondary" className="px-8 py-4">Playground</Button>
              <Button href="/draw" className="px-8 py-4">Read More</Button>
            </div>
          </div>

          <div className="relative mx-auto aspect-square w-full max-w-[560px] rounded-full border-[6px] border-[#020202] bg-[#f7f8df] shadow-[10px_10px_0_#020202]">
            <BrandImage kind="logo" alt="BLOBBIE logo" className="rounded-full object-cover" />
          </div>
        </section>

        <section className="framer-card mb-10 p-6 sm:p-8">
          <div className="grid gap-8 lg:grid-cols-[0.8fr_1.2fr]">
            <div>
              <h6 className="uppercase tracking-[.3em]">GET IT</h6>
              <h1 className="display-text mt-2 text-5xl sm:text-7xl">SOON ON:</h1>
              <div className="mt-5 flex flex-wrap gap-3">
                {['Dexscreener', 'Pancake', 'Dextools', 'Hyperliquid'].map((item) => (
                  <span key={item} className="rounded-full border-[3px] border-[#020202] bg-white px-4 py-2 font-black italic">{item}</span>
                ))}
              </div>
            </div>
            <div>
              <h1 className="display-text text-4xl sm:text-6xl">WAGMI!</h1>
              <h6 className="mt-4 text-lg">
                Blobbie Protocol introduces a recurring distribution cycle on the Binance Smart Chain, offering a transparent and verifiable experience powered by public smart contracts.
              </h6>
              <Button href="/verify" className="mt-6">Whitepaper / Audit</Button>
            </div>
          </div>
        </section>

        <section className="grid gap-6 py-10 lg:grid-cols-2">
          <Card>
            <h6 className="uppercase tracking-[.25em]">There’s a smarter way to try your luck</h6>
            <div className="mt-6 grid gap-4 md:grid-cols-2">
              <div className="rounded-[1.5rem] border-[3px] border-[#020202] bg-white p-5">
                <h3 className="display-text text-3xl">Traditionals</h3>
                {['Requires centralized trust', 'Slow settlements', 'Geographic limits', 'Manual oversight'].map((x) => <p key={x} className="mt-3">{x}</p>)}
              </div>
              <div className="rounded-[1.5rem] border-[3px] border-[#020202] bg-[#ffc4ad] p-5">
                <h3 className="display-text text-3xl">Blobbie</h3>
                {['Verified on-chain transparency', 'Automated distributions', 'Borderless access', 'Optimized participation'].map((x) => <p key={x} className="mt-3">{x}</p>)}
              </div>
            </div>
          </Card>
          <JackpotStatusCard />
        </section>

        <section className="grid gap-6 py-10 md:grid-cols-3">
          <Card><h3 className="display-text text-3xl">On-Chain Transparency</h3><p className="mt-3">All draws and distributions occur on BSC and can be independently verified.</p></Card>
          <Card><h3 className="display-text text-3xl">Sustainable Utility</h3><p className="mt-3">Burn, treasury, referral, and task systems support long-term ecosystem health.</p></Card>
          <Card><h3 className="display-text text-3xl">Automated Distribution</h3><p className="mt-3">VRF and worker automation reduce manual intervention and improve auditability.</p></Card>
        </section>

        <section className="grid gap-6 py-10 md:grid-cols-3">
          <GameCard title="Blobbie Dash" href="/playground/blobbie-dash" desc="Fast reflex runner, Phaser-ready." />
          <GameCard title="Blobbie Blast" href="/playground/blobbie-blast" desc="Combo puzzle arena with free play." />
          <GameCard title="Blobbie Stack" href="/playground/blobbie-stack" desc="Stack your way up the leaderboard." />
        </section>
      </Container>
    </main>
  );
}
