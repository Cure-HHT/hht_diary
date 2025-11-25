import React, { useState } from 'react';
import { Calendar } from './ui/calendar';
import { Popover, PopoverContent, PopoverTrigger } from './ui/popover';
import { Button } from './ui/button';
import { CalendarIcon } from 'lucide-react';
// Using built-in date formatting instead of date-fns

interface DateHeaderProps {
  date: Date;
  onChange: (date: Date) => void;
  editable: boolean;
}

export function DateHeader({ date, onChange, editable }: DateHeaderProps) {
  const [isOpen, setIsOpen] = useState(false);

  const handleDateSelect = (selectedDate: Date | undefined) => {
    if (selectedDate) {
      onChange(selectedDate);
      setIsOpen(false);
    }
  };

  const formatDate = (date: Date) => {
    return date.toLocaleDateString('en-US', { 
      weekday: 'long', 
      year: 'numeric', 
      month: 'long', 
      day: 'numeric' 
    });
  };

  if (!editable) {
    return (
      <div className="text-center">
        <h2>{formatDate(date)}</h2>
      </div>
    );
  }

  return (
    <div className="text-center mb-6">
      <Popover open={isOpen} onOpenChange={setIsOpen}>
        <PopoverTrigger asChild>
          <Button 
            variant="ghost" 
            className="text-lg font-medium p-3 h-auto hover:bg-muted/50 transition-colors"
          >
            <CalendarIcon className="w-5 h-5 mr-3" />
            {formatDate(date)}
          </Button>
        </PopoverTrigger>
        <PopoverContent className="w-auto p-0" align="center">
          <Calendar
            mode="single"
            selected={date}
            onSelect={handleDateSelect}
            initialFocus
          />
        </PopoverContent>
      </Popover>
    </div>
  );
}