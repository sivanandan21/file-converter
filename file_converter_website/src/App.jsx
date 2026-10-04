import React, { Suspense } from 'react';
import './index.css';
import './App.css';

import Navbar from './components/Navbar';
import Hero from './components/Hero';
import Features from './components/Features';
import HowItWorks from './components/HowItWorks';
import PrivacyPromise from './components/PrivacyPromise';
import Pro from './components/Pro';
import PrivacyPolicy from './components/PrivacyPolicy';
import Footer from './components/Footer';
import Ambient3DField from './components/Ambient3DField';
import VfxCanvas from './components/VfxCanvas';

// Lazy-load particles to not block first paint
const ParticleBackground = React.lazy(() => import('./components/ParticleBackground'));

function App() {
  return (
    <>
      <Suspense fallback={null}>
        <ParticleBackground />
      </Suspense>
      <VfxCanvas />
      <Ambient3DField />

      <Navbar />

      <main>
        <Hero />
        <div className="gradient-divider" />
        <Features />
        <div className="gradient-divider" />
        <HowItWorks />
        <div className="gradient-divider" />
        <PrivacyPromise />
        <div className="gradient-divider" />
        <Pro />
        <div className="gradient-divider" />
        <PrivacyPolicy />
      </main>

      <Footer />
    </>
  );
}

export default App;
