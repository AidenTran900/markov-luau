import React from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import useBaseUrl from '@docusaurus/useBaseUrl';

export default function Home() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <Layout
      title={siteConfig.title}
      description="A Luau port + extention of MarkovJunior">

      <header style={{
        padding: '6rem 0',
        textAlign: 'center',
        background: 'var(--ifm-color-primary-darker)',
        color: 'white',
      }}>
        <div className="container">
          <img
            src={useBaseUrl('/Logo.svg')}
            alt="MarkovLuau Logo"
            style={{
              height: '300px',
              marginBottom: '-8rem',
            }}
          />
          <p className="hero__subtitle" style={{ fontSize: '1.5rem', opacity: 0.9 }}>{siteConfig.tagline}</p>

          <div style={{ display: 'flex', justifyContent: 'center', gap: '1rem', marginTop: '2.5rem' }}>
            <Link
              className="button button--secondary button--lg"
              style={{ padding: '0.8rem 2rem', fontWeight: 'bold' }}
              to="/docs/intro">
              Get Started
            </Link>
            <Link
              className="button button--outline button--secondary button--lg"
              style={{ padding: '0.8rem 2rem', fontWeight: 'bold', color: 'white', borderColor: 'white' }}
              to="/api/">
              API Reference
            </Link>
          </div>
        </div>
      </header>

      <main style={{ backgroundColor: 'var(--ifm-background-surface-color)' }}>
        <section style={{ padding: '5rem 0' }}>
          <div className="container">
            <div className="row" style={{ alignItems: 'center' }}>
              <div className="col col--6">
                <h2 style={{ fontSize: '2.5rem', marginBottom: '1.5rem' }}>Procedural Generation for Luau</h2>
                <p style={{ fontSize: '1.2rem', lineHeight: '1.6', marginBottom: '1.5rem' }}>
                  MarkovLuau is a robust, headless port and extention of <strong>MarkovJunior</strong> for the Luau language. It provides a programmatic DSL for generating complex structures and textures using Wave Function Collapse and rule-based systems.
                </p>
                <ul style={{ fontSize: '1.1rem', lineHeight: '1.8' }}>
                  <li><strong>Programmatic DSL:</strong> The <code>Author</code> module allows building models directly in code.</li>
                  <li><strong>Time Travel:</strong> Snapshot-driven playback for step-by-step visualization.</li>
                  <li><strong>Grid Locking:</strong> Define protected layout bounds that rules can read but not overwrite.</li>
                </ul>
              </div>
              <div className="col col--6" style={{ textAlign: 'center' }}>
                <img
                  src={useBaseUrl('/ApartmazementsThumb.png')}
                  alt="Apartmazements Example"
                  style={{
                    maxWidth: '100%',
                    transform: 'perspective(1000px) rotateY(-5deg)',
                    transition: 'transform 0.3s ease'
                  }}
                />
              </div>
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
