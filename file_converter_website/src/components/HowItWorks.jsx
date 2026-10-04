import React from 'react';
import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { CheckCircle2, FolderOpen, Settings, Share2 } from 'lucide-react';
import './HowItWorks.css';

const steps = [
  {
    n: '01',
    Icon: FolderOpen,
    title: 'Pick a File',
    desc: 'Tap to select any PDF, image (JPG/PNG/WEBP/BMP) or DOCX from your device storage.',
    color: '#4B6BFB',
  },
  {
    n: '02',
    Icon: Settings,
    title: 'Convert Instantly',
    desc: 'Your device processes the file completely offline using on-device engines and OCR. No internet required.',
    color: '#A855F7',
  },
  {
    n: '03',
    Icon: Share2,
    title: 'Open, Share or Save',
    desc: 'Open the converted file immediately, share it via any app, or find it in your conversion history.',
    color: '#22C55E',
  },
];

const HowItWorks = () => {
  const [ref, inView] = useInView({ triggerOnce: true, threshold: 0.1 });

  return (
    <section id="how" className="how-section">
      <div className="orb orb-blue" style={{ width: 500, height: 500, bottom: '-150px', left: '-150px', opacity: 0.4 }} />
      <div className="container">
        <motion.div
          ref={ref}
          className="section-header"
          initial={{ opacity: 0, y: 30 }}
          animate={inView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.7 }}
        >
          <p className="section-label">Simple Process</p>
          <h2 className="section-title">Done in<br /><span className="gradient-text">3 steps</span></h2>
          <p className="section-sub">No learning curve. No sign-up required. Just pick, convert, done.</p>
        </motion.div>

        <div className="how-steps">
          {steps.map((s, i) => (
            <motion.div
              key={s.n}
              className="how-step"
              initial={{ opacity: 0, x: i % 2 === 0 ? -40 : 40 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true, amount: 0.3 }}
              transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1], delay: i * 0.15 }}
            >
              <div className="how-step-num" style={{ '--step-color': s.color }}>
                {s.n}
              </div>
              <motion.div
                className="how-step-content glass"
                style={{ '--step-color': s.color }}
                whileHover={{
                  y: -6,
                  rotateX: 4,
                  rotateY: i % 2 === 0 ? -4 : 4,
                  transition: { duration: 0.25 },
                }}
              >
                <div className="how-icon">
                  <s.Icon size={30} />
                </div>
                <div>
                  <h3 className="how-title">{s.title}</h3>
                  <p className="how-desc">{s.desc}</p>
                </div>
                <motion.div
                  className="how-check"
                  initial={{ scale: 0 }}
                  whileInView={{ scale: 1 }}
                  viewport={{ once: true }}
                  transition={{ delay: 0.4 + i * 0.15, type: 'spring', stiffness: 400 }}
                >
                  <CheckCircle2 size={18} />
                </motion.div>
              </motion.div>
              {i < steps.length - 1 && (
                <motion.div
                  className="how-connector"
                  initial={{ scaleY: 0 }}
                  whileInView={{ scaleY: 1 }}
                  viewport={{ once: true }}
                  transition={{ duration: 0.6, delay: 0.3 + i * 0.15, ease: 'easeOut' }}
                />
              )}
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
};

export default HowItWorks;
