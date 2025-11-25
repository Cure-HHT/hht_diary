import React from 'react';
import { Button } from './ui/button';
import { ArrowLeft, Plus, Check, HelpCircle } from 'lucide-react';

interface DaySelectionScreenProps {
  date: Date;
  onBack: () => void;
  onOptionSelect: (option: 'add-event' | 'no-nosebleeds' | 'unknown') => void;
}

export function DaySelectionScreen({ date, onBack, onOptionSelect }: DaySelectionScreenProps) {
  const formatDate = (date: Date) => {
    return date.toLocaleDateString('en-US', { 
      weekday: 'long', 
      year: 'numeric', 
      month: 'long', 
      day: 'numeric' 
    });
  };

  return (
    <div className="size-full flex flex-col bg-background">
      <div className="p-4 border-b">
        <button onClick={onBack} className="flex items-center gap-2 text-muted-foreground">
          <ArrowLeft className="w-4 h-4" />
          Back
        </button>
      </div>

      <div className="flex-1 flex flex-col p-6">
        <div className="text-center mb-8">
          <h1 className="mb-2">{formatDate(date)}</h1>
          <p className="text-muted-foreground">
            What happened on this day?
          </p>
        </div>

        <div className="flex-1 flex flex-col justify-center space-y-4">
          <Button
            onClick={() => onOptionSelect('add-event')}
            className="w-full h-16 bg-red-600 hover:bg-red-700 text-white flex items-center justify-center gap-3"
            size="lg"
          >
            <Plus className="w-6 h-6" />
            <span className="text-lg">Add nosebleed event</span>
          </Button>

          <Button
            onClick={() => onOptionSelect('no-nosebleeds')}
            className="w-full h-16 bg-green-600 hover:bg-green-700 text-white flex items-center justify-center gap-3"
            size="lg"
          >
            <Check className="w-6 h-6" />
            <span className="text-lg">No nosebleed events</span>
          </Button>

          <Button
            onClick={() => onOptionSelect('unknown')}
            variant="outline"
            className="w-full h-16 flex items-center justify-center gap-3"
            size="lg"
          >
            <HelpCircle className="w-6 h-6" />
            <span className="text-lg">I don't recall / unknown</span>
          </Button>
        </div>
      </div>
    </div>
  );
}