import React from 'react';
import './Ambient3DField.css';

const leftTiles = ['PDF', 'PNG', 'OCR', 'DOCX', 'IMG'];
const rightTiles = ['PRIVATE', '0 UPLOADS', 'A4', 'LOCAL', 'FAST'];

const Ambient3DField = () => (
  <div className="ambient-3d-field" aria-hidden="true">
    <div className="ambient-plane ambient-plane-left">
      {leftTiles.map((label, index) => (
        <span key={label} className={`ambient-tile ambient-tile-${index}`}>
          {label}
        </span>
      ))}
    </div>
    <div className="ambient-plane ambient-plane-right">
      {rightTiles.map((label, index) => (
        <span key={label} className={`ambient-tile ambient-tile-${index}`}>
          {label}
        </span>
      ))}
    </div>
    <span className="ambient-arc ambient-arc-a" />
    <span className="ambient-arc ambient-arc-b" />
  </div>
);

export default Ambient3DField;
