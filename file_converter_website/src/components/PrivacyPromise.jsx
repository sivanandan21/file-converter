import React from 'react';
import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { Lock, ShieldCheck, Trash2, UserRound, WifiOff } from 'lucide-react';
import './PrivacyPromise.css';

const pillars = [
  { Icon: Lock, title: 'Zero Uploads', desc: 'Your files are processed entirely on your device. Nothing is ever sent to a server.' },
  { Icon: WifiOff, title: 'Works Offline', desc: 'No internet connection needed. Convert files anywhere, anytime - even in airplane mode.' },
  { Icon: Trash2, title: 'Auto Cleanup', desc: 'Temporary processing files are deleted immediately after conversion completes.' },
  { Icon: UserRound, title: 'No Account Needed', desc: 'Use the free tier without ever creating an account. Sign in only to sync Pro status.' },
];

const PrivacyPromise = () => {
  const [ref, inView] = useInView({ triggerOnce: true, threshold: 0.1 });

  return (
    <section id="privacy" className="privacy-section">
      <div className="orb orb-cyan" style={{ width: 500, height: 500, top: 0, right: '-100px', opacity: 0.35 }} />
      <div className="container">
        <div className="privacy-inner">
          <motion.div
            ref={ref}
            className="privacy-text"
            initial={{ opacity: 0, x: -50 }}
            animate={inView ? { opacity: 1, x: 0 } : {}}
            transition={{ duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
          >
            <p className="section-label">Privacy First</p>
            <h2 className="section-title">Your files never<br /><span className="gradient-text">leave your device</span></h2>
            <p className="section-sub" style={{ marginBottom: 32 }}>
              In an era of cloud-everything, we chose a different path. All conversion happens locally using native on-device engines. Your documents are yours.
            </p>
            <motion.div
              className="privacy-shield"
              animate={{ scale: [1, 1.04, 1], rotateY: [0, 10, -8, 0], rotateX: [0, -4, 4, 0] }}
              transition={{ duration: 4.6, repeat: Infinity, ease: 'easeInOut' }}
            >
              <div className="shield-bg">
                <ShieldCheck size={54} />
              </div>
              <div className="shield-label">100% Private</div>
            </motion.div>
          </motion.div>

          <div className="privacy-pillars">
            {pillars.map((p, i) => (
              <motion.div
                key={p.title}
                className="pillar-card glass"
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, amount: 0.2 }}
                transition={{ duration: 0.6, delay: i * 0.1, ease: [0.22, 1, 0.36, 1] }}
                whileHover={{ scale: 1.02, rotateY: -4, z: 14, transition: { duration: 0.2 } }}
              >
                <span className="pillar-icon">
                  <p.Icon size={26} />
                </span>
                <div>
                  <h4 className="pillar-title">{p.title}</h4>
                  <p className="pillar-desc">{p.desc}</p>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
};

export default PrivacyPromise;
