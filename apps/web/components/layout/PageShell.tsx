import { Container } from "./Container";

export function PageShell({ eyebrow, title, intro, children }: { eyebrow?: string; title: string; intro?: string; children: React.ReactNode }) {
  return (
    <main className="pt-32 pb-16 sm:pt-36">
      <Container>
        <section className="page-panel mb-8 max-w-5xl rounded-[2.25rem] p-6 sm:p-8">
          {eyebrow && <h6 className="mb-2 text-sm uppercase tracking-[.25em]">{eyebrow}</h6>}
          <h1 className="display-text text-4xl leading-[0.95] sm:text-6xl lg:text-7xl">{title}</h1>
          {intro && <h6 className="mt-4 max-w-3xl text-lg sm:text-xl">{intro}</h6>}
        </section>
        {children}
      </Container>
    </main>
  );
}
