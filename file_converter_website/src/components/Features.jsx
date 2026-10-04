import React from 'react';
import { motion } from 'framer-motion';
import { useInView } from 'react-intersection-observer';
import { ArrowRight, FileArchive, FileText, FileType, Image } from 'lucide-react';
import './Features.css';

const features = [
  {
    id: 'pdf-img',
    Icon: Image,
    from: 'PDF',
    to: 'Image',
    color: '#4B6BFB',
    title: 'PDF to Image',
    desc: 'Render every page of a PDF into crisp PNG images at up to 220 DPI. Perfect for thumbnails, previews and sharing.',
    tags: ['High DPI', 'Multi-page', 'Fast'],
  },
  {
    id: 'img-pdf',
    Icon: FileText,
    from: 'Image',
    to: 'PDF',
    color: '#A855F7',
    title: 'Image to PDF',
    desc: 'Combine one or multiple JPG, PNG, WEBP or BMP images into a single perfectly formatted A4 PDF document.',
    tags: ['Multi-image', 'A4 Layout', 'EXIF aware'],
  },
  {
    id: 'pdf-docx',
    Icon: FileType,
    from: 'PDF',
    to: 'DOCX',
    color: '#06B6D4',
    title: 'PDF to DOCX',
    desc: 'Extract and preserve content from PDFs into editable Word documents. Uses on-device OCR for scanned pages.',
    tags: ['OCR Powered', 'Text & Images', 'Editable'],
  },
  {
    id: 'docx-pdf',
    Icon: FileArchive,
    from: 'DOCX',
    to: 'PDF',
    color: '#22C55E',
    title: 'DOCX to PDF',
    desc: 'Convert Word documents to polished PDF files in seconds. Preserves formatting, images and paragraph structure.',
    tags: ['Layout preserved', 'Instant', 'Offline'],
  },
];

const cardVariants = {
  hidden: { opacity: 0, y: 50 },
  visible: (i) => ({
    opacity: 1,
    y: 0,
    transition: { duration: 0.7, ease: [0.22, 1, 0.36, 1], delay: i * 0.1 },
  }),
};

const FeatureCard = ({ f, i }) => {
  const [ref, inView] = useInView({ triggerOnce: true, threshold: 0.15 });

  return (
    <motion.div
      ref={ref}
      className="feat-card glass"
      style={{ '--card-color': f.color }}
      custom={i}
      variants={cardVariants}
      initial="hidden"
      animate={inView ? 'visible' : 'hidden'}
      whileHover={{
        y: -10,
        rotateX: 5,
        rotateY: i % 2 === 0 ? -4 : 4,
        transition: { duration: 0.25 },
      }}
    >
      <div className="feat-glow" />
      <div className="feat-header">
        <span className="feat-icon">
          <f.Icon size={30} />
        </span>
        <div className="feat-arrow">
          <span className="feat-from">{f.from}</span>
          <motion.div
            className="feat-arrow-icon"
            animate={{ x: [0, 6, 0] }}
            transition={{ duration: 1.8, repeat: Infinity, ease: 'easeInOut' }}
          >
            <ArrowRight size={14} />
          </motion.div>
          <span className="feat-to">{f.to}</span>
        </div>
      </div>

      <div className="feat-mini-stage" aria-hidden="true">
        <span className="feat-light-beam" />
        <div className="feat-file feat-file-back">{f.to}</div>
        <div className="feat-file feat-file-middle">OCR</div>
        <div className="feat-file feat-file-front">{f.from}</div>
        <span className="feat-particle feat-particle-a" />
        <span className="feat-particle feat-particle-b" />
        <span className="feat-particle feat-particle-c" />
        <div className="feat-file-shadow" />
      </div>

      <h3 className="feat-title">{f.title}</h3>
      <p className="feat-desc">{f.desc}</p>
      <div className="feat-tags">
        {f.tags.map((t) => (
          <span key={t} className="feat-tag">{t}</span>
        ))}
      </div>
    </motion.div>
  );
};

const Features = () => {
  const [ref, inView] = useInView({ triggerOnce: true, threshold: 0.1 });

  return (
    <section id="features" className="features-section">
      <div className="orb orb-purple" style={{ width: 600, height: 600, top: '-100px', right: '-200px', opacity: 0.5 }} />
      <div className="features-3d-backdrop" aria-hidden="true">
        <span />
        <span />
        <span />
      </div>

      <div className="container">
        <motion.div
          ref={ref}
          className="section-header"
          initial={{ opacity: 0, y: 30 }}
          animate={inView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.7 }}
        >
          <p className="section-label">Conversion Engine</p>
          <h2 className="section-title">Four powerful<br /><span className="gradient-text">conversions</span></h2>
          <p className="section-sub">Every format you need, processed entirely on your device. No file ever leaves your phone.</p>
        </motion.div>

        <div className="feat-grid">
          {features.map((f, i) => <FeatureCard key={f.id} f={f} i={i} />)}
        </div>
      </div>
    </section>
  );
};

export default Features;
