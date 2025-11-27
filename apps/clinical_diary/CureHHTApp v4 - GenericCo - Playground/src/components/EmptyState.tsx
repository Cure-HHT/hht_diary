import React from 'react';
import { Calendar, Plus } from 'lucide-react';

interface EmptyStateProps {
  onStartRecording: () => void;
}

export function EmptyState({ onStartRecording }: EmptyStateProps) {
  return (
    <div className="flex-1 flex flex-col items-center justify-center p-8 text-center">
      <div className="mb-8">
        <Calendar className="w-16 h-16 text-muted-foreground mx-auto mb-4" />
        <h2 className="mb-2">Welcome to Nosebleed Tracker</h2>
        <p className="text-muted-foreground max-w-md">
          Start tracking your nosebleed events to better understand patterns and share accurate information with your healthcare provider.
        </p>
      </div>
      
      <div className="space-y-4 text-left max-w-sm">
        <div className="flex items-start gap-3">
          <div className="w-2 h-2 rounded-full bg-primary mt-2 flex-shrink-0" />
          <span className="text-muted-foreground">
            Record start and end times accurately
          </span>
        </div>
        <div className="flex items-start gap-3">
          <div className="w-2 h-2 rounded-full bg-primary mt-2 flex-shrink-0" />
          <span className="text-muted-foreground">
            Track severity levels from spotting to severe
          </span>
        </div>
        <div className="flex items-start gap-3">
          <div className="w-2 h-2 rounded-full bg-primary mt-2 flex-shrink-0" />
          <span className="text-muted-foreground">
            Monitor patterns over time
          </span>
        </div>
      </div>
      
      <button
        onClick={onStartRecording}
        className="mt-8 flex items-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors"
      >
        <Plus className="w-4 h-4" />
        Record Your First Event
      </button>
    </div>
  );
}