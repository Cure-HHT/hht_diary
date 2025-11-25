import React from 'react';
import { Button } from './ui/button';
import spottingIcon from 'figma:asset/2abb485475a2155888f0b9cf5d60b00d0e60c0dc.png';
import drippingIcon from 'figma:asset/b7c32eb7099d240e6e35c5e4d31747c2f17d3f14.png';
import drippingQuicklyIcon from 'figma:asset/7143b924359de55136b437848338c8123becffb7.png';
import steadyStreamIcon from 'figma:asset/af3ed36b994236e727da82af8cc77fecd4419201.png';
import pouringIcon from 'figma:asset/d8f6cd656bd09578a87697e17d921cc06a8fe405.png';
import gushingIcon from 'figma:asset/2b7e1aa050a7930996e53d943b2b2436daf6a8ca.png';

interface SeverityOption {
  id: string;
  label: string;
  icon: React.ReactNode;
}

interface SeveritySelectionProps {
  onSelect: (severity: string) => void;
  selectedSeverity?: string;
}

const severityOptions: SeverityOption[] = [
  {
    id: 'spotting',
    label: 'Spotting',
    icon: <img src={spottingIcon} alt="Spotting" className="w-24 h-24" />
  },
  {
    id: 'dripping',
    label: 'Dripping',
    icon: <img src={drippingIcon} alt="Dripping" className="w-24 h-24" />
  },
  {
    id: 'dripping-quickly',
    label: 'Dripping quickly',
    icon: <img src={drippingQuicklyIcon} alt="Dripping quickly" className="w-24 h-24" />
  },
  {
    id: 'steady-stream',
    label: 'Steady stream',
    icon: <img src={steadyStreamIcon} alt="Steady stream" className="w-24 h-24" />
  },
  {
    id: 'pouring',
    label: 'Pouring',
    icon: <img src={pouringIcon} alt="Pouring" className="w-24 h-24" />
  },
  {
    id: 'gushing',
    label: 'Gushing',
    icon: <img src={gushingIcon} alt="Gushing" className="w-24 h-24" />
  }
];

export function SeveritySelection({ onSelect, selectedSeverity }: SeveritySelectionProps) {
  return (
    <div className="space-y-3">
      <div className="text-center">
        <h3>How severe is the nosebleed?</h3>
        <p className="text-sm text-muted-foreground">
          Select the option that best describes the bleeding
        </p>
      </div>

      <div className="grid grid-cols-2 gap-3">
        {severityOptions.map((option) => (
          <button
            key={option.id}
            className={`flex flex-col items-center p-3 rounded-lg transition-all ${
              selectedSeverity === option.label 
                ? 'bg-primary/10 ring-2 ring-primary' 
                : 'hover:bg-muted/50'
            }`}
            onClick={() => onSelect(option.label)}
          >
            <div className="flex-shrink-0">
              {option.icon}
            </div>
            <div className="font-medium text-sm leading-tight text-center">
              {option.label}
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}