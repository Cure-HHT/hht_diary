import React, { useState } from 'react';
import { Button } from './ui/button';
import { Textarea } from './ui/textarea';
import { ArrowLeft, ArrowRight } from 'lucide-react';

interface NotesInputProps {
  notes: string;
  onNotesChange: (notes: string) => void;
  onBack: () => void;
  onNext: () => void;
}

const SHORTCUT_OPTIONS = [
  "Data transcribed from written records",
  "Estimated", 
  "Specific memory tied to an event"
];

export function NotesInput({ notes, onNotesChange, onBack, onNext }: NotesInputProps) {
  const [localNotes, setLocalNotes] = useState(notes);

  const handleShortcutClick = (shortcutText: string) => {
    setLocalNotes(shortcutText);
    onNotesChange(shortcutText);
  };

  const handleTextChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const newValue = e.target.value;
    setLocalNotes(newValue);
    onNotesChange(newValue);
  };

  const handleNext = () => {
    onNotesChange(localNotes);
    onNext();
  };

  return (
    <div className="min-h-screen flex flex-col bg-background">
      {/* Header */}
      <div className="flex-none p-6">
        <div className="flex items-center gap-4 mb-6">
          <button 
            onClick={onBack}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <h2>Add Notes</h2>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 flex flex-col p-6">
        <div className="max-w-md mx-auto w-full space-y-6">
          <div className="text-center space-y-2">
            <p className="text-muted-foreground">
              You are editing an event in the past. Please provide an explanation for clinical trial records:
            </p>
          </div>

          {/* Shortcut buttons */}
          <div className="space-y-3">
            <p className="font-medium">Quick options:</p>
            <div className="space-y-2">
              {SHORTCUT_OPTIONS.map((option, index) => (
                <Button
                  key={index}
                  variant="outline"
                  className="w-full text-left justify-start h-auto py-3 px-4"
                  onClick={() => handleShortcutClick(option)}
                >
                  <span className="whitespace-normal">{option}</span>
                </Button>
              ))}
            </div>
          </div>

          {/* Text area */}
          <div className="space-y-3">
            <p className="font-medium">Or write your own notes:</p>
            <Textarea
              value={localNotes}
              onChange={handleTextChange}
              placeholder="Enter additional details about this event..."
              className="min-h-[120px] resize-none"
              rows={5}
            />
          </div>

          {/* Navigation */}
          <div className="flex gap-3 pt-4">
            <Button
              variant="outline"
              className="flex-1"
              onClick={onBack}
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              Back
            </Button>
            <Button
              className="flex-1"
              onClick={handleNext}
            >
              Continue
              <ArrowRight className="w-4 h-4 ml-2" />
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}