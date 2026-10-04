import React, { useEffect, useRef } from 'react';
import './VfxCanvas.css';

const VfxCanvas = () => {
  const canvasRef = useRef(null);

  useEffect(() => {
    const media = window.matchMedia('(prefers-reduced-motion: reduce)');
    if (media.matches) return undefined;

    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d', { alpha: true });
    const pointer = { x: window.innerWidth * 0.52, y: window.innerHeight * 0.42, active: false };
    const wisps = Array.from({ length: 18 }, (_, i) => ({
      seed: i * 91.7,
      x: Math.random() * window.innerWidth,
      y: Math.random() * window.innerHeight,
      speed: 0.0018 + Math.random() * 0.0022,
      radius: 140 + Math.random() * 260,
      hue: [218, 190, 148, 270, 42][i % 5],
      width: 0.8 + Math.random() * 1.8,
    }));

    let width = 0;
    let height = 0;
    let raf = 0;

    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 1.75);
      width = window.innerWidth;
      height = window.innerHeight;
      canvas.width = Math.floor(width * dpr);
      canvas.height = Math.floor(height * dpr);
      canvas.style.width = `${width}px`;
      canvas.style.height = `${height}px`;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };

    const onMove = (event) => {
      pointer.x = event.clientX;
      pointer.y = event.clientY;
      pointer.active = true;
    };

    const drawWisp = (wisp, time, index) => {
      const t = time * wisp.speed + wisp.seed;
      const centerX = width * (0.5 + Math.sin(t * 0.72) * 0.38);
      const centerY = height * (0.5 + Math.cos(t * 0.58) * 0.34);
      const pull = pointer.active ? 0.18 : 0.04;
      const x = centerX + (pointer.x - centerX) * pull + Math.sin(t * 1.9) * wisp.radius * 0.18;
      const y = centerY + (pointer.y - centerY) * pull + Math.cos(t * 1.4) * wisp.radius * 0.13;
      const length = 120 + Math.sin(t * 1.2) * 42;
      const angle = t * 0.9 + index * 0.72;

      const x1 = x + Math.cos(angle) * length;
      const y1 = y + Math.sin(angle) * length * 0.36;
      const x2 = x - Math.cos(angle * 0.78) * length;
      const y2 = y - Math.sin(angle * 0.92) * length * 0.36;

      const gradient = ctx.createLinearGradient(x1, y1, x2, y2);
      gradient.addColorStop(0, `hsla(${wisp.hue}, 95%, 66%, 0)`);
      gradient.addColorStop(0.45, `hsla(${wisp.hue}, 95%, 66%, 0.32)`);
      gradient.addColorStop(0.55, `hsla(${(wisp.hue + 55) % 360}, 92%, 62%, 0.42)`);
      gradient.addColorStop(1, `hsla(${wisp.hue}, 95%, 66%, 0)`);

      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.bezierCurveTo(x, y - length * 0.42, x, y + length * 0.42, x2, y2);
      ctx.strokeStyle = gradient;
      ctx.lineWidth = wisp.width;
      ctx.stroke();

      ctx.beginPath();
      ctx.arc(x, y, 1.2 + (index % 3) * 0.7, 0, Math.PI * 2);
      ctx.fillStyle = `hsla(${wisp.hue}, 95%, 70%, 0.38)`;
      ctx.fill();
    };

    const render = (time) => {
      ctx.clearRect(0, 0, width, height);
      ctx.globalCompositeOperation = 'lighter';

      wisps.forEach((wisp, index) => drawWisp(wisp, time, index));

      const pulse = 0.35 + Math.sin(time * 0.002) * 0.14;
      const glow = ctx.createRadialGradient(pointer.x, pointer.y, 0, pointer.x, pointer.y, 240);
      glow.addColorStop(0, `rgba(103,232,249,${pointer.active ? pulse : 0.08})`);
      glow.addColorStop(0.35, 'rgba(75,107,251,0.08)');
      glow.addColorStop(1, 'rgba(75,107,251,0)');
      ctx.fillStyle = glow;
      ctx.fillRect(pointer.x - 260, pointer.y - 260, 520, 520);

      raf = requestAnimationFrame(render);
    };

    resize();
    window.addEventListener('resize', resize);
    window.addEventListener('pointermove', onMove, { passive: true });
    raf = requestAnimationFrame(render);

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('resize', resize);
      window.removeEventListener('pointermove', onMove);
    };
  }, []);

  return <canvas ref={canvasRef} className="vfx-canvas" aria-hidden="true" />;
};

export default VfxCanvas;
