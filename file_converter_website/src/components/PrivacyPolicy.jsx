import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronDown } from 'lucide-react';
import './PrivacyPolicy.css';

const sections = [
  {
    title: '1. Information We Collect',
    content: `We collect minimal information necessary to operate the app:

- Device identifiers (Android ID) to manage your daily usage quota
- Device model and Android OS version for crash reporting and compatibility
- Your outbound IP address (collected once at session start for analytics only)
- If you sign in with Google: your email address and Google account ID (used only to sync your Pro status and usage quota across devices)

We do NOT collect, read, or transmit the content of any files you convert.`,
  },
  {
    title: '2. How We Use Your Information',
    content: `Information collected is used solely to:

- Enforce the free-tier daily conversion quota (5 conversions per 24-hour window)
- Sync your Pro subscription status across devices when you are signed in
- Diagnose crashes and improve app stability
- Display relevant ads via Google AdMob (see Section 4)`,
  },
  {
    title: '3. File Processing & Privacy',
    content: `All file conversion happens entirely on your device using on-device processing engines.

- No file content is ever uploaded to our servers or any third-party server
- Temporary files created during processing are deleted immediately after conversion completes
- Your documents remain 100% private at all times`,
  },
  {
    title: '4. Advertising (Google AdMob)',
    content: `The free tier of the app displays advertisements provided by Google AdMob. AdMob may collect device advertising identifiers and usage data to serve relevant ads.

- You can reset your advertising ID in your Android device settings
- Pro subscribers see no ads whatsoever
- For AdMob's privacy policy, visit: https://policies.google.com/privacy`,
  },
  {
    title: '5. Third-Party Services',
    content: `We use the following third-party services:

- Supabase (supabase.com) - Backend database for quota management and user accounts. Data stored: device ID, usage count, plan status, email (if signed in).
- Google AdMob - Advertising network (free tier only)
- Google Sign-In - Optional authentication for cross-device Pro sync`,
  },
  {
    title: '6. Data Retention & Deletion',
    content: `Your data is retained only as long as necessary:

- Usage quota records reset every 24 hours automatically
- If you delete your account or uninstall the app, all locally stored data is removed immediately
- To request deletion of your Supabase-stored data (email and usage records), contact us at the email below`,
  },
  {
    title: '7. Children\'s Privacy',
    content: `File Format Converter is not directed at children under 13. We do not knowingly collect personal information from children. If you believe a child has provided us personal information, please contact us and we will delete it promptly.`,
  },
  {
    title: '8. Changes to This Policy',
    content: `We may update this Privacy Policy from time to time. Changes will be posted on this page with an updated effective date. Continued use of the app after changes constitutes acceptance of the revised policy.`,
  },
  {
    title: '9. Contact Us',
    content: `If you have any questions or concerns about this Privacy Policy or your data, please contact us:

Email: privacy@smc-apps.com
App: File Format Converter (com.smc.fileconverter)
Developer: SMC Apps`,
  },
];

const PolicySection = ({ s, i }) => {
  const [open, setOpen] = useState(i === 0);

  return (
    <motion.div
      className="policy-item glass"
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.1 }}
      transition={{ duration: 0.5, delay: i * 0.04 }}
    >
      <button className="policy-toggle" onClick={() => setOpen((o) => !o)}>
        <span className="policy-title">{s.title}</span>
        <motion.span className="policy-arrow" animate={{ rotate: open ? 180 : 0 }} transition={{ duration: 0.25 }}>
          <ChevronDown size={19} />
        </motion.span>
      </button>
      <AnimatePresence initial={false}>
        {open && (
          <motion.div
            className="policy-content"
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
          >
            <div className="policy-text">{s.content}</div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
};

const PrivacyPolicy = () => (
  <section id="policy" className="policy-section">
    <div className="container">
      <motion.div
        className="section-header"
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.7 }}
      >
        <p className="section-label">Legal</p>
        <h2 className="section-title">Privacy <span className="gradient-text">Policy</span></h2>
        <p className="section-sub">Effective date: June 24, 2026. We believe in full transparency about what data we collect and why.</p>
      </motion.div>
      <div className="policy-list">
        {sections.map((s, i) => <PolicySection key={s.title} s={s} i={i} />)}
      </div>
    </div>
  </section>
);

export default PrivacyPolicy;
