import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { ArrowLeftRight, Play } from 'lucide-react';
import './Navbar.css';

const links = [
  { label: 'Features', href: '#features' },
  { label: 'How It Works', href: '#how' },
  { label: 'Privacy', href: '#privacy' },
  { label: 'Pro', href: '#pro' },
];

const Navbar = () => {
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const fn = () => setScrolled(window.scrollY > 40);
    window.addEventListener('scroll', fn, { passive: true });
    return () => window.removeEventListener('scroll', fn);
  }, []);

  return (
    <motion.nav
      className={`navbar ${scrolled ? 'scrolled' : ''}`}
      initial={{ y: -80, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
    >
      <div className="nav-inner container">
        <a href="#" className="nav-logo">
          <div className="logo-icon">
            <ArrowLeftRight size={20} />
          </div>
          <span>FileConverter</span>
        </a>

        <ul className={`nav-links ${open ? 'open' : ''}`}>
          {links.map((l) => (
            <li key={l.href}>
              <a href={l.href} onClick={() => setOpen(false)}>{l.label}</a>
            </li>
          ))}
        </ul>

        <div className="nav-actions">
          <a
            href="https://play.google.com/store/apps/details?id=com.smc.fileconverter"
            className="btn-primary nav-cta"
            target="_blank" rel="noreferrer"
          >
            <Play size={18} fill="currentColor" />
            <span className="nav-cta-text">Get it Free</span>
          </a>
          <button className="hamburger" onClick={() => setOpen((o) => !o)} aria-label="Menu">
            <span /><span /><span />
          </button>
        </div>
      </div>
    </motion.nav>
  );
};

export default Navbar;
