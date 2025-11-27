import React, { useState } from 'react';
import { Button } from './ui/button';
import { ArrowLeft, Monitor, Sun, Moon } from 'lucide-react';
import { Checkbox } from './ui/checkbox';
import { Label } from './ui/label';

interface SettingsScreenProps {
  onBack: () => void;
}

export function SettingsScreen({ onBack }: SettingsScreenProps) {
  // State for settings options (UI only, no functionality)
  const [colorScheme, setColorScheme] = useState<'light' | 'dark'>('light');
  const [dyslexiaFriendlyFont, setDyslexiaFriendlyFont] = useState(false);
  const [largerTextAndControls, setLargerTextAndControls] = useState(false);

  return (
    <div className="min-h-screen flex flex-col bg-background">
      {/* Header */}
      <div className="flex-none p-6 border-b border-border">
        <div className="flex items-center gap-4">
          <Button
            onClick={onBack}
            variant="ghost"
            size="sm"
            className="p-2"
          >
            <ArrowLeft className="w-5 h-5" />
          </Button>
          <h1>Settings</h1>
        </div>
      </div>

      {/* Settings Content */}
      <div className="flex-1 p-6 space-y-8">
        
        {/* Color Scheme Section */}
        <div className="space-y-4">
          <div>
            <h3>Color Scheme</h3>
            <p className="text-sm text-muted-foreground">
              Choose your preferred appearance
            </p>
          </div>
          
          <div className="space-y-3">
            <button
              onClick={() => setColorScheme('light')}
              className={`w-full flex items-center gap-3 p-3 rounded-lg border transition-colors ${
                colorScheme === 'light' 
                  ? 'border-primary bg-accent' 
                  : 'border-border hover:bg-accent/50'
              }`}
            >
              <Sun className="w-5 h-5" />
              <div className="flex-1 text-left">
                <div className="font-medium">Light Mode</div>
                <div className="text-sm text-muted-foreground">
                  Bright appearance with light backgrounds
                </div>
              </div>
              <div className={`w-4 h-4 rounded-full border-2 ${
                colorScheme === 'light' 
                  ? 'border-primary bg-primary' 
                  : 'border-muted-foreground'
              }`} />
            </button>
            
            <button
              onClick={() => setColorScheme('dark')}
              className={`w-full flex items-center gap-3 p-3 rounded-lg border transition-colors ${
                colorScheme === 'dark' 
                  ? 'border-primary bg-accent' 
                  : 'border-border hover:bg-accent/50'
              }`}
            >
              <Moon className="w-5 h-5" />
              <div className="flex-1 text-left">
                <div className="font-medium">Dark Mode</div>
                <div className="text-sm text-muted-foreground">
                  Reduced brightness with dark backgrounds
                </div>
              </div>
              <div className={`w-4 h-4 rounded-full border-2 ${
                colorScheme === 'dark' 
                  ? 'border-primary bg-primary' 
                  : 'border-muted-foreground'
              }`} />
            </button>
          </div>
        </div>

        {/* Accessibility Section */}
        <div className="space-y-4">
          <div>
            <h3>Accessibility</h3>
            <p className="text-sm text-muted-foreground">
              Customize the app for better readability and usability
            </p>
          </div>
          
          <div className="space-y-4">
            {/* Dyslexia-friendly font */}
            <div className="flex items-start gap-3 p-3 rounded-lg border border-border">
              <Checkbox
                id="dyslexia-font"
                checked={dyslexiaFriendlyFont}
                onCheckedChange={setDyslexiaFriendlyFont}
                className="mt-0.5"
              />
              <div className="flex-1">
                <Label htmlFor="dyslexia-font" className="font-medium cursor-pointer">
                  Dyslexia-friendly font
                </Label>
                <p className="text-sm text-muted-foreground mt-1">
                  Use OpenDyslexic font for improved readability. Learn more at{' '}
                  <a 
                    href="https://opendyslexic.org/" 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="text-primary hover:underline"
                  >
                    opendyslexic.org
                  </a>
                </p>
              </div>
            </div>

            {/* Larger text and controls */}
            <div className="flex items-start gap-3 p-3 rounded-lg border border-border">
              <Checkbox
                id="larger-text"
                checked={largerTextAndControls}
                onCheckedChange={setLargerTextAndControls}
                className="mt-0.5"
              />
              <div className="flex-1">
                <Label htmlFor="larger-text" className="font-medium cursor-pointer">
                  Larger Text and Controls
                </Label>
                <p className="text-sm text-muted-foreground mt-1">
                  Increase the size of text and interactive elements for easier reading and navigation
                </p>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}