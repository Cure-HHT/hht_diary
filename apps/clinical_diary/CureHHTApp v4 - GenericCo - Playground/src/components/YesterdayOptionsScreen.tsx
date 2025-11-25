import React from 'react';
import { Button } from './ui/button';
import { ArrowLeft, Check, HelpCircle } from 'lucide-react';

interface YesterdayOptionsScreenProps {
  onBack: () => void;
  onOptionSelect: (option: 'no-nosebleeds' | 'unknown') => void;
}

export function YesterdayOptionsScreen({ onBack, onOptionSelect }: YesterdayOptionsScreenProps) {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  
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
          <h1 className="mb-2">Yesterday</h1>
          <p className="text-muted-foreground">
            {formatDate(yesterday)}
          </p>
        </div>

        <div className="flex-1 flex flex-col justify-center space-y-4">
          <Button
            onClick={() => onOptionSelect('no-nosebleeds')}
            className="w-full h-16 bg-blue-600 hover:bg-blue-700 text-white flex items-center justify-center gap-3"
            size="lg"
          >
            <Check className="w-6 h-6" />
            <span className="text-lg">Confirm no nosebleed events</span>
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