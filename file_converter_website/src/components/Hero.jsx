import React, { useRef } from 'react';
import { motion, useScroll, useTransform } from 'framer-motion';
import {
  ArrowRight,
  Download,
  FileText,
  FileType,
  Image,
  Layers,
  Play,
  ShieldCheck,
  Sparkles,
} from 'lucide-react';
import './Hero.css';

const floatingVariants = {
  animate: (i) => ({
    y: [0, -18, 0],
    rotate: [0, i % 2 === 0 ? 6 : -6, 0],
    transition: { duration: 3.5 + i * 0.4, repeat: Infinity, ease: 'easeInOut', delay: i * 0.3 },
  }),
};

const conversionBadges = [
  { from: 'PDF', to: 'IMG', color: '#4B6BFB', Icon: Image },
  { from: 'IMG', to: 'PDF', color: '#A855F7', Icon: FileText },
  { from: 'PDF', to: 'DOCX', color: '#06B6D4', Icon: FileType },
  { from: 'DOCX', to: 'PDF', color: '#22C55E', Icon: Layers },
];

const stats = [
  { value: '4', label: 'Conversion Types' },
  { value: '0%', label: 'Data Uploaded' },
  { value: '100%', label: 'On-Device' },
  { value: 'Free', label: 'To Start' },
];

const container = {
  hidden: { opacity: 0 },
  show: { opacity: 1, transition: { staggerChildren: 0.12, delayChildren: 0.2 } },
};

const item = {
  hidden: { opacity: 0, y: 30 },
  show: { opacity: 1, y: 0, transition: { duration: 0.7, ease: [0.22, 1, 0.36, 1] } },
};

const cubeFaces = ['PDF', 'IMG', 'DOC', 'PNG', 'OCR', 'TXT'];

const Hero3DShowcase = () => (
  <motion.div className="converter-3d-wrap" variants={item} aria-hidden="true">
      <div className="converter-stage">
        <div className="stage-grid" />
        <div className="stage-reflection" />

        <div className="orbit-ring orbit-ring-a">
          <span>PDF</span>
          <span>IMG</span>
          <span>DOCX</span>
        </div>
        <div className="orbit-ring orbit-ring-b">
          <span>OCR</span>
          <span>PNG</span>
          <span>TXT</span>
        </div>

        <span className="data-beam data-beam-1" />
        <span className="data-beam data-beam-2" />
        <span className="data-beam data-beam-3" />
        <span className="data-beam data-beam-4" />

      <div className="format-chip file-pdf">
        <FileText size={18} />
        <span>PDF</span>
      </div>
      <div className="format-chip file-img">
        <Image size={18} />
        <span>PNG</span>
      </div>
      <div className="format-chip file-doc">
        <FileType size={18} />
        <span>DOCX</span>
      </div>
      <div className="format-chip file-private">
        <ShieldCheck size={18} />
        <span>LOCAL</span>
      </div>

      <div className="converter-device">
        <div className="device-bezel">
          <div className="device-topbar">
            <span className="device-dot" />
            <span className="device-dot" />
            <span className="device-dot" />
            <span className="device-mode">On-device</span>
          </div>

          <div className="device-screen">
            <div className="screen-scanline" />
            <span className="screen-node screen-node-a" />
            <span className="screen-node screen-node-b" />
            <span className="screen-node screen-node-c" />

            <div className="document-card input-card">
              <FileText size={30} />
              <span>PDF</span>
              <i />
              <i />
              <i />
            </div>

            <div className="document-card preview-card">
              <Layers size={24} />
              <span>OCR</span>
              <i />
              <i />
            </div>

            <div className="transfer-line" />

            <div className="conversion-core">
              <div className="conversion-cube">
                {cubeFaces.map((face, index) => (
                  <span key={face} className={`cube-face cube-face-${index}`}>
                    {face}
                  </span>
                ))}
              </div>
              <Sparkles size={18} className="core-spark" />
            </div>

            <div className="document-card output-card">
              <Image size={30} />
              <span>Image</span>
              <i />
              <i />
              <i />
            </div>
          </div>

          <div className="device-rail">
            <span>
              <ShieldCheck size={14} />
              Private
            </span>
            <span>0 uploads</span>
          </div>
        </div>
      </div>
    </div>
  </motion.div>
);

const Hero = () => {
  const ref = useRef(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end start'] });
  const y = useTransform(scrollYProgress, [0, 1], ['0%', '30%']);
  const opacity = useTransform(scrollYProgress, [0, 0.6], [1, 0]);

  return (
    <section className="hero" ref={ref}>
      <div className="orb orb-blue" style={{ width: 700, height: 700, top: '-200px', left: '-200px' }} />
      <div className="orb orb-purple" style={{ width: 500, height: 500, top: '100px', right: '-150px' }} />
      <div className="orb orb-cyan" style={{ width: 400, height: 400, bottom: '-100px', left: '30%' }} />

      <motion.div className="hero-inner container" style={{ y, opacity }} variants={container} initial="hidden" animate="show">
        <motion.div variants={item}>
          <span className="chip">
            <Play size={12} fill="currentColor" />
            Now on Google Play
          </span>
        </motion.div>

        <motion.h1 className="hero-title display" variants={item}>
          <span className="title-line">Convert Files.</span><br />
          <span className="gradient-text title-line title-line-gradient">Stay Private.</span>
        </motion.h1>

        <motion.p className="hero-sub" variants={item}>
          PDF to Image. PDF to DOCX. All on your device.
          No cloud uploads, no accounts needed. Just convert.
        </motion.p>

        <motion.div className="hero-ctas" variants={item}>
          <a
            href="https://play.google.com/store/apps/details?id=com.smc.fileconverter"
            className="btn-primary"
            target="_blank" rel="noreferrer"
          >
            <Download size={22} />
            Download Free on Play Store
          </a>
          <a href="#features" className="btn-outline">
            See Features
            <ArrowRight size={18} />
          </a>
        </motion.div>

        <Hero3DShowcase />

        <motion.div className="hero-badges" variants={item}>
          {conversionBadges.map((b, i) => (
            <motion.div
              key={`${b.from}-${b.to}`}
              className="badge-pill"
              style={{ '--accent-color': b.color }}
              custom={i}
              variants={floatingVariants}
              animate="animate"
            >
              <span className="badge-icon">
                <b.Icon size={16} />
              </span>
              <span className="badge-from">{b.from}</span>
              <ArrowRight size={16} strokeWidth={2.5} opacity="0.6" />
              <span className="badge-to">{b.to}</span>
            </motion.div>
          ))}
        </motion.div>

        <motion.div className="hero-stats" variants={item}>
          {stats.map((s) => (
            <div key={s.label} className="stat-item">
              <span className="stat-value gradient-text">{s.value}</span>
              <span className="stat-label">{s.label}</span>
            </div>
          ))}
        </motion.div>
      </motion.div>

      <motion.div
        className="scroll-indicator"
        initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 2 }}
      >
        <motion.div className="scroll-dot" animate={{ y: [0, 12, 0] }} transition={{ duration: 1.5, repeat: Infinity }} />
      </motion.div>
    </section>
  );
};

export default Hero;
