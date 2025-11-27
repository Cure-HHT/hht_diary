import React, { useState } from 'react';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from './ui/alert-dialog';
import { NosebleedRecord } from '../App';
import { RadioGroup, RadioGroupItem } from './ui/radio-group';
import { Label } from './ui/label';
import { Clock } from 'lucide-react';

interface DeleteConfirmationDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onConfirmDelete: (reason: string) => void;
  record: NosebleedRecord | null;
}

const DELETION_REASONS = [
  'Duplicate entry',
  'Entered by mistake',
  'Wrong information',
  'Wrong date/time',
];

export function DeleteConfirmationDialog({
  open,
  onOpenChange,
  onConfirmDelete,
  record,
}: DeleteConfirmationDialogProps) {
  const [selectedReason, setSelectedReason] = useState<string>('');

  const handleConfirm = () => {
    if (selectedReason) {
      onConfirmDelete(selectedReason);
      setSelectedReason(''); // Reset for next time
      onOpenChange(false);
    }
  };

  const handleCancel = () => {
    setSelectedReason(''); // Reset selection
    onOpenChange(false);
  };

  if (!record) return null;

  // Format time helper
  const formatTime = (date: Date | undefined) => {
    if (!date) return 'Not set';
    return date.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit', hour12: true });
  };

  // Calculate duration
  const getDuration = () => {
    if (!record.startTime || !record.endTime) return null;
    const diff = record.endTime.getTime() - record.startTime.getTime();
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    if (hours > 0) {
      return `${hours}h ${mins}m`;
    }
    return `${mins}m`;
  };

  const duration = getDuration();

  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent className="max-w-md">
        <AlertDialogHeader>
          <AlertDialogTitle>Are you sure you want to delete this event?</AlertDialogTitle>
          <AlertDialogDescription>
            Review the event details below and select a reason for deletion before confirming.
          </AlertDialogDescription>
        </AlertDialogHeader>
        
        <div className="space-y-3">
          {/* Event Details */}
          <div className="bg-muted p-3 rounded-lg space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-sm text-muted-foreground">Date:</span>
              <span className="font-medium">
                {record.date?.toLocaleDateString(undefined, {
                  weekday: 'short',
                  month: 'short',
                  day: 'numeric',
                  year: 'numeric',
                })}
              </span>
            </div>
            
            {!record.isSurveyEvent && !record.isNoNosebleedsEvent && !record.isUnknownEvent && (
              <>
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">Start Time:</span>
                  <span className="font-medium">{formatTime(record.startTime)}</span>
                </div>
                
                <div className="flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">End Time:</span>
                  <span className="font-medium">{formatTime(record.endTime)}</span>
                </div>
                
                {duration && (
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-muted-foreground">Duration:</span>
                    <div className="flex items-center gap-1">
                      <Clock className="w-3 h-3" />
                      <span className="font-medium">{duration}</span>
                    </div>
                  </div>
                )}
                
                {record.severity && (
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-muted-foreground">Severity:</span>
                    <span className="font-medium">{record.severity}</span>
                  </div>
                )}
              </>
            )}
            
            {record.isNoNosebleedsEvent && (
              <div className="text-center text-sm font-medium text-green-600">
                No Nosebleeds Event
              </div>
            )}
            
            {record.isUnknownEvent && (
              <div className="text-center text-sm font-medium text-yellow-600">
                Unknown Event
              </div>
            )}
            
            {record.isSurveyEvent && record.surveyName && (
              <div className="text-center text-sm font-medium">
                Survey: {record.surveyName}
              </div>
            )}
            
            {record.notes && (
              <div className="pt-2 border-t">
                <span className="text-sm text-muted-foreground">Notes:</span>
                <p className="text-sm mt-1">{record.notes}</p>
              </div>
            )}
          </div>
          
          {/* Deletion Reason Selection */}
          <div className="pt-2">
            <Label className="text-foreground mb-2 block">
              Reason for deletion <span className="text-destructive">*</span>
            </Label>
            <RadioGroup value={selectedReason} onValueChange={setSelectedReason}>
              <div className="space-y-2">
                {DELETION_REASONS.map((reason) => (
                  <div key={reason} className="flex items-center space-x-2">
                    <RadioGroupItem value={reason} id={reason} />
                    <Label htmlFor={reason} className="font-normal cursor-pointer">
                      {reason}
                    </Label>
                  </div>
                ))}
              </div>
            </RadioGroup>
          </div>
        </div>
        
        <AlertDialogFooter>
          <AlertDialogCancel onClick={handleCancel}>Keep Event</AlertDialogCancel>
          <AlertDialogAction
            onClick={handleConfirm}
            disabled={!selectedReason}
            className="bg-destructive text-destructive-foreground hover:bg-destructive/90 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Delete Event
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}