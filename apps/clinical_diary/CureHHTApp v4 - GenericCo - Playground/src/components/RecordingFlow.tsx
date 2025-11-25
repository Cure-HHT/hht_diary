import React, { useState, useEffect } from 'react';
import { NosebleedRecord } from '../App';
import { DateHeader } from './DateHeader';
import { MaterialTimePicker } from './MaterialTimePicker';
import { SeveritySelection } from './SeveritySelection';
import { NotesInput } from './NotesInput';
import { Button } from './ui/button';
import { ArrowLeft, AlertTriangle, Trash2 } from 'lucide-react';
import { Alert, AlertDescription } from './ui/alert';
import { DeleteConfirmationDialog } from './DeleteConfirmationDialog';

interface RecordingFlowProps {
  onSave: (record: NosebleedRecord) => void;
  onBack: (incompleteRecord?: NosebleedRecord) => void;
  onDelete: (reason: string) => void;
  existingRecord?: NosebleedRecord;
  initialDate?: Date;
  recordId?: string;
  records?: NosebleedRecord[];
  getOverlappingEvents?: (record: NosebleedRecord) => NosebleedRecord[];
  isEnrolledInTrial?: boolean;
  enrollmentDateTime?: Date | null;
  enrollmentStatus?: 'active' | 'ended';
}

export type RecordingStep = 'start-time' | 'severity' | 'end-time' | 'notes' | 'complete';

// Compact Summary Component
function RecordSummary({ 
  record, 
  currentStep, 
  currentEndTime,
  onFieldClick
}: { 
  record: NosebleedRecord; 
  currentStep: RecordingStep;
  currentEndTime: Date;
  onFieldClick: (field: 'start-time' | 'severity' | 'end-time') => void;
}) {
  const formatTime = (date: Date | undefined) => {
    if (!date) return '--:--';
    return date.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit', hour12: true });
  };

  const formatTimeWithDayDiff = (endTime: Date, startTime?: Date) => {
    if (!endTime || !startTime) return formatTime(endTime);
    
    const startDay = new Date(startTime);
    startDay.setHours(0, 0, 0, 0);
    const endDay = new Date(endTime);
    endDay.setHours(0, 0, 0, 0);
    
    const dayDiff = Math.round((endDay.getTime() - startDay.getTime()) / (24 * 60 * 60 * 1000));
    
    if (dayDiff === 0) {
      return formatTime(endTime);
    } else if (dayDiff === 1) {
      return `${formatTime(endTime)} (+1 day)`;
    } else {
      return `${formatTime(endTime)} (+${dayDiff} days)`;
    }
  };

  return (
    <div className="p-4 bg-muted/30 rounded-lg border">
      <div className="flex items-center justify-between text-center">
        {/* Start Time */}
        <button 
          className="flex-1 p-1 rounded hover:bg-muted/50 transition-colors"
          onClick={() => onFieldClick('start-time')}
          disabled={currentStep === 'start-time'}
        >
          <div className="text-xs text-muted-foreground mb-1">Start</div>
          <div className={`${currentStep === 'start-time' ? 'text-muted-foreground' : 'text-foreground'}`}>
            {currentStep === 'start-time' ? '--:--' : formatTime(record.startTime)}
          </div>
        </button>

        <div className="px-2 text-border">|</div>

        {/* Severity */}
        <button 
          className="flex-1 p-1 rounded hover:bg-muted/50 transition-colors"
          onClick={() => onFieldClick('severity')}
          disabled={currentStep === 'severity'}
        >
          <div className="text-xs text-muted-foreground mb-1">Severity</div>
          <div className={`${currentStep === 'severity' ? 'text-muted-foreground' : 'text-foreground'} text-sm`}>
            {currentStep === 'severity' ? 'Select...' : (record.severity || '--')}
          </div>
        </button>

        <div className="px-2 text-border">|</div>

        {/* End Time */}
        <button 
          className="flex-1 p-1 rounded hover:bg-muted/50 transition-colors"
          onClick={() => onFieldClick('end-time')}
          disabled={currentStep === 'end-time'}
        >
          <div className="text-xs text-muted-foreground mb-1">End</div>
          <div className={`${currentStep === 'end-time' ? 'text-muted-foreground' : 'text-foreground'}`}>
            {currentStep === 'end-time' ? '--:--' : 
              (record.endTime ? formatTimeWithDayDiff(record.endTime, record.startTime) : 
                (currentStep === 'complete' || currentStep === 'notes' ? formatTimeWithDayDiff(currentEndTime, record.startTime) : '--:--'))}
          </div>
        </button>
      </div>
    </div>
  );
}

export function RecordingFlow({ onSave, onBack, onDelete, existingRecord, initialDate, recordId, records = [], getOverlappingEvents, isEnrolledInTrial = false, enrollmentDateTime = null }: RecordingFlowProps) {
  // Helper function to determine if notes are required for this record
  const shouldRequireNotes = (recordToCheck: NosebleedRecord) => {
    if (!isEnrolledInTrial || !enrollmentDateTime) return false;
    
    const recordStartTime = recordToCheck.startTime || recordToCheck.date || new Date();
    return recordStartTime >= enrollmentDateTime;
  };
  
  // Add state for delete dialog
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  
  // Determine initial step based on what's missing from existing record
  const getInitialStep = (): RecordingStep => {
    if (!existingRecord) return 'start-time';
    
    // Check if record is incomplete
    const needsNotes = shouldRequireNotes(existingRecord) && !existingRecord.notes;
    const isIncomplete = !existingRecord.severity || !existingRecord.endTime || needsNotes;
    
    if (isIncomplete) {
      // If severity is missing, start with severity selection
      if (!existingRecord.severity) return 'severity';
      // If only end time is missing, start with end time
      if (!existingRecord.endTime) return 'end-time';
      // If only notes are missing, start with notes
      if (needsNotes) return 'notes';
    }
    
    // Complete record, start at complete step
    return 'complete';
  };

  const [step, setStep] = useState<RecordingStep>(getInitialStep());
  const [record, setRecord] = useState<NosebleedRecord>(() => {
    if (existingRecord) {
      // Ensure existing record has valid startTime
      return {
        ...existingRecord,
        startTime: existingRecord.startTime || new Date(),
        date: existingRecord.date || new Date()
      };
    }
    const baseDate = initialDate || new Date();
    return {
      id: recordId || '',
      date: baseDate,
      startTime: new Date(baseDate), // Use the selected date for start time
    };
  });
  const [currentEndTime, setCurrentEndTime] = useState<Date>(
    existingRecord?.endTime || new Date()
  );
  const [endTimeError, setEndTimeError] = useState<string>('');
  const [hasManuallySetEndTime, setHasManuallySetEndTime] = useState<boolean>(
    // If editing an existing record that already has an end time, consider it manually set
    Boolean(existingRecord?.endTime)
  );

  // Update current end time every second when on end-time step
  useEffect(() => {
    if (step === 'end-time') {
      // Only update time in real-time if the user has never manually set the end time
      const shouldUpdateRealTime = !hasManuallySetEndTime;
      
      if (shouldUpdateRealTime) {
        const interval = setInterval(() => {
          const now = new Date();
          const adjustedTime = record.startTime ? adjustEndTimeDate(record.startTime, now) : now;
          setCurrentEndTime(adjustedTime);
        }, 1000);
        return () => clearInterval(interval);
      }
    }
  }, [step, hasManuallySetEndTime, record.startTime]);

  const handleDateChange = (date: Date) => {
    setRecord(prev => {
      // Update the start time to match the new date while preserving time
      const newStartTime = new Date(date);
      
      if (prev.startTime && prev.startTime instanceof Date) {
        newStartTime.setHours(prev.startTime.getHours(), prev.startTime.getMinutes(), 0, 0);
      } else {
        // If no startTime exists, use current time
        const now = new Date();
        newStartTime.setHours(now.getHours(), now.getMinutes(), 0, 0);
      }
      
      return { 
        ...prev, 
        date,
        startTime: newStartTime
      };
    });
  };

  const handleStartTimeChange = (time: Date) => {
    setRecord(prev => {
      const updatedRecord = { ...prev, startTime: time };
      
      // If we have an end time, adjust its date based on the new start time
      if (prev.endTime) {
        const adjustedEndTime = adjustEndTimeDate(time, prev.endTime);
        updatedRecord.endTime = adjustedEndTime;
        // Also update currentEndTime to reflect the adjustment
        setCurrentEndTime(adjustedEndTime);
      } else if (step === 'end-time') {
        // If we're on the end-time step and don't have a saved end time yet,
        // adjust the current end time based on the new start time
        const adjustedCurrentEndTime = adjustEndTimeDate(time, currentEndTime);
        setCurrentEndTime(adjustedCurrentEndTime);
      }
      
      return updatedRecord;
    });
  };

  const handleStartTimeConfirm = () => {
    setStep('severity');
  };

  const handleSeveritySelect = (severity: string) => {
    setRecord(prev => ({ ...prev, severity }));
    
    // Determine next step based on current record state
    // If we already have an end time in the current record (meaning we're editing from complete step)
    // or if we're editing an existing record that has an end time, go to complete
    if (record.endTime || (existingRecord && existingRecord.endTime)) {
      setStep('complete');
    } else {
      // No end time yet, continue to end-time step
      setStep('end-time');
    }
  };

  // Helper function to adjust end time date based on start time and rules
  const adjustEndTimeDate = (startTime: Date, endTime: Date): Date => {
    if (!startTime || !endTime || !(startTime instanceof Date) || !(endTime instanceof Date)) {
      return endTime;
    }

    const now = new Date();
    const adjustedEndTime = new Date(endTime);
    
    // Set the end time to the same date as start time initially
    adjustedEndTime.setFullYear(startTime.getFullYear(), startTime.getMonth(), startTime.getDate());
    
    // Check if end time is before start time (crossed midnight)
    if (adjustedEndTime.getTime() <= startTime.getTime()) {
      // Move to next day
      adjustedEndTime.setDate(adjustedEndTime.getDate() + 1);
    }
    
    // Ensure end time is not in the future
    if (adjustedEndTime > now) {
      // If the adjusted time is in the future, use the same day as start time
      // but cap the time at current time if it's today
      const startDateOnly = new Date(startTime);
      startDateOnly.setHours(0, 0, 0, 0);
      const nowDateOnly = new Date(now);
      nowDateOnly.setHours(0, 0, 0, 0);
      
      if (startDateOnly.getTime() === nowDateOnly.getTime()) {
        // Start time is today, cap end time at current time
        return new Date(Math.min(adjustedEndTime.getTime(), now.getTime()));
      } else {
        // Start time is not today, something is wrong with the logic
        // Fall back to same day as start time
        const fallbackEndTime = new Date(endTime);
        fallbackEndTime.setFullYear(startTime.getFullYear(), startTime.getMonth(), startTime.getDate());
        return fallbackEndTime;
      }
    }
    
    return adjustedEndTime;
  };

  const handleEndTimeChange = (time: Date) => {
    const adjustedTime = record.startTime ? adjustEndTimeDate(record.startTime, time) : time;
    setCurrentEndTime(adjustedTime);
    // Mark that the user has manually set the end time
    setHasManuallySetEndTime(true);
    // Clear error when user changes time
    if (endTimeError) {
      setEndTimeError('');
    }
  };

  // Helper function to validate end time
  const validateEndTime = (startTime: Date, endTime: Date): string => {
    if (!startTime || !endTime || !(startTime instanceof Date) || !(endTime instanceof Date)) {
      return 'Invalid time values';
    }
    
    const now = new Date();
    const startDateTime = startTime.getTime();
    const endDateTime = endTime.getTime();
    
    // Check if end time is the same as start time
    if (endDateTime === startDateTime) {
      return 'End time cannot be the same as start time';
    }
    
    // Check if end time is in the future
    if (endTime > now) {
      return 'End time cannot be in the future';
    }
    
    // Check if end time is before start time (accounting for date changes)
    const startDateOnly = new Date(startTime);
    startDateOnly.setHours(0, 0, 0, 0);
    const endDateOnly = new Date(endTime);
    endDateOnly.setHours(0, 0, 0, 0);
    
    const daysDifference = (endDateOnly.getTime() - startDateOnly.getTime()) / (1000 * 60 * 60 * 24);
    
    // If end time is on the same day as start time
    if (daysDifference === 0) {
      if (endDateTime < startDateTime) {
        return 'End time cannot be earlier than start time on the same day';
      }
    }
    // If end time is on the next day
    else if (daysDifference === 1) {
      // This is valid (crossed midnight scenario)
      return '';
    }
    // If end time is on a previous day or more than one day in the future
    else if (daysDifference < 0) {
      return 'End time cannot be on a previous day';
    }
    else if (daysDifference > 1) {
      return 'End time cannot be more than one day after start time';
    }
    
    return '';
  };

  const handleEndTimeConfirm = () => {
    if (!record.startTime) {
      setEndTimeError('Start time is required');
      return;
    }
    
    // Ensure the end time has the correct date adjustment applied
    const adjustedEndTime = adjustEndTimeDate(record.startTime, currentEndTime);
    
    const validationError = validateEndTime(record.startTime, adjustedEndTime);
    
    if (validationError) {
      setEndTimeError(validationError);
      return;
    }
    
    const updatedRecord = { ...record, endTime: adjustedEndTime };
    setRecord(updatedRecord);
    
    // Update the current end time to reflect the adjustment
    setCurrentEndTime(adjustedEndTime);
    
    // Check if notes are required for this record
    if (shouldRequireNotes(updatedRecord)) {
      setStep('notes');
    } else {
      setStep('complete');
    }
  };

  const handleFinish = () => {
    // Ensure we have the most current data with proper date adjustment
    let endTime = record.endTime || currentEndTime;
    
    // Apply date adjustment if we have both start and end times
    if (record.startTime && endTime) {
      endTime = adjustEndTimeDate(record.startTime, endTime);
    }
    
    const finalRecord = {
      ...record,
      endTime: endTime
    };
    
    // Validate duration before saving - prevent negative durations
    if (finalRecord.startTime && finalRecord.endTime) {
      const validationError = validateEndTime(finalRecord.startTime, finalRecord.endTime);
      if (validationError) {
        // Set error and switch to end-time step to show the error
        setEndTimeError(validationError);
        setCurrentEndTime(finalRecord.endTime);
        setStep('end-time');
        return;
      }
    }
    
    onSave(finalRecord);
  };

  // Get current overlapping events
  const getCurrentOverlappingEvents = () => {
    if (!getOverlappingEvents) return [];
    
    const currentRecord = {
      ...record,
      endTime: record.endTime || (step === 'end-time' || step === 'notes' || step === 'complete' ? currentEndTime : undefined)
    };
    
    return getOverlappingEvents(currentRecord);
  };

  const overlappingEvents = getCurrentOverlappingEvents();

  const handleBack = () => {
    // If this is a new recording and the user has made progress past start-time,
    // save as incomplete record
    if (!existingRecord && step !== 'start-time') {
      const incompleteRecord: NosebleedRecord = {
        ...record,
        isIncomplete: true
      };
      onBack(incompleteRecord);
    } else {
      onBack();
    }
  };

  const handleNotesChange = (notes: string) => {
    setRecord(prev => ({ ...prev, notes }));
  };

  const handleNotesConfirm = () => {
    setStep('complete');
  };

  const handleNotesBack = () => {
    setStep('end-time');
  };

  const handleFieldClick = (field: 'start-time' | 'severity' | 'end-time') => {
    // Only allow navigation to previous steps or completed steps
    if (field === 'start-time') {
      setStep('start-time');
    } else if (field === 'severity' && (record.startTime || existingRecord?.startTime)) {
      setStep('severity');
    } else if (field === 'end-time' && record.severity && (record.startTime || existingRecord?.startTime)) {
      // If editing an existing record with an end time, use that as the current end time
      if (existingRecord?.endTime) {
        setCurrentEndTime(existingRecord.endTime);
        setHasManuallySetEndTime(true);
      }
      setStep('end-time');
    }
  };

  return (
    <div className="size-full flex flex-col bg-background">
      <div className="p-4 border-b">
        <div className="flex items-center justify-between">
          <button onClick={handleBack} className="flex items-center gap-2 text-muted-foreground">
            <ArrowLeft className="w-4 h-4" />
            Back
          </button>
          
          {/* Delete/Cancel Button */}
          {existingRecord && (
            <button 
              onClick={() => setShowDeleteDialog(true)}
              className="p-2 text-destructive hover:bg-destructive/10 rounded-md transition-colors"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          )}
        </div>
      </div>

      <DeleteConfirmationDialog
        open={showDeleteDialog}
        onOpenChange={setShowDeleteDialog}
        onConfirmDelete={onDelete}
        record={existingRecord || null}
      />

      <div className="flex-1 flex flex-col p-4">
        <DateHeader 
          date={record.date} 
          onChange={handleDateChange}
          editable={true}
        />

        {/* Compact Record Summary */}
        <div className="mt-2">
          <RecordSummary 
            record={record} 
            currentStep={step}
            currentEndTime={currentEndTime}
            onFieldClick={handleFieldClick}
          />
        </div>

        {/* Overlap Warning */}
        {overlappingEvents.length > 0 && (
          <div className="mt-2 p-2 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg">
            <div className="flex items-start gap-2">
              <AlertTriangle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
              <div className="text-amber-800 dark:text-amber-200">
                <div className="font-medium mb-1">Overlapping Events Detected</div>
                <div className="text-sm">
                  This event overlaps with {overlappingEvents.length} existing event{overlappingEvents.length > 1 ? 's' : ''}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Edit Area */}
        <div className="flex-1 flex flex-col justify-center mt-4">
          {step === 'start-time' && (
            <div className="space-y-4">
              <MaterialTimePicker
                time={record.startTime || new Date()}
                onChange={handleStartTimeChange}
                editable={true}
                label="Nosebleed Start"
                showAdjustButtons={true}
                onConfirm={handleStartTimeConfirm}
              />
            </div>
          )}

          {step === 'severity' && (
            <SeveritySelection
              onSelect={handleSeveritySelect}
              selectedSeverity={record.severity}
            />
          )}

          {step === 'end-time' && (
            <div className="space-y-4">
              <MaterialTimePicker
                time={currentEndTime}
                onChange={handleEndTimeChange}
                editable={true}
                label="Nosebleed End Time"
                showAdjustButtons={true}
                onConfirm={handleEndTimeConfirm}
                confirmButtonText="Nosebleed Ended"
              />
              
              {endTimeError && (
                <Alert variant="destructive">
                  <AlertTriangle className="h-4 w-4" />
                  <AlertDescription>
                    {endTimeError}
                  </AlertDescription>
                </Alert>
              )}
            </div>
          )}

          {step === 'notes' && (
            <NotesInput
              notes={record.notes || ''}
              onNotesChange={handleNotesChange}
              onBack={handleNotesBack}
              onNext={handleNotesConfirm}
            />
          )}

          {step === 'complete' && (
            <div className="space-y-4 text-center">
              <div>
                <h2 className="mb-1">
                  {existingRecord 
                    ? ((!existingRecord.severity || !existingRecord.endTime) ? 'Complete Record' : 'Edit Record')
                    : 'Record Complete'
                  }
                </h2>
                <p className="text-muted-foreground">
                  {existingRecord && (!existingRecord.severity || !existingRecord.endTime)
                    ? 'Review the information and save when ready'
                    : 'Tap any field above to edit it'
                  }
                </p>
              </div>

              {shouldRequireNotes(record) && (
                <div className="p-3 bg-muted/30 rounded-lg border">
                  <div className="text-sm text-muted-foreground mb-1">Notes</div>
                  <button 
                    onClick={() => setStep('notes')}
                    className="text-left hover:text-primary transition-colors w-full"
                  >
                    {record.notes || 'Tap to add notes (required)'}
                  </button>
                </div>
              )}

              <Button 
                onClick={handleFinish}
                className="w-full"
                size="lg"
                disabled={shouldRequireNotes(record) && !record.notes}
              >
                {existingRecord 
                  ? ((!existingRecord.severity || !existingRecord.endTime) ? 'Complete Record' : 'Save Changes')
                  : 'Finished'
                }
              </Button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}