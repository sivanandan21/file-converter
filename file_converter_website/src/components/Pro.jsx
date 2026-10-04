import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ArrowRight, CheckCircle2, Crown, Rocket, XCircle } from 'lucide-react';
import './Pro.css';

const freeFeatures = [
  { label: '5 conversions per 24 hours', included: true },
  { label: 'All 4 conversion types', included: true },
  { label: '100% offline & private', included: true },
  { label: 'Conversion history', included: true },
  { label: 'Banner ads shown', included: false },
  { label: 'Unlimited conversions', included: false },
  { label: 'No ads', included: false },
  { label: 'Batch conversion', included: false },
];

const proFeatures = [
  { label: 'Unlimited conversions', included: true },
  { label: 'All 4 conversion types', included: true },
  { label: '100% offline & private', included: true },
  { label: 'Conversion history', included: true },
  { label: 'No ads, ever', included: true },
  { label: 'Batch conversion', included: true },
  { label: 'Priority processing', included: true },
  { label: 'Early access to new features', included: true },
];

const plans = [
  { id: 'monthly', label: 'Monthly', price: 'Rs 99', period: '/month', badge: null, saving: null },
  { id: 'yearly', label: 'Yearly', price: 'Rs 699', period: '/year', badge: 'Best Value', saving: 'Save Rs 489' },
  { id: 'lifetime', label: 'Lifetime', price: 'Rs 1499', period: 'one-time', badge: 'Most Popular', saving: 'Pay once, own forever' },
];

const FeatureIcon = ({ included }) => (
  <span className={`feat-check ${included ? 'pro-check' : ''}`}>
    {included ? <CheckCircle2 size={15} /> : <XCircle size={15} />}
  </span>
);

const Pro = () => {
  const [selected, setSelected] = useState('yearly');

  return (
    <section id="pro" className="pro-section">
      <div className="orb orb-blue" style={{ width: 600, height: 600, top: '-100px', left: '-200px', opacity: 0.4 }} />
      <div className="orb orb-purple" style={{ width: 400, height: 400, bottom: 0, right: '-100px', opacity: 0.3 }} />

      <div className="container">
        <motion.div
          className="section-header"
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: 0.7 }}
        >
          <p className="section-label">Pro Upgrade</p>
          <h2 className="section-title">Go unlimited.<br /><span className="gradient-text">No limits, no ads.</span></h2>
          <p className="section-sub">Start free, upgrade when you need more. Cancel anytime.</p>
        </motion.div>

        <div className="pro-layout">
          <div className="pro-compare">
            <motion.div
              className="tier-card glass"
              initial={{ opacity: 0, y: 40 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
              whileHover={{ rotateY: -4, rotateX: 3, y: -6, transition: { duration: 0.25 } }}
            >
              <div className="tier-header">
                <p className="tier-name">Free</p>
                <div className="tier-price">
                  <span className="price-value">Rs 0</span>
                  <span className="price-period">forever</span>
                </div>
              </div>
              <div className="tier-holo tier-holo-free" aria-hidden="true">
                <span className="tier-holo-ring" />
                <span className="tier-holo-cube">5</span>
                <span className="tier-holo-chip">FREE</span>
              </div>
              <ul className="tier-features">
                {freeFeatures.map((f) => (
                  <li key={f.label} className={f.included ? '' : 'excluded'}>
                    <FeatureIcon included={f.included} />
                    {f.label}
                  </li>
                ))}
              </ul>
              <a
                href="https://play.google.com/store/apps/details?id=com.smc.fileconverter"
                className="btn-outline tier-btn" target="_blank" rel="noreferrer"
              >
                Download Free
              </a>
            </motion.div>

            <motion.div
              className="tier-card tier-pro glass"
              initial={{ opacity: 0, y: 40 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: 0.1 }}
              whileHover={{ rotateY: 4, rotateX: 3, y: -6, transition: { duration: 0.25 } }}
            >
              <div className="pro-crown">
                <Crown size={14} />
                PRO
              </div>
              <div className="tier-header">
                <p className="tier-name" style={{ color: '#C084FC' }}>Pro</p>

                <div className="plan-tabs">
                  {plans.map((p) => (
                    <button
                      key={p.id}
                      className={`plan-tab ${selected === p.id ? 'active' : ''}`}
                      onClick={() => setSelected(p.id)}
                    >
                      {p.label}
                      {p.badge && <span className="plan-badge">{p.badge}</span>}
                    </button>
                  ))}
                </div>

                <AnimatePresence mode="wait">
                  {plans.filter((p) => p.id === selected).map((p) => (
                    <motion.div
                      key={p.id}
                      className="tier-price"
                      initial={{ opacity: 0, y: -10 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: 10 }}
                      transition={{ duration: 0.25 }}
                    >
                      <span className="price-value gradient-text">{p.price}</span>
                      <span className="price-period">{p.period}</span>
                      {p.saving && <span className="price-saving">{p.saving}</span>}
                    </motion.div>
                  ))}
                </AnimatePresence>
              </div>
              <div className="tier-holo tier-holo-pro" aria-hidden="true">
                <span className="tier-holo-ring" />
                <span className="tier-holo-cube">UNL</span>
                <span className="tier-holo-chip">BATCH</span>
                <span className="tier-holo-chip tier-holo-chip-alt">NO ADS</span>
              </div>
              <ul className="tier-features">
                {proFeatures.map((f) => (
                  <li key={f.label} className="pro-feat">
                    <FeatureIcon included={f.included} />
                    {f.label}
                  </li>
                ))}
              </ul>
              <div className="coming-soon-notice">
                <Rocket size={15} />
                In-app billing launching soon - prices are confirmed
              </div>
              <a
                href="https://play.google.com/store/apps/details?id=com.smc.fileconverter"
                className="btn-primary tier-btn" target="_blank" rel="noreferrer"
              >
                Get on Play Store
                <ArrowRight size={17} />
              </a>
              <p className="tier-note">Payments processed securely - Cancel anytime</p>
            </motion.div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default Pro;
