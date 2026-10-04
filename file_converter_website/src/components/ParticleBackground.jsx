import React, { useEffect, useCallback } from 'react';
import Particles from '@tsparticles/react';
import { loadSlim } from '@tsparticles/slim';

const ParticleBackground = () => {
  useEffect(() => {
    loadSlim(window.tsParticles || {}).catch(() => {});
  }, []);

  const particlesInit = useCallback(async (engine) => {
    await loadSlim(engine);
  }, []);

  return (
    <Particles
      id="tsparticles"
      init={particlesInit}
      options={{
        background: { color: { value: 'transparent' } },
        fpsLimit: 60,
        particles: {
          number: { value: 60, density: { enable: true, area: 900 } },
          color: { value: ['#4B6BFB', '#A855F7', '#06B6D4'] },
          shape: { type: 'circle' },
          opacity: { value: { min: 0.05, max: 0.35 }, animation: { enable: true, speed: 0.8, minimumValue: 0.05 } },
          size: { value: { min: 1, max: 3 }, animation: { enable: true, speed: 2, minimumValue: 0.5 } },
          links: { enable: true, distance: 140, color: '#4B6BFB', opacity: 0.08, width: 1 },
          move: { enable: true, speed: 0.6, direction: 'none', random: true, straight: false, outModes: 'out' },
        },
        interactivity: {
          events: { onHover: { enable: true, mode: 'grab' }, onClick: { enable: true, mode: 'push' } },
          modes: { grab: { distance: 180, links: { opacity: 0.3 } }, push: { quantity: 3 } },
        },
        detectRetina: true,
      }}
    />
  );
};

export default ParticleBackground;
