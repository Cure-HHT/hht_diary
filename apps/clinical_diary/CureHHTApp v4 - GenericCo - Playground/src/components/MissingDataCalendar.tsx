import React from 'react';
import { Calendar } from './ui/calendar';
import { X } from 'lucide-react';
import { NosebleedRecord } from '../App';

interface MissingDataCalendarProps {
  isOpen: boolean;
  onClose: () => void;
  onDateSelect: (date: Date) => void;
  missingDays: Date[];
  records?: NosebleedRecord[];
  incompleteRecords?: NosebleedRecord[];
}

export function MissingDataCalendar({ 
  isOpen, 
  onClose, 
  onDateSelect, 
  missingDays, 
  records = [], 
  incompleteRecords = []
}: MissingDataCalendarProps) {
  if (!isOpen) return null;

  const handleDateSelect = (date: Date | undefined) => {
    if (date) {
      // Only allow selection of missing days
      const isMissingDay = missingDays.some(missingDay => 
        missingDay.toDateString() === date.toDateString()
      );
      
      if (isMissingDay) {
        onDateSelect(date);
      }
    }
  };

  // Helper function to get the earliest record date
  const getEarliestRecordDate = () => {
    if (records.length === 0) return null;
    const validRecords = records.filter(record => record.date && record.date instanceof Date);
    if (validRecords.length === 0) return null;
    return validRecords.reduce((earliest, record) => {
      return record.date < earliest ? record.date : earliest;
    }, validRecords[0].date);
  };



  // Helper function to classify a date and return its status
  const getDateStatus = (date: Date) => {
    const dateStr = date.toDateString();
    const today = new Date().toDateString();
    const earliestDate = getEarliestRecordDate();
    
    // Check if it's today
    const isToday = dateStr === today;
    
    // Check if it's missing data
    const isMissingData = missingDays.some(d => d.toDateString() === dateStr);
    
    // Check if it's before the first recorded event
    const isBeforeFirstRecord = earliestDate && date < earliestDate;
    
    // Check for records on this date
    const recordsForDate = records.filter(record => {
      if (!record.date || !(record.date instanceof Date)) return false;
      return record.date.toDateString() === dateStr;
    });
    
    // Check for incomplete records on this date
    const hasIncompleteRecords = incompleteRecords.some(record => {
      if (!record.date || !(record.date instanceof Date)) return false;
      return record.date.toDateString() === dateStr;
    });
    
    if (hasIncompleteRecords || isMissingData) {
      return { type: 'incomplete', isToday };
    }
    
    if (recordsForDate.length === 0) {
      return { type: isBeforeFirstRecord ? 'beforeFirst' : 'noEvents', isToday };
    }
    
    // Check types of records
    const hasNosebleedEvents = recordsForDate.some(r => !r.isNoNosebleedsEvent && !r.isUnknownEvent);
    const hasNoNosebleedEvents = recordsForDate.some(r => r.isNoNosebleedsEvent);
    const hasUnknownEvents = recordsForDate.some(r => r.isUnknownEvent);
    
    if (hasNosebleedEvents) {
      return { type: 'nosebleed', isToday };
    } else if (hasNoNosebleedEvents) {
      return { type: 'noNosebleed', isToday };
    } else if (hasUnknownEvents) {
      return { type: 'unknown', isToday };
    }
    
    return { type: 'noEvents', isToday };
  };

  // Create modifiers and styles for the calendar
  const nosebleedDates = [];
  const noNosebleedDates = [];
  const unknownDates = [];
  const incompleteDates = [];
  const noEventDates = [];
  const beforeFirstDates = [];
  const todayDates = [];
  const nosebleedTodayDates = [];
  const noNosebleedTodayDates = [];
  const unknownTodayDates = [];
  const incompleteTodayDates = [];
  const noEventsTodayDates = [];
  const beforeFirstTodayDates = [];

  // Generate a range of dates to classify (last 2 years to next year)
  const startDate = new Date();
  startDate.setFullYear(startDate.getFullYear() - 2);
  const endDate = new Date();
  endDate.setFullYear(endDate.getFullYear() + 1);

  for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
    const dateStatus = getDateStatus(new Date(d));
    const currentDate = new Date(d);
    
    if (dateStatus.isToday) {
      todayDates.push(currentDate);
      // Also add to today-specific modifiers
      switch (dateStatus.type) {
        case 'nosebleed':
          nosebleedTodayDates.push(currentDate);
          break;
        case 'noNosebleed':
          noNosebleedTodayDates.push(currentDate);
          break;
        case 'unknown':
          unknownTodayDates.push(currentDate);
          break;
        case 'incomplete':
          incompleteTodayDates.push(currentDate);
          break;
        case 'beforeFirst':
          beforeFirstTodayDates.push(currentDate);
          break;
        case 'noEvents':
          noEventsTodayDates.push(currentDate);
          break;
      }
    }
    
    switch (dateStatus.type) {
      case 'nosebleed':
        nosebleedDates.push(currentDate);
        break;
      case 'noNosebleed':
        noNosebleedDates.push(currentDate);
        break;
      case 'unknown':
        unknownDates.push(currentDate);
        break;
      case 'incomplete':
        incompleteDates.push(currentDate);
        break;
      case 'beforeFirst':
        beforeFirstDates.push(currentDate);
        break;
      case 'noEvents':
        noEventDates.push(currentDate);
        break;
    }
  }

  const modifiers = {
    nosebleed: nosebleedDates,
    noNosebleed: noNosebleedDates,
    unknown: unknownDates,
    incomplete: incompleteDates,
    noEvents: noEventDates,
    beforeFirst: beforeFirstDates,
    nosebleedToday: nosebleedTodayDates,
    noNosebleedToday: noNosebleedTodayDates,
    unknownToday: unknownTodayDates,
    incompleteToday: incompleteTodayDates,
    noEventsToday: noEventsTodayDates,
    beforeFirstToday: beforeFirstTodayDates,
    missingData: missingDays,
  };

  const modifiersStyles = {
    nosebleed: {
      backgroundColor: '#dc2626',
      color: '#ffffff',
      fontWeight: 'bold',
    },
    noNosebleed: {
      backgroundColor: '#16a34a',
      color: '#ffffff',
      fontWeight: 'bold',
    },
    unknown: {
      backgroundColor: '#eab308',
      color: '#000000',
      fontWeight: 'bold',
    },
    incomplete: {
      backgroundColor: '#000000',
      color: '#ffffff',
      fontWeight: 'bold',
    },
    noEvents: {
      backgroundColor: '#6b7280',
      color: '#ffffff',
    },
    beforeFirst: {
      backgroundColor: '#6b7280',
      color: '#ffffff',
    },
    nosebleedToday: {
      backgroundColor: '#dc2626',
      color: '#ffffff',
      fontWeight: 'bold',
      boxShadow: 'inset 0 0 0 2px rgba(255, 255, 255, 0.6)',
      borderRadius: '50%',
    },
    noNosebleedToday: {
      backgroundColor: '#16a34a',
      color: '#ffffff',
      fontWeight: 'bold',
      boxShadow: 'inset 0 0 0 2px rgba(255, 255, 255, 0.6)',
      borderRadius: '50%',
    },
    unknownToday: {
      backgroundColor: '#eab308',
      color: '#000000',
      fontWeight: 'bold',
      boxShadow: 'inset 0 0 0 2px rgba(0, 0, 0, 0.6)',
      borderRadius: '50%',
    },
    incompleteToday: {
      backgroundColor: '#000000',
      color: '#ffffff',
      fontWeight: 'bold',
      boxShadow: 'inset 0 0 0 2px rgba(255, 255, 255, 0.6)',
      borderRadius: '50%',
    },
    noEventsToday: {
      backgroundColor: '#6b7280',
      color: '#ffffff',
      boxShadow: 'inset 0 0 0 2px rgba(255, 255, 255, 0.6)',
      borderRadius: '50%',
    },
    beforeFirstToday: {
      backgroundColor: '#6b7280',
      color: '#ffffff',
      boxShadow: 'inset 0 0 0 2px rgba(255, 255, 255, 0.6)',
      borderRadius: '50%',
    },

    missingData: {
      backgroundColor: '#000000',
      color: '#ffffff',
      fontWeight: 'bold',
    },
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
      <div className="bg-background rounded-2xl p-6 shadow-xl max-w-sm w-full">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-medium">Missing Data</h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-muted rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>
        
        <Calendar
          mode="single"
          onSelect={handleDateSelect}
          className="w-full"
          modifiers={modifiers}
          modifiersStyles={modifiersStyles}
          initialFocus
        />
        
        <div className="mt-4 space-y-2">
          <div className="grid grid-cols-2 gap-2 text-xs">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 bg-red-600 rounded"></div>
              <span>Nosebleed events</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 bg-green-600 rounded"></div>
              <span>No nosebleeds</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 bg-yellow-600 rounded"></div>
              <span>Unknown</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 bg-black rounded"></div>
              <span>Incomplete/Missing</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 bg-gray-500 rounded"></div>
              <span>No events</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 border-2 border-gray-400 rounded-full"></div>
              <span>Today</span>
            </div>

          </div>
          <p className="text-sm text-muted-foreground text-center">
            Tap a highlighted date to add data for that day
          </p>
        </div>
      </div>
    </div>
  );
}