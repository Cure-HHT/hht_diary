import React from 'react';
import { ArrowLeft, Plus } from 'lucide-react';
import { NosebleedRecord } from '../App';
import { EventListItem } from './EventListItem';



interface DateRecordsScreenProps {
  date: Date;
  records: NosebleedRecord[];
  incompleteRecords: NosebleedRecord[];
  recordsWithOverlaps: Set<string>;
  onBack: () => void;
  onEditRecord: (recordIndex: number) => void;
  onAddNewEvent: () => void;
}

export function DateRecordsScreen({
  date,
  records,
  incompleteRecords,
  recordsWithOverlaps,
  onBack,
  onEditRecord,
  onAddNewEvent
}: DateRecordsScreenProps) {
  
  // Get records for the selected date
  const recordsForDate = records
    .map((record, index) => ({ ...record, originalIndex: index }))
    .filter(record => {
      if (!record.date || !(record.date instanceof Date)) return false;
      return record.date.toDateString() === date.toDateString();
    })
    .sort((a, b) => {
      // Sort by start time
      if (!a.startTime || !b.startTime) return 0;
      return a.startTime.getTime() - b.startTime.getTime();
    });



  const formatDate = (date: Date) => {
    const today = new Date();
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    
    if (date.toDateString() === today.toDateString()) {
      return 'Today';
    } else if (date.toDateString() === yesterday.toDateString()) {
      return 'Yesterday';
    } else {
      return date.toLocaleDateString('en-US', { 
        weekday: 'long', 
        month: 'long', 
        day: 'numeric' 
      });
    }
  };

  return (
    <div className="min-h-screen bg-background flex flex-col">
      {/* Header */}
      <div className="flex-none p-6 md:p-4">
        <div className="flex items-center gap-4 mb-4 md:mb-3">
          <button 
            onClick={onBack}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
          >
            <ArrowLeft className="w-6 h-6" />
          </button>
          <div className="flex-1">
            <h1 className="text-lg md:text-lg font-medium">{formatDate(date)}</h1>
            <p className="text-sm text-muted-foreground">
              {recordsForDate.length} event{recordsForDate.length !== 1 ? 's' : ''}
            </p>
          </div>
        </div>
      </div>

      {/* Records List */}
      <div className="flex-1 px-6 pb-6 overflow-y-auto">
        <div className="space-y-3 md:space-y-2">
          {recordsForDate.map((record, index) => {
            const isIncomplete = incompleteRecords.some(incompleteRecord => 
              incompleteRecord.id === record.id
            );
            const hasOverlap = recordsWithOverlaps.has(record.id);

            return (
              <EventListItem
                key={record.id}
                record={record}
                isIncomplete={isIncomplete}
                hasOverlap={hasOverlap}
                onClick={() => onEditRecord(record.originalIndex)}
                clickable={!record.isSurveyEvent}
              />
            );
          })}
        </div>
      </div>

      {/* Add New Event Button */}
      <div className="flex-none p-6 md:p-4">
        <button
          onClick={onAddNewEvent}
          className="w-full flex items-center justify-center gap-3 py-4 md:py-3 px-4 bg-red-600 hover:bg-red-700 text-white rounded-xl transition-colors"
        >
          <Plus className="w-5 h-5 md:w-4 md:h-4" />
          <span className="font-medium">Add New Event</span>
        </button>
      </div>
    </div>
  );
}