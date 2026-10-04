import React from 'react';
import { ArrowLeftRight, ArrowRight } from 'lucide-react';
import './Footer.css';

const Footer = () => (
  <footer className="footer">
    <div className="gradient-divider" />
    <div className="container footer-inner">
      <div className="footer-brand">
        <div className="footer-logo">
          <div className="logo-icon">
            <ArrowLeftRight size={20} />
          </div>
          <span>FileConverter</span>
        </div>
        <p className="footer-tagline">Convert files privately.<br />On your device. Always.</p>
        <a
          href="https://play.google.com/store/apps/details?id=com.smc.fileconverter"
          className="btn-primary footer-cta"
          target="_blank" rel="noreferrer"
        >
          Download Free
          <ArrowRight size={16} />
        </a>
      </div>

      <div className="footer-links">
        <div className="footer-col">
          <p className="footer-col-title">App</p>
          <a href="#features">Features</a>
          <a href="#how">How It Works</a>
          <a href="#pro">Pro Plans</a>
        </div>
        <div className="footer-col">
          <p className="footer-col-title">Legal</p>
          <a href="#policy">Privacy Policy</a>
          <a href="mailto:privacy@smc-apps.com">Contact</a>
        </div>
      </div>
    </div>

    <div className="footer-bottom">
      <p>Copyright {new Date().getFullYear()} SMC Apps - <span className="footer-pkg">com.smc.fileconverter</span></p>
      <p>Made in India</p>
    </div>
  </footer>
);

export default Footer;
