import React, { useState, useCallback } from 'react';
import { Button } from './ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from './ui/dialog';
import { Input } from './ui/input';

interface MaterialTimePickerProps {
  time: Date;
  onChange: (time: Date) => void;
  editable: boolean;
  label: string;
  showAdjustButtons?: boolean;
  onConfirm?: () => void;
  confirmButtonText?: string;
}

type ClockMode = 'hours' | 'minutes';

export function MaterialTimePicker({ 
  time, 
  onChange, 
  editable, 
  label, 
  showAdjustButtons = false,
  onConfirm,
  confirmButtonText = "Record Start Time"
}: MaterialTimePickerProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [clockMode, setClockMode] = useState<ClockMode>('hours');
  
  // Internal state for the picker
  const [selectedHour, setSelectedHour] = useState(time.getHours() % 12 || 12);
  const [selectedMinute, setSelectedMinute] = useState(time.getMinutes());
  const [isAM, setIsAM] = useState(time.getHours() < 12);

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString('en-US', { 
      hour: 'numeric', 
      minute: '2-digit',
      hour12: true 
    });
  };

  const adjustTime = (minutes: number) => {
    const newTime = new Date(time);
    newTime.setMinutes(newTime.getMinutes() + minutes);
    onChange(newTime);
  };

  const handleOpenPicker = () => {
    if (editable) {
      // Reset picker state to current time
      setSelectedHour(time.getHours() % 12 || 12);
      setSelectedMinute(time.getMinutes());
      setIsAM(time.getHours() < 12);
      setClockMode('hours');
      setIsOpen(true);
    }
  };

  const handleHourChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = parseInt(e.target.value);
    if (value >= 1 && value <= 12) {
      setSelectedHour(value);
    }
  };

  const handleMinuteChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = parseInt(e.target.value);
    if (value >= 0 && value <= 59) {
      setSelectedMinute(value);
    }
  };

  const handleClockClick = useCallback((event: React.MouseEvent<HTMLDivElement>) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const centerX = rect.width / 2;
    const centerY = rect.height / 2;
    const x = event.clientX - rect.left - centerX;
    const y = event.clientY - rect.top - centerY;
    
    const angle = Math.atan2(y, x);
    const degrees = ((angle * 180 / Math.PI) + 90 + 360) % 360;
    
    if (clockMode === 'hours') {
      const hour = Math.round(degrees / 30) || 12;
      setSelectedHour(hour);
      // Auto-advance to minutes after selecting hour
      setTimeout(() => setClockMode('minutes'), 200);
    } else {
      const minute = Math.round(degrees / 6) % 60;
      setSelectedMinute(minute);
    }
  }, [clockMode]);

  const handleOK = () => {
    const newTime = new Date(time);
    let hour24 = selectedHour;
    if (selectedHour === 12) {
      hour24 = isAM ? 0 : 12;
    } else {
      hour24 = isAM ? selectedHour : selectedHour + 12;
    }
    newTime.setHours(hour24, selectedMinute, 0, 0);
    onChange(newTime);
    setIsOpen(false);
    
    // Trigger onConfirm callback if provided (for advancing to next step)
    if (onConfirm) {
      onConfirm();
    }
  };

  const handleCancel = () => {
    setIsOpen(false);
  };

  const renderClockFace = () => {
    const radius = 100;
    const centerX = 120;
    const centerY = 120;
    
    const numbers = clockMode === 'hours' 
      ? Array.from({length: 12}, (_, i) => i === 0 ? 12 : i)
      : Array.from({length: 12}, (_, i) => i * 5);
    
    // Calculate angles for both hands (always visible)
    const hourAngle = ((selectedHour % 12) * 30 - 90) * Math.PI / 180;
    const minuteAngle = (selectedMinute * 6 - 90) * Math.PI / 180;
    
    // Hour hand is shorter (50% of radius) and wider
    const hourHandLength = radius * 0.5;
    const hourHandX = centerX + hourHandLength * Math.cos(hourAngle);
    const hourHandY = centerY + hourHandLength * Math.sin(hourAngle);
    
    // Minute hand is longer (70% of radius) and thinner
    const minuteHandLength = radius * 0.7;
    const minuteHandX = centerX + minuteHandLength * Math.cos(minuteAngle);
    const minuteHandY = centerY + minuteHandLength * Math.sin(minuteAngle);

    return (
      <div className="relative">
        <svg width="240" height="240" className="touch-none">
          {/* Clock circle */}
          <circle
            cx={centerX}
            cy={centerY}
            r={radius}
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            className="text-border"
          />
          
          {/* Hour/minute markers */}
          {numbers.map((num, index) => {
            const angle = (index * (360 / numbers.length) - 90) * Math.PI / 180;
            const x = centerX + radius * 0.8 * Math.cos(angle);
            const y = centerY + radius * 0.8 * Math.sin(angle);
            const isSelected = clockMode === 'hours' ? num === selectedHour : num === selectedMinute;
            
            return (
              <g key={num}>
                <circle
                  cx={x}
                  cy={y}
                  r="16"
                  fill={isSelected ? "currentColor" : "transparent"}
                  className={`cursor-pointer ${isSelected ? "text-primary" : ""}`}
                />
                <text
                  x={x}
                  y={y}
                  textAnchor="middle"
                  dominantBaseline="central"
                  className={`text-sm select-none cursor-pointer ${
                    isSelected ? "fill-primary-foreground" : "fill-foreground"
                  }`}
                >
                  {clockMode === 'minutes' && num < 10 ? `0${num}` : num}
                </text>
              </g>
            );
          })}
          
          {/* Hour hand - shorter and wider */}
          <line
            x1={centerX}
            y1={centerY}
            x2={hourHandX}
            y2={hourHandY}
            stroke="currentColor"
            strokeWidth="6"
            strokeLinecap="round"
            opacity={clockMode === 'hours' ? 1 : 0.7}
            className="text-primary"
          />
          
          {/* Minute hand - longer and thinner */}
          <line
            x1={centerX}
            y1={centerY}
            x2={minuteHandX}
            y2={minuteHandY}
            stroke="currentColor"
            strokeWidth="3"
            strokeLinecap="round"
            opacity={clockMode === 'minutes' ? 1 : 0.7}
            className="text-primary"
          />
          
          {/* Center dot */}
          <circle
            cx={centerX}
            cy={centerY}
            r="4"
            fill="currentColor"
            className="text-primary"
          />
        </svg>
        
        {/* Invisible click area */}
        <div
          className="absolute inset-0 cursor-pointer"
          onClick={handleClockClick}
        />
      </div>
    );
  };

  return (
    <div className="space-y-4">
      {label && (
        <div className="text-center">
          <div className="text-sm text-muted-foreground">{label}</div>
        </div>
      )}
      
      <div className="text-center">
        <button
          onClick={handleOpenPicker}
          className="text-3xl font-medium p-2 rounded-lg hover:bg-muted/50 transition-colors"
          disabled={!editable}
        >
          {formatTime(time)}
        </button>
      </div>

      {showAdjustButtons && (
        <div className="space-y-3">
          <Button
            variant="outline"
            className="w-full"
            onClick={() => adjustTime(-5)}
          >
            Subtract 5 minutes
          </Button>
          
          <Button
            variant="outline"
            className="w-full"
            onClick={() => adjustTime(-15)}
          >
            Subtract 15 minutes
          </Button>
          
          {onConfirm && (
            <Button
              className="w-full"
              size="lg"
              onClick={onConfirm}
            >
              {confirmButtonText}
            </Button>
          )}
        </div>
      )}

      <Dialog open={isOpen} onOpenChange={setIsOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Set Time</DialogTitle>
            <DialogDescription>
              Choose the time by editing the fields or clicking on the clock face.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-6">
            {/* Time display and inputs */}
            <div className="flex items-center justify-center gap-3">
              <div className="text-center">
                <Input
                  type="number"
                  min="1"
                  max="12"
                  value={selectedHour.toString().padStart(2, '0')}
                  onChange={handleHourChange}
                  className="w-16 text-center text-xl font-mono"
                />
                <div className="text-xs text-muted-foreground mt-1">Hour</div>
              </div>
              
              <div className="text-2xl font-medium">:</div>
              
              <div className="text-center">
                <Input
                  type="number"
                  min="0"
                  max="59"
                  value={selectedMinute.toString().padStart(2, '0')}
                  onChange={handleMinuteChange}
                  className="w-16 text-center text-xl font-mono"
                />
                <div className="text-xs text-muted-foreground mt-1">Minute</div>
              </div>
              
              <div className="flex flex-col gap-1 ml-2">
                <button
                  className={`px-3 py-1 rounded text-sm transition-colors ${
                    isAM 
                      ? 'bg-primary text-primary-foreground' 
                      : 'bg-muted text-muted-foreground hover:bg-muted/80'
                  }`}
                  onClick={() => setIsAM(true)}
                >
                  AM
                </button>
                <button
                  className={`px-3 py-1 rounded text-sm transition-colors ${
                    !isAM 
                      ? 'bg-primary text-primary-foreground' 
                      : 'bg-muted text-muted-foreground hover:bg-muted/80'
                  }`}
                  onClick={() => setIsAM(false)}
                >
                  PM
                </button>
              </div>
            </div>

            {/* Mode selector */}
            <div className="flex justify-center gap-4">
              <button
                className={`px-4 py-2 rounded text-sm transition-colors ${
                  clockMode === 'hours'
                    ? 'bg-primary text-primary-foreground'
                    : 'text-muted-foreground hover:bg-muted'
                }`}
                onClick={() => setClockMode('hours')}
              >
                Set Hours
              </button>
              <button
                className={`px-4 py-2 rounded text-sm transition-colors ${
                  clockMode === 'minutes'
                    ? 'bg-primary text-primary-foreground'
                    : 'text-muted-foreground hover:bg-muted'
                }`}
                onClick={() => setClockMode('minutes')}
              >
                Set Minutes
              </button>
            </div>

            {/* Clock face */}
            <div className="flex justify-center">
              {renderClockFace()}
            </div>

            {/* Action buttons */}
            <div className="flex gap-3 justify-end">
              <Button variant="outline" onClick={handleCancel}>
                Cancel
              </Button>
              <Button onClick={handleOK}>
                OK
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}